#!/bin/sh

set -e

export $(cat .env)

PASSWORD_FILE=.password
echo $PASSWORD | sed 's/"//g' > .password

cleanup() {
  echo "Removing .password"
  rm  -r $PASSWORD_FILE
}

trap cleanup EXIT

alias ssh_="sshpass -f $PASSWORD_FILE ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP"

# Install sshpass
sudo apt install sshpass -y

# Install deps
ssh_ "apt install curl socat fail2ban -y"
echo "Installed depps"

# Install Acme Script
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "curl https://get.acme.sh | sh"
echo "Install Acme Script"

# Get Free SSL Certificate using Let’s Encrypt
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "~/.acme.sh/acme.sh --set-default-ca --server letsencrypt"
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "~/.acme.sh/acme.sh --register-account -m xxxx@xxxx.com"
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone"
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP \
    "~/.acme.sh/acme.sh --installcert -d $DOMAIN --key-file /root/private.key --fullchain-file /root/cert.crt"

echo "Got Free SSL Certificate using Let’s Encrypt"

# Install X-UI
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "echo 'n' | bash <(curl -Ls https://raw.githubusercontent.com/hossinasaadi/x-ui/master/install.sh)"
echo "Installed X-UI"

# Setup venv
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
echo "Setup venv"

# Setup ssl
python3 cli.py setup-ssl
SSL_ENABLED=TRUE
echo "Setup SSL"

# Restart x-ui
echo $PASSWORD
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP "x-ui restart"
echo "Restart x-ui"

sleep 3

# Change password
XPASSWORD=$(python3 cli.py change-password | grep -Po '(?<=PASSWORD: )[^P]*')
echo "New Password: $XPASSWORD"

# Setup configs
python3 cli.py add-vmess 80 ws
python3 cli.py add-vless-tls 443 wss
python3 cli.py add-trojan 995

# Optimizing
sshpass -p $PASSWORD ssh -o StrictHostKeychecking=no -o PubkeyAuthentication=false -t $USER@$IP \
    "curl https://raw.githubusercontent.com/iRhonin/easy-v2ray/master/sysctl/local.conf -o /etc/sysctl.d/local.conf && sysctl --system"
