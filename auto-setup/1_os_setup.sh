#!/bin/sh

echo "Setting up the SER Environment ..."
echo "Current Network Configuration ..."
uci show | grep -i network

echo "Adding LAN3 and LAN4 to the LAN Bridge ..."
uci set network.@device[0].ports='lan3 lan4'

## Delete WAN IPv6
echo "Deleting WAN IPv6 ..."
uci delete network.wan
uci delete network.wan6

## Map interface-1 for wan-1/ISP-1
echo "Mapping Port-1 i.e. interface-1 for wan-1/ISP-1 ..."
uci set network.wan1=interface
uci set network.wan1.device='lan1'
uci set network.wan1.proto='dhcp'

## Map interface-2 for wan-2
echo "Mapping Port-2 i.e. interface-2 for wan-2/ISP-2 ..."
uci set network.wan2=interface
uci set network.wan2.device='lan2'
uci set network.wan2.proto='dhcp'
uci commit network
echo "Restarting Network ..."
service network restart

## Remove wan,wan6 from firewall zone and add wan1 and wan2
echo "Removing wan,wan6 from firewall zone and adding wan1 and wan2 ..."
uci set firewall.@zone[1].network='wan wan1 wan2'
uci commit firewall

## Fetch device configuration
curl -o /etc/config/scogo https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/main/scogo/scogo

## Get serial_number from first input to the script and convert that to Upper case
SERIAL_NUMBER=$(jsonfilter -i config.json -e @.serial_number | tr '[a-z]' '[A-Z]')
echo "Setting serial number ..."
uci set scogo.@device[0].serial_number="$SERIAL_NUMBER"

echo "Setting hostname ..."
uci set scogo.@device[0].hostname="SER-$SERIAL_NUMBER"

## Get and Set Make and Model Number
echo "Setting device make ..."
MAKE=$(jsonfilter -i config.json -e @.make | tr '[a-z]' '[A-Z]')
uci set scogo.@device[0].make="$MAKE"

echo "Setting device model number ..."
MODEl=$(jsonfilter -i config.json -e @.model | tr '[a-z]' '[A-Z]')
uci set scogo.@device[0].model="$MODEl"

## Get and Set Asset Number
echo "Setting asset number ..."
ASSET_NUMBER=$(jsonfilter -i config.json -e @.asset_number)
uci set scogo.@device[0].asset_id="$ASSET_NUMBER"

## Set License Key
echo "Setting license key ..."
LICENSE_KEY=$(jsonfilter -i config.json -e @.license_key)
uci set scogo.@device[0].license_key="$LICENSE_KEY"
