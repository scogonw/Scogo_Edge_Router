# #!/bin/sh

# jsonfilter -i config.json -e @.hostname
# jsonfilter -i config.json -e @.rathole_default_token


#!/bin/sh

# # Iterate over all keys in config.json
# while read -r key value; do
#     # Handle special cases for serial_number and hostname
#     if [[ $key = "serial_number" ]]; then
#         value=$(echo "$value" | tr '[a-z]' '[A-Z]')  # Convert to upper case
#         uci set scogo.@device[0].hostname="SER-$value"  # Set hostname
#     fi

#     echo ">> Setting $key ..."
#     uci set scogo.@device[0]."$key"="$value"  # Set the value using uci set
# done < <(jsonfilter -i config.json -e @.*)

# KEYS=$(jq -r '. | keys_unsorted | @csv' config.json | sed 's/"//g')


# Path to your JSON file
json_file="config.json"

# Read all keys without quotes or commas using jq
keys=$(jq -r '. | keys_unsorted | @csv' config.json | sed 's/"//g')


#echo $keys

# Split keys into an array using IFS
IFS=, ; set -- $keys  # Ash-specific way to split string

# Loop through each key
for key do
    value=$(jsonfilter -i config.json -e @.$key | tr '[a-z]' '[A-Z]')
    echo ">> Setting $key=$value ..."
    uci set scogo.@device[0]."$key"="$value"
done