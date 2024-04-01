#!/bin/bash
passwd

apt update
apt upgrade -y

useradd -m crmr
passwd crmr

mkdir /scripts
wget -P /scripts/ https://github.com/Crumar/server-setup/blob/main/scripts/firewall.sh
chmod u+x /scripts/firewall.sh
echo "@reboot root /scripts/firewall.sh" > /etc/crontab
sed -i 's/Port 22/Port 22222/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
apt install fail2ban nginx -y


### STEAM ###
apt install software-properties-common -y
apt-add-repository non-free -y
dpkg --add-architecture i386
apt update
apt install steamcmd -y
useradd -m steam
su -c "wget -P ~/scripts/ https://github.com/Crumar/server-setup/blob/main/scripts/firewall.sh " -g apache apache