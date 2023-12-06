#!/bin/sh

START=10
STOP=15

start() {
        echo "Starting TinyProxy"
        touch /var/log/tinyproxy.log
	chown nobody:nogroup /var/log/tinyproxy.log
        /usr/bin/tinyproxy -d -c /etc/config/tinyproxy.conf &
}

stop() {
        echo "Stopping TinyProxy"
        killall tinyproxy
}

restart() {
        echo "Restarting TinyProxy"
        stop
        start
	return 0
}

touch /var/log/tinyproxy.log
chown nobody:nogroup /var/log/tinyproxy.log
/usr/bin/tinyproxy -d -c /etc/config/tinyproxy.conf &
