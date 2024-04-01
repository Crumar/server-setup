#!/bin/bash
cd /home/steam/cs2/game/bin/linuxsteamrt64/
LD_LIBRARY_PATH='/home/steam/.steam/steam/steamcmd/linux64' ./cs2 -dedicated -tickrate 128 -port 27015 -maxplayers 10 +sv_setsteamaccount [TOKEN] +map de_dust2 +exec server.cfg