# Final Configuration
## Option-1 directly editing /etc/config/firewall file
```
config redirect
        option target 'DNAT'
        option name 'Redirect port-54 traffic to Scogo DNS'
        option src 'lan'
        option src_dport '53'
        option dest_ip '20.244.41.36'
        option dest_port '54'
        list proto 'tcp'
        list proto 'udp'

/etc/init.d/firewall restart
```
## Option-2 via UCI

```
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].name='Redirect DNS port-53 traffic to Scogo DNS'
uci set firewall.@redirect[-1].src='lan'
uci set firewall.@redirect[-1].src_dport='53'
uci set firewall.@redirect[-1].dest_ip='20.244.41.36'
uci set firewall.@redirect[-1].dest_port='53'
uci add_list firewall.@redirect[-1].proto='tcp'
uci add_list firewall.@redirect[-1].proto='udp'
uci commit firewall
/etc/init.d/firewall restart
```
## Whitelist IP address `192.168.3.189`
```
config redirect
        option target 'DNAT'
        option name 'Redirect port-54 traffic to Scogo DNS'
        option src 'lan'
        option src_dport '53'
        option dest_ip '20.244.41.36'
        option dest_port '54'
        list proto 'tcp'
        list proto 'udp'
        option src_ip '!192.168.3.189'
```
## Whitelist MAC address `5c:53:10:28:9c:2c`

```
config redirect
        option target 'DNAT'
        option name 'Redirect port-54 traffic to Scogo DNS'
        option src 'lan'
        option src_dport '53'
        option dest_ip '20.244.41.36'
        option dest_port '54'
        list proto 'tcp'
        list proto 'udp'
        option src_mac '!5c:53:10:28:9c:2c'

```

## To whitelist multiple mac addresses using UCI
```
uci add_list firewall.@redirect[0].src_mac=!5c:53:10:28:9c:2c
uci add_list firewall.@redirect[0].src_mac=!5c:e9:1e:80:15:ab
uci commit firewall
/etc/init.d/firewall restart

```

## Testing

## Openwrt filrewall rule to forward all DNS requests to a specific DNS server 192.168.3.1:5333
- Make sure ports are enabled on Azure 
```
iptables -t nat -A PREROUTING -i br-lan -p udp --dport 53 -j DNAT --to 20.244.41.36:53
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 53 -j DNAT --to 20.244.41.36:53

```


root@SER-B960616E:~# iptables -t nat -A PREROUTING -i br-lan -p udp --dport 53 -j DNAT --to 20.244.41.36:53

Warning: Extension DNAT revision 0 not supported, missing kernel module?
iptables v1.8.8 (nf_tables):  RULE_APPEND failed (No such file or directory): rule in chain PREROUTING



## Openwrt filrewall rule to forward all DNS requests to a specific DNS server , use nftables
- Make sure ports are enabled on Azure 
```
nft add rule ip nat PREROUTING iifname "br-lan" udp dport 53 dnat
```
- List all nftables rules
```
nft list ruleset
```

You are a software engineer and you have been tasked to configure a openwrt router to forward all DNS requests to a specific DNS server. You need to use nftables to achieve this. explain the steps you will take to achieve this task, with the command you will use to add the rule to the nftables ruleset.

nft add rule ip filter PREROUTING dport 53 iifname "br-lan" jump DNAT to destination "20.244.41.36":53

nft add rule ip filter PREROUTING dport 53 protocol udp iifname 'br-lan' jump DNAT to destination 20.244.41.36 53




nft add rule inet fw4 mangle_prerouting tcp dport 22 meta nftrace set 1
nft monitor


config redirect
        option target 'DNAT'
        option name 'Redirect port-53 traffic to Scogo DNS'
        option src 'lan'
        option src_dport '53'
        option dest 'lan'
        option dest_ip '20.244.41.36'
        option dest_port '53'
        list proto 'tcp'
        list proto 'udp'

config redirect
        option target 'DNAT'
        option name 'Redirect port-54 traffic to Scogo DNS'
        option src 'lan'
        option src_dport '53'
        option dest_ip '20.244.41.36'
        option dest_port '54'
        list proto 'tcp'
        list proto 'udp'


config redirect
        option name 'Redirect-DNS'
        option target 'DNAT'
        option src 'lan'
        option src_ip '!10.0.0.1'
        option dest_port '53'
        option src_dport '53'
        list proto 'tcp'
        list proto 'udp'


config redirect 'adblock_lan53'
        option name 'Adblock DNS (lan, 53)'
        option src 'lan'
        option proto 'tcp udp'
        option src_dport '53'
        option dest_port '53'
        option target 'DNAT'


