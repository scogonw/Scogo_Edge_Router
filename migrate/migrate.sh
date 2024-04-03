#!/bin/sh

## migrates the device from one project / fleet to another
## steps: 
### 1.delete current device 
### 2.create new device in new project / fleet 
### 3.update shadow
### 4.update tags


#####################
# Delete Old Device #
#####################
delete_device(){
    # check if the device is registered
    if [ -f /usr/lib/thornol/device_registration_response.json ]; then
        # if the device is registered, extract the device id
        device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
        # if the device id is not empty
        if [ ! -z "$device_id" ]; then
            # delete the device
            echo "===> Deleting the device ..."
            curl -s --location 'https://api.golain.io/core/api/v1/projects/'"$project_id"'/fleets/'"$fleet_id"'/devices/'"$device_id" \
            --header "ORG-ID: $org_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: APIKEY $api_key" \
            --request DELETE > /usr/lib/thornol/device_deletion_response.json

            # check if the response is successful based on json file
            status=$(jsonfilter -i /usr/lib/thornol/device_deletion_response.json -e @.ok)
            if [ "$status" != "1" ]; then
                echo ">> Error : Failed to delete the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_deletion_response.json -e @.message)"
                exit 1
            fi
        else
            echo ">> Error : device_id is not set... Exiting"
            exit 1
        fi
    # if the device is not registered, exit
    else 
        echo ">> Error : Device is not registered... Exiting"
        exit 1
    fi

}



################
# Thornol Setup #
################

# This is a lift from the aio.sh script

thornol_setup() {
echo "======================"
echo "Setting up Thornol ..."
echo "======================"

# Create required directories
mkdir -p /usr/lib/thornol/certs

# Seting variables
api_key=$(uci get scogo.@infrastructure[0].golain_api_key)
device_name=$(uci get scogo.@device[0].serial_number | tr '[A-Z]' '[a-z]')
org_id=$(uci get scogo.@infrastructure[0].golain_org_id)
# get these from migrate.json
project_id=$(jq -r '.project_id' migrate.json)
fleet_id=$(jq -r '.fleet_id' migrate.json)
fleet_device_template_id=$(jq -r '.fleet_device_template_id' migrate.json)

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
--header "Authorization: APIKEY $api_key" \
--data '{
    "device_count": 1,
    "fleet_device_template_id": "'"$fleet_device_template_id"'",
    "device_names": ["'"$device_name"'"]
}' > /usr/lib/thornol/device_registration_response.json

# Check if the response is successful based on json file
status=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.ok)
if [ "$status" != "1" ]; then
    echo ">> Error : Failed to register the device. Reason: $(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.message)"
    exit 1
fi

}

setup_shadow_config_values(){
echo "===> Setting up Shadow Config values ..."
device_id=$(jsonfilter -i /usr/lib/thornol/device_registration_response.json -e @.data.deviceIds[0])
curl -s "https://api.golain.io/core/api/v1/projects/$project_id/fleets/$fleet_id/devices/$device_id/shadow" \
--header "ORG-ID: $org_id" \
--header "Content-Type: application/json" \
--header "Authorization: APIKEY $api_key" \
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
--header 'Authorization: APIKEY '"$api_key"'' \
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
echo "$device_cert" | base64 -d > /usr/lib/thornol/certs/device_cert.pem &> /dev/null
# Extract and decode device private key
json_get_var device_private_key "device_private_key.pem"
echo "$device_private_key" | base64 -d > /usr/lib/thornol/certs/device_private_key.pem &> /dev/null
# Extract and decode root CA certificate
json_get_var root_ca_cert "root_ca_cert.pem"
echo "$root_ca_cert" | base64 -d > /usr/lib/thornol/certs/root_ca_cert.pem &> /dev/null
}

apply_device_tags(){
    # get the device tags from the migrate.json file
    device_tags=$(jq -c '.device.device_tags' migrate.json)
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
            --header "Authorization: APIKEY $api_key" \
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

    ## Opkg remove jq and jsonfilter
    echo "===> Removing coreutils-base64 jsonfilter jq package ..."
    opkg remove coreutils-base64 jsonfilter jq --force-depends
}

################
# Main Program #
################

main() {
    
    if [ ! -f migrate.json ]; then
        echo "**ERROR** : migrate.json file not found in current working directory. Please create the file and try again." >&2
        exit 1
    fi
    
    delete_device
    thornol_setup
    apply_device_tags
    cleanup

}

main