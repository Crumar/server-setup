#!/bin/bash
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
su -c "wget -P ~/scripts/ https://raw.githubusercontent.com/Crumar/server-setup/main/steam/scripts/start_cs2.sh" -g steam steam
su -c "chmod u+x ~/scripts/*.sh" -g steam steam

su -c "~/scripts/update_cs2.sh"

wget -P ~/.config/systemd/user/cs2.service https://raw.githubusercontent.com/Crumar/server-setup/main/steam/.config/systemd/user/cs2.service
su -c "systemctl --user daemon-reload"
su -c "systemctl --user enabled cs2"
#change token in start cs2.sh
su -c "systemctl --user start cs2"