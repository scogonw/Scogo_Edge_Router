#!/bin/sh

# Enable debugging mode
set -x

# Redirect stdout and stderr to a log file in /tmp directory with a unique file name using the current date and time stamp in the file name format (aio-YYYYMMDD-HHMMSS.log)
exec > >(tee /tmp/aio-$(date '+%Y%m%d-%H%M%S').log) 2>&1


## Kubernetes pre-requisites
#1. Create ingress route for configure and terminal
#2. Update CM for configure and terminal
#3. Update service names for configure and terminal
#4. Use argocd to deploy the changes
#5. Delete the existing pods to apply the changes

## Router pre-requisites
#1. Create config.json file with all the configuration details on the router

## Todo
#1 For every function call make sure the previous function is successful if not then exit the script
#2 Add the cleanup function at the end of the script
#3 All the logs failed or successfull should be pushed to remote server with unique file name
#4 Set password for root user
#5 Configure wifi and set password
#6 Wrap the script (aio.sh) in a curl one-liner installer

## Update as on 25 March
#1. config.json and aio.sh are on the router
#2. aio.sh should be executed on the router and test

##########################
# Prerequisites Setup    #
##########################

failure=0

prerequisites_setup() {

echo "============================"
echo "Setting up Prerequisites ..."
echo "============================"

## check if internet is available using ping command and if not available, write the error to stderr and exit
if ! ping -c 1 google.com &> /dev/null
then
    echo "Internet is not available. Please check the internet connection and try again." >&2
    failure=1
    exit 1
fi

# if opkg is not installed, abort
if ! command -v opkg &> /dev/null
then
    echo "opkg is not installed. Please install opkg and try again." >&2
    failure=1
    exit 1
fi

# update the package list
echo "==> Updating the package list ..."
## Todo : uncomment the below line after testing
opkg update

# write an if condition to check if curl , jsonfilter AND jq commands are available and if not, install them

# if condition to check if curl and jsonfilter commands are available and if not, install them
#echo "==> Checking if curl and jsonfilter commands are available ..."
if ! command -v curl &> /dev/null || ! command -v jsonfilter &> /dev/null || ! command -v jq &> /dev/null
then
    echo "==> Installing curl, jsonfilter, jq, coreutils-base64 packages ..."
    opkg install curl coreutils-base64 jsonfilter jq 
    # check if the installation was successful
    if [ $? -ne 0 ]; then
        echo "Failed to install curl, jsonfilter, jq, coreutils-base64 packages. Please try again." >&2
        failure=1
        exit 1
    fi
fi

}

##########################
# Operating System Setup #
##########################

operating_system_setup() {
echo "==============================="
echo "Setting up Operating System ..."
echo "==============================="


## Todo : uncomment the below line before deploying to production

echo "===> Fetching default UCI configuration for scogo ..."
# curl -o /etc/config/scogo https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/uci_config/scogo

echo "===> Setting up UCI for Device configuration details ..."
# Read all keys without quotes or commas using jq
device_keys=$(jq -r '.device | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $device_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    device_value=$(jsonfilter -i config.json -e @.device.$key| tr '[a-z]' '[A-Z]')
    echo ">> Running uci set scogo.@device[0].$key=$device_value ..."
    uci set scogo.@device[0]."$key"="$device_value"
done
# unset variable value
unset device_keys
unset device_value
unset IFS
unset key

echo "===> Setting up UCI for Site configuration details ..."
# Read all keys without quotes or commas using jq
site_keys=$(jq -r '.site | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $site_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    site_value=$(jsonfilter -i config.json -e @.site.$key | tr '[a-z]' '[A-Z]')
    echo ">> Running uci set scogo.@site[0].$key=$site_value ..."
    uci set scogo.@site[0]."$key"="$site_value"
done
# unset variable value
unset site_keys
unset site_value
unset IFS
unset key


echo "===> Setting up UCI for Link1 configuration details ..."
# Read all keys without quotes or commas using jq
link1_keys=$(jq -r '.link1 | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $link1_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    link1_value=$(jsonfilter -i config.json -e @.link1.$key | tr '[a-z]' '[A-Z]')
    echo ">> Running uci set scogo.@link1[0].$key=$link1_value ..."
    uci set scogo.@link1[0]."$key"="$link1_value"
done
# unset variable value
unset link1_keys
unset link1_value
unset IFS
unset key


echo "===> Setting up UCI for Link2 configuration details ..."
# Read all keys without quotes or commas using jq
link2_keys=$(jq -r '.link2 | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $link2_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    link2_value=$(jsonfilter -i config.json -e @.link2.$key | tr '[a-z]' '[A-Z]')
    echo ">> Running uci set scogo.@link2[0].$key=$link2_value ..."
    uci set scogo.@link2[0]."$key"="$link2_value"
done
# unset variable value
unset link2_keys
unset link2_value
unset IFS
unset key

echo "===> Setting up UCI for Infrastructure configuration details ..."
# Read all keys without quotes or commas using jq
infrastructure_keys=$(jq -r '.infrastructure | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $infrastructure_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    infrastructure_value=$(jsonfilter -i config.json -e @.infrastructure.$key)
    echo ">> Running uci set scogo.@infrastructure[0].$key=$infrastructure_value ..."
    uci set scogo.@infrastructure[0]."$key"="$infrastructure_value"
done
# unset variable value
unset infrastructure_keys
unset infrastructure_value
unset IFS
unset key

echo "===> Setting up UCI for Notification configuration details ..."
# Read all keys without quotes or commas using jq
notification_keys=$(jq -r '.notification | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $notification_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    notification_value=$(jsonfilter -i config.json -e @.notification.$key | tr '[a-z]' '[A-Z]')
    echo ">> Running uci set scogo.@notification[0].$key=$notification_value ..."
    uci set scogo.@notification[0]."$key"="$notification_value"
done
# unset variable value
unset notification_keys
unset notification_value
unset IFS
unset key


## Todo : uncomment the section before deploying to production

# echo "===> Getting Current Network Configuration ..."
# uci show | grep -i network

# echo "===> Adding LAN3 and LAN4 to the LAN Bridge ..."
# uci set network.@device[0].ports='lan3 lan4'

# ## Delete WAN IPv6
# echo "===> Deleting WAN IPv6 ..."
# uci delete network.wan
# uci delete network.wan6

# ## Map interface-1 for wan-1/ISP-1
# echo "===> Mapping Port-1 i.e. interface-1 for wan-1/ISP-1 ..."
# uci set network.wan1=interface
# uci set network.wan1.device='lan1'
# uci set network.wan1.proto='dhcp'

# ## Map interface-2 for wan-2
# echo "===> Mapping Port-2 i.e. interface-2 for wan-2/ISP-2 ..."
# uci set network.wan2=interface
# uci set network.wan2.device='lan2'
# uci set network.wan2.proto='dhcp'
# uci commit network
# echo "===> Restarting Network Service ..."
# service network restart

# ## Remove wan,wan6 from firewall zone and add wan1 and wan2
# echo "===> Removing wan,wan6 from firewall zone and adding wan1 and wan2 ..."
# uci set firewall.@zone[1].network='wan wan1 wan2'
# uci commit firewall

}

#################
# Rathole Setup #
#################

rathole_setup() {
    echo "======================"
    echo "Setting up Rathole ..."
    echo "========================"

    create_initd_service_rathole() {
    rathole_server_endpoint=$(uci get scogo.@infrastructure[0].rathole_server_endpoint | tr '[A-Z]' '[a-z]')
    rathole_default_token=$(uci get scogo.@infrastructure[0].rathole_default_token)
    serial_number=$(uci get scogo.@device[0].serial_number | tr '[A-Z]' '[a-z]')
    rm /etc/config/rathole-client.toml &> /dev/null
    echo "===> Creating /etc/config/rathole-client.toml file ..."
cat <<EOF > /etc/config/rathole-client.toml
[client]
remote_addr = "$rathole_server_endpoint"
default_token = "$rathole_default_token"
[client.transport]
type = "tcp"
[client.services.${serial_number}_configure]
type = "tcp"
local_addr = "0.0.0.0:80"
nodelay = true
[client.services.${serial_number}_terminal]
type = "tcp"
local_addr = "0.0.0.0:3000"
nodelay = true
[client.services.${serial_number}_terminal_ttyd]
type = "tcp"
local_addr = "0.0.0.0:7681"
nodelay = true
EOF
    rm /etc/init.d/rathole &> /dev/null
    echo "===> Creating /etc/init.d/rathole file ..."
cat <<EOF > /etc/init.d/rathole
#!/bin/sh /etc/rc.common
START=99
STOP=15
USE_PROCD=1
PROG=/usr/bin/rathole
start_service() {
    echo "Starting rathole service ..."
    procd_open_instance rathole
    procd_set_param command /usr/bin/rathole -c /etc/config/rathole-client.toml 
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
    pidof rathole &> /dev/null
    if [ $? -eq 0 ]; then
        echo "rathole service is running"
    else
        echo "rathole service is not running"
    fi
}

EOF

    echo "===> Starting Rathole service ..."
    chmod +x /etc/init.d/rathole
    /etc/init.d/rathole enable
    /etc/init.d/rathole start
    sleep 2
    /etc/init.d/rathole status

    }

    # if the rathole binary does not exist, download it
    if [ ! -f /usr/bin/rathole ]; then
        echo "===> Downloading Rathole ...."
        killall rathole
        curl -o /usr/bin/rathole "https://scogo-ser.s3.ap-south-1.amazonaws.com/rathole/target/mipsel-unknown-linux-musl/release/rathole"
        chmod +x /usr/bin/rathole
    fi

    # if /etc/init.d/rathole service file does not exist, create it
    if [ -f /etc/init.d/rathole ]; then
        rm -f /var/etc/rathole-client.toml
        rm -f /etc/init.d/rathole
        create_initd_service_rathole
    else 
        echo "===> Restarting Rathole service ..."
        /etc/init.d/rathole restart
    fi

}

###############
# Rutty Setup #
###############

rutty_setup() {
    echo "======================"
    echo "Setting up Rutty ..."
    echo "========================"

create_initd_service_rutty() {
# Create a init.d service for the binaries
echo "===> Setting up /etc/init.d/rutty service file for Rutty ..."
hostname=$(uci get scogo.@device[0].hostname | tr '[A-Z]' '[a-z]')

cat <<EOF > /etc/init.d/rutty

#!/bin/sh /etc/rc.common
START=99
STOP=15
USE_PROCD=1
PROG=/usr/bin/rutty
start_service() {
    echo "Starting rutty service ..."
    procd_open_instance rutty
    procd_set_param command /usr/bin/rutty /bin/login -w -t "$hostname-Terminal" -r 10
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param user root
    procd_close_instance
}
stop_service() {
    killall rutty
}
restart_service() {
    stop_service
    sleep 2
    start_service
}
status_service() {
    pidof rutty &> /dev/null
    if [ 0 -eq 0 ]; then
        echo "rutty service is running"
    else
        echo "rutty service is not running"
    fi
}

EOF

chmod +x /etc/init.d/rutty
/etc/init.d/rutty enable
/etc/init.d/rutty start
pidof rutty
if [ $? -eq 0 ]; then
    echo "Rutty service is running"
else
    echo "===> Starting Rutty service ..."
    /etc/init.d/rutty start
fi


}
    # if the rutty binary does not exist, download it
    if [ ! -f /usr/bin/rutty ]; then
        echo "===> Downloading Rutty ...."
        killall rutty
        curl -o /usr/bin/rutty "https://scogo-ser.s3.ap-south-1.amazonaws.com/rutty/target/mipsel-unknown-linux-musl/release/rutty"
        chmod +x /usr/bin/rutty
    fi

    # if the /etc/init.d/rutty service does not exist, create it
    if [ -f /etc/init.d/rutty ]; then
        rm -f /etc/init.d/rutty
        create_initd_service_rutty
    else 
        chmod +x /etc/init.d/rutty
        /etc/init.d/rutty start
    fi

}


###################
# Tinyproxy Setup #
###################

tinyproxy_setup() {
    echo "========================"
    echo "Setting up Tinyproxy ..."
    echo "========================"

create_initd_service_configuration_tinyproxy() {

echo "===> Setting up /etc/config/tinyproxy.conf file for Tinyproxy ..."
rm /etc/config/tinyproxy.conf &> /dev/null
cat <<EOF > /etc/config/tinyproxy.conf
User nobody
Group nogroup

Port 8888
Listen 0.0.0.0
BindSame yes
Timeout 600

StatFile "/usr/share/tinyproxy/stats.html"
Logfile "/var/log/tinyproxy.log"
#Syslog On
LogLevel Info
PidFile "/var/log/tinyproxy.pid"

MaxClients 5
ViaProxyName "tinyproxy"

ConnectPort 8888
#ConnectPort 80
# The following two ports are used by SSL.
ConnectPort 443
#ConnectPort 563

ReversePath "/configure/" "http://0.0.0.0/"
reversePath "/terminal/" "http://0.0.0.0:3000/"

ReverseOnly Yes
ReverseMagic Yes
ReverseBaseURL "http://0.0.0.0:8888/"

EOF

echo "===> Setting up /etc/init.d/tinyproxy service file for Tinyproxy ..."
rm /etc/init.d/tinyproxy &> /dev/null
cat <<EOF > /etc/init.d/tinyproxy
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

EOF

chmod +x /etc/init.d/tinyproxy
killall tinyproxy
pidof tinyproxy
if [ $? -eq 0 ]; then
    echo "Tinyproxy service is running"
else
    echo "===> Starting Tinyproxy service ..."
    /etc/init.d/tinyproxy start
fi
    }

create_initd_service_configuration_tinyproxy

}

################
# Thornol Setup #
################

thornol_setup() {
    echo "======================"
    echo "Setting up Thornol ..."
    echo "======================"
    source ./auto-setup/5_thornol_setup.sh
}

## Cleanup
cleanup() {
    echo "==============="
    echo "Cleaning up ..."
    echo "==============="

    ## Opkg remove jq and jsonfilter
    echo "Removing jq package ..."
    opkg remove jq
}

################
# Main Program #
################

main() {
    prerequisites_setup
    # check if the failure variable is set to 1 and if yes, exit
    if [ $failure -eq 1 ]; then
        echo "!! Failed to setup prerequisites. Please try again." >&2
        exit 1
    fi
    operating_system_setup
    rathole_setup
    rutty_setup
    # tinyproxy_setup ## Remove tinyproxy setup because it does not support websocket, we have to expose ports directly
    # thornol_setup
    # cleanup

}

main