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


### STEAM ###
apt install software-properties-common -y
apt-add-repository non-free -y
dpkg --add-architecture i386
apt update
apt install steamcmd -y
useradd -m steam
passwd steam
su -c "mkdir ~/scripts" -g steam steam
su -c "wget -P ~/scripts/ https://raw.githubusercontent.com/Crumar/server-setup/main/steam/scripts/_update_cs2" -g steam steam
su -c "wget -P ~/scripts/ https://raw.githubusercontent.com/Crumar/server-setup/main/steam/scripts/autoupdate_cs2.sh" -g steam steam
su -c "wget -P ~/scripts/ https://raw.githubusercontent.com/Crumar/server-setup/main/steam/scripts/update_cs2.sh" -g steam steam
su -c "chmod u+x ~/scripts/*.sh" -g steam steam
wget -P /etc/systemd/system/
reboot