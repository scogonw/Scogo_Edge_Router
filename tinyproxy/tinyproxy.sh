#!/bin/sh /etc/rc.common

START=10
STOP=15

start() {
        echo starting tinyproxy
        /usr/bin/tinyproxy -d -c /etc/config/tinyproxy.conf &
}

stop() {
        echo stopping tinyproxy
        killall tinyproxy
}