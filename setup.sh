#!/bin/bash
passwd

apt update
apt upgrade -y

useradd -m crmr
passwd crmr

mkdir /scripts
wget -P /scripts/ https://raw.githubusercontent.com/Crumar/server-setup/main/scripts/firewall.sh
chmod u+x /scripts/firewall.sh
echo "@reboot root /scripts/firewall.sh" > /etc/crontab
sed -i 's/Port 22/Port 22222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
apt install fail2ban nginx htop -y

reboot

