#!/bin/bash
IPT="/sbin/iptables"
IPT6="/sbin/ip6tables"
PUBIF="eth0"

$IPT -F
$IPT -X
$IPT -t mangle -F
$IPT -t mangle -X
$IPT6 -F
$IPT6 -X
$IPT6 -t mangle -F
$IPT6 -t mangle -X
iptables -t raw -A OUTPUT -p tcp --dport 4480 -j TRACE
#unlimited access to loopback
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT6 -A INPUT -i lo -j ACCEPT
$IPT6 -A OUTPUT -o lo -j ACCEPT

# DROP all incomming traffic
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP
$IPT6 -P INPUT DROP
$IPT6 -P OUTPUT DROP
$IPT6 -P FORWARD DROP


# Allow full outgoing connection but no incomming stuff
$IPT -A INPUT -i $PUBIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -o $PUBIF -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPT6 -A INPUT -i $PUBIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT6 -A OUTPUT -o $PUBIF -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# allow incoming ICMP ping pong stuff
$IPT -A INPUT -i $PUBIF -p icmp -j ACCEPT
$IPT -A OUTPUT -o $PUBIF -p icmp -j ACCEPT
$IPT6 -A INPUT -i $PUBIF -p ipv6-icmp -j ACCEPT
$IPT6 -A OUTPUT -o $PUBIF -p ipv6-icmp -j ACCEPT

#localhost smtp
#$IPT -A INPUT -p tcp -s 127.0.0.0/8 --destination-port 25 -j ACCEPT
#$IPT -A INPUT -p tcp -s 127.0.0.0/8 --destination-port 4480 -j ACCEPT

function b {
    $IPT -A INPUT -i $PUBIF -p $1 --destination-port $2 -j ACCEPT
    $IPT6 -A INPUT -i $PUBIF -p $1 --destination-port $2 -j ACCEPT
}

function u {
    b udp $1
}

function t {
    b tcp $1
}

t 22222       #SSH
t 80          #HTTP
t 443         #HTTPS
t 53          #DNS
u 53          #DNS
#t 2456:2458   #VALHEIM
#u 2456:2458   #VALHEIM
t 27015       #CS
u 27015       #CS
#t 27016       #CS
#u 27016       #CS
#t 28015:28016 #RUST
#u 28015:28016 #RUST
#u 10000       #JITSI
#t 8080       #GITLAB
#t 8181       #GITLAB
#t 5580
#t 3012
###TS3
#u 9987
#t 10011
#t 30033

#### no need to edit below ###
# log everything else
#$IPT -A INPUT -i $PUBIF -j LOG
$IPT -A INPUT  -j LOG --log-prefix "Input Log:"
$IPT -A OUTPUT  -j LOG --log-prefix "Output Log:"
$IPT6 -A INPUT -i $PUBIF -j LOG
$IPT -A INPUT -i $PUBIF -j DROP
$IPT6 -A INPUT -i $PUBIF -j DROP

#iptables -A INPUT -i docker0 -p tcp -j ACCEPT
#iptables -A OUTPUT -o docker0 -p tcp -j ACCEPT