#!/bin/bash

systemctl stop csgo
su steam -c 'cd ~ && sh update_csgo.sh'
systemctl start csgo