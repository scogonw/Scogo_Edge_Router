#!/bin/sh /etc/rc.common
 
START=10
STOP=15
 
start() {        
        echo "Starting TinyProxy"
        /usr/bin/tinyproxy -d -c /var/etc/tinyproxy.conf &
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
