## TODO
- [ ] Based on inputs from config.json file, create scogo/scogo luci configuration file at runtime
- [ ] 

# Scogo Edge Router Configuration
Repository contains Scogo Smart Secure Edge Router General Configuration files

- Tinyproxy
```
touch /var/log/tinyproxy.log
chown nobody:nogroup /var/log/tinyproxy.log
/usr/bin/tinyproxy -d -c /etc/config/tinyproxy.conf &
```
