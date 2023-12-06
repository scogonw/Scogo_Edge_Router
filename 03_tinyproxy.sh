touch /var/log/tinyproxy.log
chown nobody:nogroup /var/log/tinyproxy.log
/usr/bin/tinyproxy -d -c /etc/config/tinyproxy.conf &
