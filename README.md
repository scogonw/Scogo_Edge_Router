## TODO

- Test if we need to add entries in https://github.com/scogonw/Scogo_Edge_Router/blob/prod/config/scogo if we need to set anything from uci set command. Does the entry in UCI set command is required in the config file?
  
- Enable admin user (non root) access to LUCI web interface

- useradd command output is failing and not able to capture the output in the log file. Need to fix this issue.
```
root@OpenWrt:~# useradd -m -s /bin/ash $admin_username  >&1 | tee /tmp/test1-20240403-130823.log
-ash: useradd: not found
root@OpenWrt:~#
```

- Karan: 
    - [ ] Fix DHCP warning issue (dhcp_option)
    - [ ] Check if rathole and rutty installation and configuration can directly go into the Image. Such that upon resetting the device, it should revert back to original firmware image that should be remotely managed / configured. This could be a savior backdoor in case of failure, we can get the device resetted and take remote control.
    - [ ] Check if rutty UI could be integrated in Argon/Luci theme, left bottom section as <Device Terminal>, this should be only visible to root user

- Surya: 
    - [ ] Test notification with following changes
      - [ ] Remove one cable from the router and check if notification is received
      - [ ] Remove one cable from the ISP router end and check if notification is received
      - [ ] Power off the ISP router and check if notification is received
    - [ ]  If link-1 is showing packet drops or link flapping or fluctuating, then mwan3 should automatically make link-2 as primary and link-1 as secondary. This should be done automatically without any manual intervention.

- Keyur : 
    - [ ] discuss how notification service could be extended to push data over Webhooks or HTTP endpoint to create new service tickets on scogo platform or on 3rd party ticketing system 
    - [x] Provide notification endpoint to Ishan with correct payload format to send notifications to subscribers

- Ishan: 
    - [ ] Add scogo notification API to Golan's rule engine to send notifications to subscribers in case of device is offline with retries mechanisms
    - [ ] Possiblity of submitting remote commands to device and get output back from the device
    - [ ] use `enable_dashboard` flag to enable/disable the dashboard for the device automatically
    - [ ] Textual changes in Golain UI
        - [ ] Scogo.Default ==> Scogo.Scogo-Store (change default to Scogo-Store)
        - [ ] Change "Scogo-Store" fleet to "Master Warehouse"
            - [ ] Scogo Final Convention : Scogo.Scogo-Store."Master Warehouse"
            - [ ] Connect4Sure Final Naming convention ==> Scogo.Connect4Sure."Master Warehouse"
            - [ ] Spectra Final Naming convention ==> Scogo.Spectra."Master Warehouse"
    - [ ] Perform the dashboard UI changes as discuss on saturday meeting

# Scogo Edge Router Configuration
1. Copy `config_Serial_Number.json` locally and update the values as needed.
2. Move this file to the router's `/root` directory.
3. Get `aio.sh` file from Internet and move it to the router's `/root` directory.
4. Run the following commands:
```bash
curl -o aio.sh https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/aio.sh
chmod +x aio.sh
./aio.sh
```
OR 
```bash
sh -c "$(curl -sSL https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/aio.sh)"
```
Sit back and relax. The script will take care of the rest.
#### Post successful run
1. Once the script is done, reboot the router.
2. Go to [golain dashboard](https://scogo.golain.io) and check if the router is connected.
3. delete the `config.json` file from the router.


# Scogo Edge Router Customer Provisioning / Migration
- If the device has already been provisioned, and no manual cleanup / deletion was done, then the script will detect this and give the user the option to re-provision the device with new credentials based on `config.json` file.
- If the device has been manually deleted from the golain dashboard, then manually delete the thornol config dirs and files from the router and run the script again.