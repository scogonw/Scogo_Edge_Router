#!/bin/sh

# Enable debugging mode
#set -x

## Router pre-requisites
#1. Create config.json file with all the configuration details on the router

## Todo
#8 Add k8s operator that monitors config map and restart the pods if there is any change in config map

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
    echo "**ERROR** : Internet is not available. Please check the internet connection and try again.. Exiting" >&1
    failure=1
    exit 1
fi

# if opkg is not installed, abort
if ! command -v opkg &> /dev/null
then
    echo "**ERROR** : opkg is not installed. Please install opkg and try again... Exiting" >&1
    failure=1
    exit 1
fi

# Get df -h output before installation of packages
echo "==> Getting storage utilization information before installation of packages ..."
df -h

# update the package list
echo "==> Updating the package list ..."
## Todo : uncomment the below line after testing
opkg update

# write an if condition to check if curl , jsonfilter AND jq commands are available and if not, install them

# if condition to check if curl and jsonfilter commands are available and if not, install them
#echo "==> Checking if curl and jsonfilter commands are available ..."
if ! command -v curl &> /dev/null || ! command -v jsonfilter &> /dev/null || ! command -v jq &> /dev/null
then
    echo "==> Installing curl, jsonfilter, jq, coreutils-base64, mwan3, luci-app-mwan3, shadow-useradd packages ..."
    opkg install curl coreutils-base64 jsonfilter jq mwan3 luci-app-mwan3 iptables-nft shadow-useradd
    # check if the installation was successful
    if [ $? -ne 0 ]; then
        echo "**ERROR** : Failed to install packages... Exiting" >&1
        failure=1
        exit 1
    fi
fi

echo "==> Getting storage utilization information after installation of packages ..."
df -h

}

##########################
#     Migration Check    #
##########################

migration_check() {
    echo "=============================================="
    echo "Checking for Existing Device Registeration ..."
    echo "=============================================="

    # check if the device has been registered
    if [ -f /usr/lib/thornol/device_registration_response.json ]; then
        # if the device is registered, extract the device id
        device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            echo ">> Device is already registered with device_id: $device_id"
            echo ">> Do you want to delete the device and re-register? (y/n)"
            read -r delete_device
            if [ "$delete_device" == "y" ]; then
                delete_device
            else
                echo ">> Continuing with the existing device registration..."
            fi
        else
            echo ">> Device is not registered, will attempt to register the device..."
        fi
    else
        echo ">> Device is not registered, will attempt to register the device...."
    fi
}

#####################
# Delete Old Device #
#####################

delete_device(){
    echo "===> Deleting the device from store..."
    # get fleet id and project id from uci
    store_fleet_id=$(uci get scogo.@infrastructure[0].golain_fleet_id)
    store_project_id=$(uci get scogo.@infrastructure[0].golain_project_id)
    api_key=$(uci get scogo.@infrastructure[0].golain_api_key)
    org_id=$(uci get scogo.@infrastructure[0].golain_org_id)
    device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
    # check if store_fleet_id and store_project_id are not empty
    if [ -z "$store_fleet_id" ] || [ -z "$store_project_id" ]; then
        echo ">> Error : $store_fleet_id or $store_project_id missing from uci... Exiting"
        exit 1
    fi
    # check if the device is registered
    if [ -f /usr/lib/thornol/device_registration_response.json ]; then
        # if the device is registered, extract the device id
        device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            # delete the device
            curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$store_project_id"'/fleets/'"$store_fleet_id"'/devices/'"$device_id" \
            --header "ORG-ID: $org_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: $api_key" \
            --request DELETE > /usr/lib/thornol/device_deletion_response.json

            # check if the response is successful based on json file
            status=$(jsonfilter -i /usr/lib/thornol/device_deletion_response.json -e @.ok)
            if [ "$status" != "1" ]; then
                echo ">> Error : Failed to delete the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_deletion_response.json -e @.message)"
                exit 1
            fi
        else
            echo ">> Error : $device_id is not set... Exiting"
            exit 1
        fi
    # if the device is not registered, exit
    else 
        echo ">> Error : Device is not registered... Exiting"
        exit 1
    fi
    # remove the thorol directories and files
    rm -rf /usr/lib/thornol
    rm -rf /etc/init.d/thornol
    rm -f /usr/bin/thornol
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
curl -s -o /etc/config/scogo https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/config/scogo
if [ $? -ne 0 ]; then
    echo "**ERROR** : Failed to fetch default UCI configuration for scogo from Github. Please check & try again... Exiting" >&1
    failure=1
    exit 1
fi

echo "===> Setting banner message ..."
model_code=$(jsonfilter -i config.json -e @.device.model_code)
# Check if the model_code variable is not empty
if [ -n "$model_code" ]; then
    # Use the model_code variable as part of the URL in the curl command
    curl -s -o /etc/banner "https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/config/banner_${model_code}"
        if [ $? -ne 0 ]; then
            echo "**ERROR** : Failed to fetch https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/config/banner_${model_code} file from Github. Please check & try again... Exiting" >&1
            failure=1
            exit 1
fi
else
    echo "**ERROR** : Failed to retrieve model code from config.json"
fi

echo "===> Setting up UCI for Device configuration details ..."
# Read all keys without quotes or commas using jq
device_keys=$(jq -r '.device | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $device_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    device_value=$(jsonfilter -i config.json -e @.device.$key)
    echo ">> Running uci set scogo.@device[0].$key=$device_value ..."
    uci set scogo.@device[0]."$key"="$device_value"
done
# unset variable value
unset device_keys
unset device_value
unset IFS
unset key
uci commit scogo

echo "===> Setting up UCI for Site configuration details ..."
# Read all keys without quotes or commas using jq
site_keys=$(jq -r '.site | keys_unsorted | @csv' config.json | sed 's/"//g')
# Split keys into an array using IFS
IFS=, ; set -- $site_keys  # Ash-specific way to split string
# Loop through each key and set the value in UCI
for key do
    site_value=$(jsonfilter -i config.json -e @.site.$key)
    echo ">> Running uci set scogo.@site[0].$key=$site_value ..."
    uci set scogo.@site[0]."$key"="$site_value"
done
# unset variable value
unset site_keys
unset site_value
unset IFS
unset key
uci commit scogo

configure_link1=$(jsonfilter -i config.json -e @.device.configure_link1)
if [ "$configure_link1" == "True" ]; then
    echo "===> Setting up UCI for Link1 configuration details ..."
    # Read all keys without quotes or commas using jq
    link1_keys=$(jq -r '.link1 | keys_unsorted | @csv' config.json | sed 's/"//g')
    # Split keys into an array using IFS
    IFS=, ; set -- $link1_keys  # Ash-specific way to split string
    # Loop through each key and set the value in UCI
    for key do
        link1_value=$(jsonfilter -i config.json -e @.link1.$key)
        echo ">> Running uci set scogo.@link1[0].$key=$link1_value ..."
        uci set scogo.@link1[0]."$key"="$link1_value"
    done
    # unset variable value
    unset link1_keys
    unset link1_value
    unset IFS
    unset key
    uci commit scogo
fi

configure_link2=$(jsonfilter -i config.json -e @.device.configure_link2)
if [ "$configure_link2" == "True" ]; then
    echo "===> Setting up UCI for Link2 configuration details ..."
    # Read all keys without quotes or commas using jq
    link2_keys=$(jq -r '.link2 | keys_unsorted | @csv' config.json | sed 's/"//g')
    # Split keys into an array using IFS
    IFS=, ; set -- $link2_keys  # Ash-specific way to split string
    # Loop through each key and set the value in UCI
    for key do
        link2_value=$(jsonfilter -i config.json -e @.link2.$key)
        echo ">> Running uci set scogo.@link2[0].$key=$link2_value ..."
        uci set scogo.@link2[0]."$key"="$link2_value"
    done
    # unset variable value
    unset link2_keys
    unset link2_value
    unset IFS
    unset key
    uci commit scogo
fi

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
uci commit scogo

echo "===> Printing updated Scogo Configuration ..."
uci show scogo

## setup up wifi
configure_wifi=$(jsonfilter -i config.json -e @.device.configure_wifi)
if [ "$configure_wifi" == "True" ]; then
    echo "===> Setting up WiFi ..."
    uci set wireless.radio0.disabled='0'
    uci set wireless.radio1.disabled='0'
    uci set wireless.@wifi-iface[0].device='radio0'
    uci set wireless.@wifi-iface[1].device='radio1'
    uci set wireless.@wifi-iface[0].ssid="$(jsonfilter -i config.json -e @.device.wifi_ssid)"
    uci set wireless.@wifi-iface[1].ssid="$(jsonfilter -i config.json -e @.device.wifi_ssid)"
    uci set wireless.@wifi-iface[0].key="$(jsonfilter -i config.json -e @.device.wifi_ssid_password)"
    uci set wireless.@wifi-iface[1].key="$(jsonfilter -i config.json -e @.device.wifi_ssid_password)"
    uci set wireless.@wifi-iface[0].encryption='psk2'
    uci set wireless.@wifi-iface[1].encryption='psk2'
    uci commit wireless
else
    echo "===> Skipping WiFi setup ..."
fi

echo "===> Getting Current Network Configuration ..."
uci show network

echo "===> Adding LAN3 and LAN4 to the LAN Bridge ..."
uci set network.@device[0].ports='lan3 lan4'

## Delete WAN IPv6
echo "===> Deleting WAN IPv6 ..."
uci delete network.wan
uci delete network.wan6

## Map interface-1 for wan-1/ISP-1
echo "===> Mapping Port-1 i.e. interface-1 for wan-1/ISP-1 ..."
uci set network.wan1=interface
uci set network.wan1.device='lan1'
uci set network.wan1.proto='dhcp'

## Map interface-2 for wan-2
echo "===> Mapping Port-2 i.e. interface-2 for wan-2/ISP-2 ..."
uci set network.wan2=interface
uci set network.wan2.device='lan2'
uci set network.wan2.proto='dhcp'
uci commit network

echo "===> Enabling software and hardware flow offloading ..."
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall

echo "===> Configuring LAN ..."
model_code=$(jsonfilter -i config.json -e @.device.model_code)
echo "===> Setting up Network Configuration for model code $model_code  ..."
if [ "$model_code" == "C6UT" ]; then
    echo "===> Fetching default network configuration for model code $model_code ..."
    curl -s -o /etc/config/network https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/network/C6UT_network
    if [ $? -ne 0 ]; then
        echo "**ERROR** : Failed to fetch default network configuration for model code: $model_code from Github. Please check & try again... Exiting" >&1
        failure=1
        exit 1
    fi
else
    echo "**ERROR** : Incorrect model code $model_code in config.json ... exiting"
    exit 1
fi

network_router_ip=$(jsonfilter -i config.json -e @.device.network_router_ip)
network_router_domain=$(jsonfilter -i config.json -e @.device.network_router_domain)
echo "===> Setting up Router IP and Domain ..."
uci set network.lan.ipaddr="$network_router_ip"
uci set dhcp.@dnsmasq[0].server="$network_router_ip"
uci add_list dhcp.@dnsmasq[0].server="/$network_router_domain/$network_router_ip"
uci set dhcp.lan.dhcp_option="6,$network_router_ip 3,$network_router_ip"
echo "address=/$network_router_domain/$network_router_ip" >> /etc/dnsmasq.conf
uci commit dhcp
uci commit network
service dnsmasq restart

echo "===> Setting up Hostname, Description, Timezone and Zonename ..."
make=$(jsonfilter -i config.json -e @.device.make)
series=$(jsonfilter -i config.json -e @.device.series)
model=$(jsonfilter -i config.json -e @.device.model)

uci set system.@system[0].hostname="$(jsonfilter -i config.json -e @.device.hostname | tr '[a-z]' '[A-Z]')"
uci set system.@system[0].description="$make $series $model"
uci set system.@system[0].timezone="$(jsonfilter -i config.json -e @.device.timezone)"
uci set system.@system[0].zonename="$(jsonfilter -i config.json -e @.device.zonename)"
uci commit system

echo "===> Setting up Firewall Zones ..."
uci set firewall.@zone[1].network='wan wan1 wan2'
uci commit firewall
echo "===> Restarting Firewall Service ..."
/etc/init.d/firewall reload

echo "===> Setting up root user password ..."
root_user=$(jsonfilter -i config.json -e @.device.root_username)
root_password=$(jsonfilter -i config.json -e @.device.root_password)
echo -e "$root_password\n$root_password" | passwd $root_user

admin_username=$(jsonfilter -i config.json -e @.device.admin_username)
echo "===> Setting up non-root user $admin_username ..."
admin_password=$(jsonfilter -i config.json -e @.device.admin_password)
useradd -m -s /bin/ash $admin_username  >&1
echo -e "$admin_password\n$admin_password" | passwd $admin_username

echo ">> Configuring permissions for user $admin_username ..."
chmod 0700 /sbin/uci
chmod 0600 /etc/config/scogo
chmod 0600 /root/aio.sh &> /dev/null
chmod 0600 /root/config.json &> /dev/null

uci add rpcd login
uci set rpcd.@login[1].username="${admin_username}"
uci set rpcd.@login[1].password='$p$scogo'
uci add_list rpcd.@login[1].read='*'
uci add_list rpcd.@login[1].write='*'
uci commit rpcd

}

###############################
# MWAN3 & Notification Setup  #
###############################

mwan3_and_notification_setup() {
    echo "===================================="
    echo "Setting up MWAN3 & Notification ... "
    echo "===================================="
    
    echo "===> Setting up MWAN3 ..."
    curl -s -o /etc/config/mwan3 https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/mwan3/mwan3
    if [ $? -ne 0 ]; then
        echo "**ERROR** : Failed to fetch default mwan3 configuration from Github. Please check & try again... Exiting" >&1
        failure=1
        exit 1
    fi
    service mwan3 restart

    echo "===> Setting up MWAN3 Notification Action ..."
    curl -s -o /etc/mwan3.user https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/mwan3/mwan3.user
    if [ $? -ne 0 ]; then
        echo "**ERROR** : Failed to fetch default mwan3.user configuration from Github. Please check & try again... Exiting" >&1
        failure=1
        exit 1
    fi

    echo "===> Setting up UCI for Notification configuration details ..."
    # Read all keys without quotes or commas using jq
    notification_keys=$(jq -r '.notification | keys_unsorted | @csv' config.json | sed 's/"//g')
    # Split keys into an array using IFS
    IFS=, ; set -- $notification_keys  # Ash-specific way to split string
    # Loop through each key and set the value in UCI
    for key do
        notification_value=$(jsonfilter -i config.json -e @.notification.$key)
        echo ">> Running uci set scogo.@notification[0].$key=$notification_value ..."
        uci set scogo.@notification[0]."$key"="$notification_value"
    done
    # unset variable value
    unset notification_keys
    unset notification_value
    unset IFS
    unset key
    uci commit scogo

    echo "===> Setting up Notifications ..."
    notification_service_endpoint=$(uci get scogo.@notification[0].notification_service_endpoint | tr '[A-Z]' '[a-z]')
    # Todo : Uncomment the below line before deploying to production, when authenticaion for notification service is enabled
    notification_service_auth_key=$(uci get scogo.@notification[0].notification_service_auth_key)
    notification_topic=$(uci get scogo.@notification[0].notification_topic)

    echo "===> Creating Notification Topic ..."
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --insecure --location $notification_service_endpoint/v1/topics \
    --header "Authorization: $notification_service_auth_key" \
    --header 'Content-Type: application/json' \
    --data '{
        "key": "'"$notification_topic"'",
        "name": "'"$notification_topic"'"
    }')

    if [ $response_code -eq 200 ] || [ $response_code -eq 201 ]; then
        echo ">> Notification Topic $notification_topic created successfully"
    elif [ $response_code -eq 409 ]; then
        echo ">> Notification Topic $notification_topic already exists"
    else
        echo "**ERROR** : Error Code: $response_code, Failed to create Notification Topic. Please check & try again... Exiting" >&1
        failure=1
        exit 1
    fi

    echo "===> Adding Subscribers to Topic ..."
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --insecure --location $notification_service_endpoint/v1/topics/$notification_topic/subscribers \
    --header "Authorization: $notification_service_auth_key" \
    --header 'Content-Type: application/json' \
    --data '{
        "subscribers": [
            "10001",
            "10002",
            "10003",
            "10004",
            "10006",
            "10007"
        ]
    }')

    if [ $response_code -eq 200 ] || [ $response_code -eq 201 ]; then
        echo ">> Subscribers added to $notification_topic created successfully"
    else
        echo "**ERROR** : Error Code: $response_code, Failed to add subscribers to topic. Please check & try again... Exiting" >&1
        failure=1
        exit 1
    fi

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
    serial_number=$(uci get scogo.@device[0].serial_number | tr '[a-z]' '[A-Z]')
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
EOF
chmod 0600 /etc/config/rathole-client.toml

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
    if [ $(echo '$?') -eq 0 ]; then
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
        curl -s -o /usr/bin/rathole "https://scogo-ser.s3.ap-south-1.amazonaws.com/rathole/target/mipsel-unknown-linux-musl/release/rathole"
        chmod +x /usr/bin/rathole
    fi

    # if /etc/init.d/rathole service file does not exist, create it
    if [ -f /etc/init.d/rathole ]; then
        rm -f /var/etc/rathole-client.toml &> /dev/null
        rm -f /etc/init.d/rathole &> /dev/null
        create_initd_service_rathole
    else
        create_initd_service_rathole

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
hostname=$(uci get scogo.@device[0].hostname | tr '[a-z]' '[A-Z]')

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
    if [ $(echo '$?') -eq 0 ]; then
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
        killall rutty  &> /dev/null
        curl -s -o /usr/bin/rutty "https://scogo-ser.s3.ap-south-1.amazonaws.com/rutty/target/mipsel-unknown-linux-musl/release/rutty"
        chmod +x /usr/bin/rutty
    fi


    # if the /etc/init.d/rutty service does not exist, create it
    if [ -f /etc/init.d/rutty ]; then
        rm -f /etc/init.d/rutty &> /dev/null
        create_initd_service_rutty
    else 
        create_initd_service_rutty
    fi

}

################
# Thornol Setup #
################

thornol_setup() {
echo "======================"
echo "Setting up Thornol ..."
echo "======================"

# Create required directories
mkdir -p /usr/lib/thornol/certs

# Seting variables
api_key=$(uci get scogo.@infrastructure[0].golain_api_key)
device_name=$(uci get scogo.@device[0].serial_number | tr '[a-z]' '[A-Z]')
project_id=$(uci get scogo.@infrastructure[0].golain_project_id)
org_id=$(uci get scogo.@infrastructure[0].golain_org_id)
fleet_id=$(uci get scogo.@infrastructure[0].golain_fleet_id)
fleet_device_template_id=$(uci get scogo.@infrastructure[0].golain_fleet_device_template_id)

# Check if all the variables are set, if not exit
if [ -z "$api_key" ] || [ -z "$device_name" ] || [ -z "$project_id" ] || [ -z "$org_id" ] || [ -z "$fleet_id" ] || [ -z "$fleet_device_template_id" ]; then
    echo ">> Error : One or more variables are not set...Exiting"
    exit 1
fi

. /usr/share/libubox/jshn.sh

download_thornol_binary(){
# replace the thornol binary if exists
if [ -f /usr/bin/thornol ]; then
    rm /usr/bin/thornol
fi

# Download the binary using curl
echo "===> Downloading the latest version of Thornol binary ..."
curl -s -o /usr/bin/thornol "https://binaries.scogo.golain.io/thornol_app"
# Make the binary executable
chmod +x /usr/bin/thornol
}

create_new_device() {
# Register a new device based on a device template
echo "===> Registering a new device based on device template ..."

curl -s --location "https://api.golain.io/core/api/v1/projects/$project_id/fleets/$fleet_id/devices/bulk" \
--header "ORG-ID: $org_id" \
--header "Content-Type: application/json" \
--header "Authorization: $api_key" \
--data '{
    "device_count": 1,
    "fleet_device_template_id": "'"$fleet_device_template_id"'",
    "device_names": ["'"$device_name"'"]
}' > /usr/lib/thornol/device_registration_response.json

# Check if the response is successful based on json file
status=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.ok)
if [ "$status" != "1" ]; then
    echo ">> Error : Failed to register the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.message)"
    echo ">> For more details check /usr/lib/thornol/device_registration_response.json file... Exiting"
    exit 1
fi

}

setup_shadow_config_values(){
echo "===> Setting up Shadow Config values ..."
device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
curl -s "https://api.golain.io/core/api/v1/projects/$project_id/fleets/$fleet_id/devices/$device_id/shadow" \
--header "ORG-ID: $org_id" \
--header "Content-Type: application/json" \
--header "Authorization: $api_key" \
--data-raw '{"shadow":{"ifaces":[],"interfacesToRead":["lan1","lan2","lan3","lan4","phy0-ap0","phy1-ap0"],"lanMappings":["lan3","lan4","phy0-ap0","phy1-ap0"],"speedTestStatus":"UNKNOWN","uptime":0,"wan1Mapping":"lan1","wan2Mapping":"lan2","wifi5Mapping":"phy1-ap0","wifiMapping":"phy0-ap0"}}' > /usr/lib/thornol/shadow_config_setup_response.json
}

provision_new_certificate_for_device(){
# Extract the device id from the response
device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
# Ensure api_key and device_name are defined
if [ -z "$device_id" ]; then
    echo ">> Error : device_id is not set... Exiting"
    exit 1
fi
# Provision new certificates for the device and decode the response from base64
echo "===> Provisioning new certificates for the device ..."
curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$project_id"'/fleets/'"$fleet_id"'/devices/'"$device_id"'/certificates' \
--header 'ORG-ID: '"$org_id"'' \
--header 'Content-Type: application/json' \
--header 'Authorization: '"$api_key"'' \
--data '{}' > /usr/lib/thornol/device_certificate_response.json
} 

extract_connection_settings(){
# Load JSON data into jshn
json_load_file /usr/lib/thornol/device_certificate_response.json
# Navigate to the certificates object
json_select certificates
# Extract and decode connection settings
json_get_var connection_settings "connection_settings.json"
echo "$connection_settings" | base64 -d > /usr/lib/thornol/connection_settings.json
# Extract and decode device certificate
json_get_var device_cert "device_cert.pem"
echo "$device_cert" | base64 -d > /usr/lib/thornol/certs/device_cert.pem
# Extract and decode device private key
json_get_var device_private_key "device_private_key.pem"
echo "$device_private_key" | base64 -d > /usr/lib/thornol/certs/device_private_key.pem
# Extract and decode root CA certificate
json_get_var root_ca_cert "root_ca_cert.pem"
echo "$root_ca_cert" | base64 -d > /usr/lib/thornol/certs/root_ca_cert.pem
}

apply_device_tags(){
    echo "===> Applying device tags to the device ..."
    # get the device tags from config.json
    device_tags=$(jq -c '.device.tags' config.json)
    echo "===> Found device tags: $device_tags"
    # if the device tags are not empty
    if [ ! -z "$device_tags" ]; then
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            json_payload="{\"tag_names\":$device_tags}"
            # apply the device tags to the device
            echo "===> Applying device tags to the device ..."
            curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$project_id"'/fleets/'"$fleet_id"'/devices/'"$device_id"'/tags_by_name' \
            --header "ORG-ID: $org_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: $api_key" \
            --data "$json_payload" > /usr/lib/thornol/device_tags_response.json
            # check if the response is successful based on json file
            status=$(jsonfilter -i /usr/lib/thornol/device_tags_response.json -e @.ok)
            if [ "$status" != "1" ]; then
                echo ">> Error : Failed to apply device tags to the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_tags_response.json -e @.message)"
                exit 1
            fi
        fi
    fi
}

add_device_metadata(){
    echo "===> Fetching Device Metadata ..."
    # pickup relevant metadata from config.json
    device_metadata=$(jq -c '{device, site, link1, link2, notification}' config.json)
    # if metadata is not empty
    if [ ! -z "$device_metadata" ]; then
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            # apply the device metadata to the device
            echo "===> Adding metadata to the device ..."
            curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$project_id"'/fleets/'"$fleet_id"'/devices/'"$device_id"'/meta' \
            --header "ORG-ID: $org_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: $api_key" \
            --data "$device_metadata" > /usr/lib/thornol/device_metadata_response.json
            # check if the response is successful based on json file
            status=$(jsonfilter -i /usr/lib/thornol/device_metadata_response.json -e @.ok)
            if [ "$status" != "1" ]; then
                echo ">> Error : Failed to add device metadata to the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_metadata_response.json -e @.message)"
                exit 1
            fi
        fi
    fi
}

add_device_location(){
    echo "===> Fetching Device Location ..."
    #get the device location from config.json
    location_string=$(uci get scogo.@site[0].device_latitude_longitude)
    latitude=$(echo $location_string | cut -d, -f1)
    longitude=$(echo $location_string | cut -d, -f2)
    # if locations are not empty
    if [ ! -z "$latitude" ] && [ ! -z "$longitude" ]; then
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            json_payload="{\"location\":{\"latitude\":$latitude,\"longitude\":$longitude}}"
            # apply the device tags to the device
            echo "===> Updating Device Location Metadata ..."
            curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$project_id"'/fleets/'"$fleet_id"'/devices/'"$device_id"'/location' \
            --header "ORG-ID: $org_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: $api_key" \
            --data "$json_payload" > /usr/lib/thornol/device_location_response.json
            # check if the response is successful based on json file
            status=$(jsonfilter -i /usr/lib/thornol/device_location_response.json -e @.ok)
            if [ "$status" != "1" ]; then
                echo ">> Error : Failed to set device location. Reason: $(jsonfilter -i /usr/lib/thornol/device_location_response.json -e @.message)"
                exit 1
            fi
        fi
    fi
}

create_initd_service() {
# Create a init.d service for the binary
echo "===> Setting up /etc/init.d/thornol service file for Thornol ..."
cat <<EOF > /etc/init.d/thornol
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance thornol
    procd_set_param command /usr/bin/thornol

    procd_set_param limits core="unlimited"
    procd_set_param env GO_ENV=dev CONFIG_DIR=/usr/lib/thornol/
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn

    procd_set_param pidfile /var/run/thornol.pid
    procd_set_param user root
    procd_close_instance
}

restart_service() {
    stop
    start
}

EOF

chmod +x /etc/init.d/thornol
/etc/init.d/thornol enable
echo "===> Starting Thornol service ..."
/etc/init.d/thornol restart
}

failure=1
is_dev=1
# check if the device is a dev registered device
if [ -f /usr/lib/thornol/prod ]; then
    is_dev=0
fi

# if the /usr/lib/thornol/device_registration_response.json file does not exist or does not have the `ok` key set to 1
if [ ! -f /usr/lib/thornol/device_registration_response.json ] || [ "$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.ok)" != "1" ]; then
    # and if the connection_settings file does not exist
    if [ ! -f /usr/lib/thornol/connection_settings.json ]; then
        create_new_device
        setup_shadow_config_values
        apply_device_tags
    fi
fi

# if the /usr/lib/thornol/device_certificate_response.json file does not exist or does not have the `ok` key set to 1
if [ ! -f /usr/lib/thornol/device_certificate_response.json ] || [ "$(jsonfilter -i /usr/lib/thornol/device_certificate_response.json -e @.ok)" != "1" ]; then
    # and if the device_private_key file does not exist
    if [ ! -f /usr/lib/thornol/certs/device_private_key.pem ]; then
        provision_new_certificate_for_device
    fi
fi

# extract the connection settings & certificates
if [ ! -f /usr/lib/thornol/certs/device_private_key.pem ]; then
    extract_connection_settings
fi

download_thornol_binary
add_device_metadata
add_device_location

# if the init.d service does not exist, create it
if [ ! -f /etc/init.d/thornol ]; then
    create_initd_service
    failure=0
else 
    echo "===> Starting Thornol service ..."
    /etc/init.d/thornol stop
    /etc/init.d/thornol restart
    failure=0
fi
}

## Cleanup
cleanup() {
    echo "==============="
    echo "Cleaning up ..."
    echo "==============="

    ## Opkg remove jq and
    echo "===> Removing coreutils-base64 jq package ..."
    opkg remove coreutils-base64 jq shadow-useradd --force-depends
}

## Upload Log file to Scogo Asset Inventory
upload_log_file() {

    echo "======================="
    echo "Uploading Log File ..."
    echo "======================="

    ## Upload the log file to scogo asset inventory against the device serial number
    echo "===> Uploading log file to Scogo Asset Inventory ..."
    asset_file_upload_endpoint="https://ydzkg5tj55.execute-api.ap-south-1.amazonaws.com/prod/api/webhooks/assets/config"
    serial_number=$(uci get scogo.@device[0].serial_number | tr '[a-z]' '[A-Z]')
    #logfile="lastlog"
    # convert the log file to base64
    base64_logfile=$(base64 -w 0 "/var/log/$logfile")
    # Create a payload for the API request that should include the "serial_number": "serial number", "mime_type": "application/json", "file": filebase64 encoded log file
    payload='{"serial_number": "'"$serial_number"'", "mime_type": "text/plain", "file": "'"$base64_logfile"'", "action": "installation_log_file"}'
    # Send the payload to the API endpoint in --data option , add the endpoint in --location option , add the headers in --header option the headers should include the content type as application/json
    curl -s -o /var/log/upload_log_file_response.json --location $asset_file_upload_endpoint \
    --header "Content-Type: application/json" \
    --data "$payload"

    response_code=$(jsonfilter -i /var/log/upload_log_file_response.json -e @.code)
    response_message=$(jsonfilter -i /var/log/upload_log_file_response.json -e @.data.message)

    ## check if the response code is 200 and if not, write the error to stderr including the response code and message from the API and exit
    if [ $response_code -eq 200 ]; then
        echo ">> Log file uploaded successfully to Scogo Asset Inventory"
    else
        echo "**ERROR** : Failed to upload log file to Scogo Asset Inventory. Error Code: $response_code, Message: $response_message Please check & try again... Exiting" >&1
        exit 1
    fi

}

upload_config_file() {
    echo "=========================="
    echo "Uploading Config File ..."
    echo "=========================="
    ## Upload the config.json file to scogo asset inventory against the device serial number
    echo "===> Uploading config.json file to Scogo Asset Inventory ..."
    asset_file_upload_endpoint="https://ydzkg5tj55.execute-api.ap-south-1.amazonaws.com/prod/api/webhooks/assets/config"
    serial_number=$(uci get scogo.@device[0].serial_number | tr '[a-z]' '[A-Z]')
    #logfile="lastlog"
    # convert the config.json file to base64
    base64_configfile=$(base64 -w 0 "/root/config.json")
    # Create a payload for the API request that should include the "serial_number": "serial number", "mime_type": "application/json", "file": filebase64 encoded config.json file
    payload='{"serial_number": "'"$serial_number"'", "mime_type": "application/json", "file": "'"$base64_configfile"'", "action": "device_config_file"}'
    # Send the payload to the API endpoint in --data option , add the endpoint in --location option , add the headers in --header option the headers should include the content type as application/json
    curl -s -o /var/log/upload_config_file_response.json -w "%{http_code}" --location $asset_file_upload_endpoint \
    --header "Content-Type: application/json" \
    --data "$payload"

    response_code=$(jsonfilter -i /var/log/upload_config_file_response.json -e @.code)
    response_message=$(jsonfilter -i /var/log/upload_config_file_response.json -e @.data.message)

    if [ $response_code -eq 200 ]; then
        echo ">> Config file uploaded successfully to Scogo Asset Inventory"
    else
        echo "**ERROR** : Failed to upload /root/config.json file to Scogo Asset Inventory. Error Code: $response_code, Message: $response_message Please check & try again... Exiting" >&1
        exit 1
    fi

}

################
# Main Program #
################

main() {

    logfile="ser-setup-log-$(date '+%Y%m%d-%H%M%S').log"

    {

        if [ ! -f config.json ]; then
            echo "**ERROR** : config.json file not found in current working directory. Please create the file and try again." >&1
            exit 1
        fi

        echo "******************************************"
        echo "Scogo Edge Router All-in-One Setup Script"
        echo "Log file path : $logfile"
        echo "******************************************"
        echo

        prerequisites_setup
        if [ $failure -eq 1 ]; then
            echo "**ERROR** : Failed to setup prerequisites. Please check & try again... Exiting" >&1
            exit 1
        fi

        migration_check

        operating_system_setup
        if [ $failure -eq 1 ]; then
            echo "**ERROR** : Failed to setup operating system. Please check & try again... Exiting" >&1
            exit 1
        fi

        mwan3_and_notification_setup
        if [ $failure -eq 1 ]; then
            echo "**ERROR** : Failed to setup MWAN3 & Notification. Please check & try again... Exiting" >&1
            exit 1
        fi

        rathole_setup
        rutty_setup
        thornol_setup
        upload_config_file

    } | tee "/var/log/$logfile" >&1

    upload_log_file
    cleanup

    echo "***************************************************************************"
    echo "Setup Completed ... Check /var/log/$logfile for details."
    echo "****************************************************************************"
    echo
    echo
    echo "################ IMPORTANT ################################"
    echo "You *MUST* restart the device to apply the network changes"
    echo "###########################################################"

}

main
