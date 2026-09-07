#!/bin/bash

#add non-free to all apt sources first!
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

mkdir -p /usr/local/bin
ln -s /usr/games/steamcmd /usr/local/bin/steamcmd

su -c "~/scripts/update_cs2.sh" -g steam steam
ln -s /home/steam/.steam/steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/
wget -P ~/.config/systemd/user/ https://raw.githubusercontent.com/Crumar/server-setup/main/steam/.config/systemd/user/cs2.service
su -c "systemctl --user daemon-reload"
su -c "systemctl --user enabled cs2" -g steam steam
#change token in start cs2.sh
su -c "systemctl --user start cs2" -g steam steam