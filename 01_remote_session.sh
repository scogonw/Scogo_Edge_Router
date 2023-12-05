#!/bin/sh /etc/rc.common
 
START=10
STOP=15
 
start() {        
        echo "starting ttyd"
        /usr/bin/ttyd -m 2 -t cursorStyle=bar -t enableTrzsz=true -t enableZmodem=true -t lineHeight=1 login &
}                 
 
stop() {          
        echo "stopping ttyd"
        killall ttyd 
}
