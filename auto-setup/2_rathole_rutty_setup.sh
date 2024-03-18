#!/bin/sh
HOSTNAME=$(uci get scogo.@device[0].serial_number | tr '[A-Z]' '[a-z]')
# if curl is not installed, install it
if ! command -v curl &> /dev/null
then
    opkg update
    opkg install curl
fi

download_binaries(){
    echo "Downloading Rutty ...."
    killall rutty
    curl -o /usr/bin/rutty "https://scogo-ser.s3.ap-south-1.amazonaws.com/rutty/target/mipsel-unknown-linux-musl/release/rutty"
    chmod +x /usr/bin/rutty

    echo "Downloading Rathole ...."
    killall rathole
    curl -o /usr/bin/rathole "https://scogo-ser.s3.ap-south-1.amazonaws.com/rathole/target/mipsel-unknown-linux-musl/release/rathole"
    chmod +x /usr/bin/rathole
}

create_initd_service_rutty() {
# Create a init.d service for the binaries
echo "Setting up init.d service for Rutty ..."
cat <<EOF > /etc/init.d/rutty

#!/bin/sh /etc/rc.common

START=10
STOP=15

start() {
        echo "Starting rutty service ..."
        /usr/bin/rutty /bin/login -w -t "$HOSTNAME-Terminal" -r 10 &
}

stop() {
        echo "Stopping rutty service ..."
        killall rutty
}

EOF

chmod +x /etc/init.d/rutty
/etc/init.d/rutty start

}

create_initd_service_rathole() {
echo "Setting up init.d service for Rathole ..."

rathole_remote_addr=$(jsonfilter -i config.json -e @.rathole_remote_addr)
rathole_default_token=$(jsonfilter -i config.json -e @.rathole_default_token)

cat <<EOF > /var/etc/rathole-client.toml
[client]
remote_addr = "$rathole_remote_addr"
default_token = "$rathole_default_token"

[client.transport]
type = "tcp"

[client.services.$HOSTNAME]
type = "tcp"
local_addr = "0.0.0.0:3000"
nodelay = true

EOF

cat <<EOF > /etc/init.d/rathole
#!/bin/sh /etc/rc.common
START=99
STOP=15
USE_PROCD=1
PROG=/usr/bin/rathole

start_service() {
    echo "Starting rathole service ..."
    procd_open_instance rathole
    procd_set_param command /usr/bin/rathole -c /var/etc/rathole-client.toml 
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param user root
    procd_close_instance
}

stop_service() {
    killall rathole
}

restart_service() {
    stop_service
    sleep 2
    start_service
}

status_service() {
    pidof rathole
    if [ $? -eq 0 ]; then
        echo "rathole service is running"
    else
        echo "rathole service is not running"
    fi
}

EOF

echo "Starting Rathole service ..."
chmod +x /etc/init.d/rathole
/etc/init.d/rathole enable
/etc/init.d/rathole start
sleep 2
/etc/init.d/rathole status

}

failure=1

# Download the binaries
download_binaries


# if the init.d/rutty service does not exist, create it
if [ -f /etc/init.d/rutty ]; then
    # rm -f /etc/init.d/rutty
    create_initd_service_rutty
    failure=0
else 
    /etc/init.d/rutty start
    failure=0
fi

# if the init.d/rathole service does not exist, create it
if [ -f /etc/init.d/rathole ]; then
    rm -f /var/etc/rathole-client.toml
    rm -f /etc/init.d/rathole
    create_initd_service_rathole
    failure=0
else 
    /etc/init.d/rathole restart
    failure=0
fi