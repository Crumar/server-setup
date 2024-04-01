

mkdir /scripts
echo "@reboot root /scripts/firewall.sh" > /etc/crontab
sed -i 's/Port 22/Port 22222/' /etc/ssh/sshd_config
sudo apt install fail2ban bind9 nginx
