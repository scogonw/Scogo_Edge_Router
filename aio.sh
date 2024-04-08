#!/bin/sh

# Enable debugging mode
#set -x

# Redirect stdout and stderr to a log file in /tmp directory with a unique file name using the current date and time stamp in the file name format (aio-YYYYMMDD-HHMMSS.log)
#exec > >(tee /tmp/aio-$(date '+%Y%m%d-%H%M%S').log) 2>&1


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
#6 Wrap the script (aio.sh) in a curl one-liner installer and update the README.md file with the curl command
#7 currently the topic for notification are created manually by keyur, we need to automate this by curling the API
#8 Add k8s operator that monitors config map and restart the pods if there is any change in config map

## Update as on 25 March


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

# update the package list
echo "==> Updating the package list ..."
## Todo : uncomment the below line after testing
opkg update

# write an if condition to check if curl , jsonfilter AND jq commands are available and if not, install them

# if condition to check if curl and jsonfilter commands are available and if not, install them
#echo "==> Checking if curl and jsonfilter commands are available ..."
if ! command -v curl &> /dev/null || ! command -v jsonfilter &> /dev/null || ! command -v jq &> /dev/null
then
    echo "==> Installing curl, jsonfilter, jq, coreutils-base64, mwan3, luci-app-mwan3 packages ..."
    opkg install curl coreutils-base64 jsonfilter jq mwan3 luci-app-mwan3 iptables-nft
    # check if the installation was successful
    if [ $? -ne 0 ]; then
        echo "**ERROR** : Failed to install curl, jsonfilter, jq, coreutils-base64, mwan3, luci-app-mwan3 packages. Please try again... Exiting" >&1
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
uci add_list dhcp.@dnsmasq[0].server="/scogo.ser.local/$network_router_ip"
uci set dhcp.lan.dhcp_option="6,$network_router_ip 3,$network_router_ip"
echo "address=/scogo.ser.local/$network_router_ip" >> /etc/dnsmasq.conf
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
root_user=$(jsonfilter -i config.json -e @.device.root_user)
root_password=$(jsonfilter -i config.json -e @.device.root_password)
# Todo : remove the below line before deploying to production
#echo "root:$root_password" | chpasswd
echo -e "$root_password\n$root_password" | passwd $root_user


admin_username=$(jsonfilter -i config.json -e @.device.admin_username)
echo "===> Setting up non-root user $admin_username ..."
admin_password=$(jsonfilter -i config.json -e @.device.admin_password)
useradd -m -s /bin/ash $admin_username  >&1
echo -e "$admin_password\n$admin_password" | passwd $admin_username

}

###############################
# MWAN3 & Notification Setup  #
###############################

mwan3_and_notificatio_setup() {
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
        notification_value=$(jsonfilter -i config.json -e @.notification.$key | tr '[a-z]' '[A-Z]')
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
    #notification_service_auth_key=$(uci get scogo.@notification[0].notification_service_auth_key)
    notification_topic=$(uci get scogo.@notification[0].notification_topic)

    echo "===> Creating Notification Topic ..."
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --location $notification_service_endpoint/v1/topics \
    --header 'Content-Type: application/json' \
    --data '{
        "key": "'"$notification_topic"'",
        "name": "'"$notification_topic"'"
    }')

    if [ $response_code -eq 200 ]; then
        echo ">> Notification Topic $notification_topic created successfully"
    elif [ $response_code -eq 409 ]; then
        echo ">> Notification Topic $notification_topic already exists"
    else
        echo "**ERROR** : Error Code: $response_code, Failed to create Notification Topic. Please check & try again... Exiting" >&1
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
    serial_number=$(uci get scogo.@device[0].serial_number | tr '[A-Z]' '[a-z]')
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
device_name=$(uci get scogo.@device[0].serial_number | tr '[A-Z]' '[a-z]')
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
/etc/init.d/thornol start
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

# if the init.d service does not exist, create it
if [ ! -f /etc/init.d/thornol ]; then
    create_initd_service
    failure=0
else 
    echo "===> Starting Thornol service ..."
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
    opkg remove coreutils-base64 jq --force-depends
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

        operating_system_setup
        if [ $failure -eq 1 ]; then
            echo "**ERROR** : Failed to setup operating system. Please check & try again... Exiting" >&1
            exit 1
        fi

        mwan3_and_notificatio_setup
        if [ $failure -eq 1 ]; then
            echo "**ERROR** : Failed to setup MWAN3 & Notification. Please check & try again... Exiting" >&1
            exit 1
        fi

        rathole_setup
        rutty_setup
        thornol_setup
        cleanup

    } | tee "/tmp/$logfile" >&1

        echo "*********************************************"
        echo "Script finished. Check /tmp/$logfile for details."
        echo "*********************************************"
        echo "##### Important #######"
        echo "Please restart the device to apply the changes"
        echo "########################"

    # access_key_id=$1
    # secret_access_key=$2
    # bucket_name="ser-installaion-logs"
    # region="ap-south-1"
    # endpoint="s3.${region}.amazonaws.com"

    # # Object key (filename) within the bucket
    # # object_key="/tmp/$logfile"  # Create a folder structure with date

    # # Construct the upload URL with placeholders for signature and date
    # upload_url="https://${bucket_name}.${endpoint}/${logfile}"

    # # Generate the authorization signature (not recommended to embed secret key directly)
    # timestamp=$(date -R)  # Get current date in RFC 2822 format

    # # This is a simplified example using SHA1 (AWS recommends using SigV4)
    # # Refer to AWS documentation for secure signature generation: https://www.amazon.com/gp/help/customer/display.html?nodeId=GRGL3L4SXX29V2ZR

    # string_to_sign="PUT\n\n\n${timestamp}\n/s3/${bucket_name}/${object_key}"

    # signature=$(echo -n "${string_to_sign}" | openssl sha1 -hmac "${secret_access_key}" | sed 's/.*=//')

    # # Construct the cURL command
    # curl_command="curl -X PUT -T ${logfile} \
    # -H \"Authorization: AWS ${access_key_id}:${signature}\" \
    # -H \"Content-Type: application/octet-stream\" \
    # -H \"Date: ${timestamp}\" \
    # ${upload_url}"

    # # Execute the cURL command and handle errors
    # response=$(eval "${curl_command}")

    # if [ $? -eq 0 ]; then
    # echo "Log file uploaded successfully to S3!"
    # else
    #     echo "Error uploading log file: $response"
    # # Handle errors (e.g., retry logic, send notification)
    # fi

    # # Your commands here (output and errors will be captured in the log file and uploaded to S3)
    # command1
    # command2
    # # ...

    # echo "Script finished. Check S3 bucket for log details."

}

main