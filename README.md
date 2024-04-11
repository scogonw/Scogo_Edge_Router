## TODO

- Test if we need to add entries in https://github.com/scogonw/Scogo_Edge_Router/blob/prod/config/scogo if we need to set anything from uci set command. Does the entry in UCI set command is required in the config file?
  
- Enable admin user (non root) access to LUCI web interface

- useradd command output is failing and not able to capture the output in the log file. Need to fix this issue.
```
root@OpenWrt:~# useradd -m -s /bin/ash $admin_username  >&1 | tee /tmp/test1-20240403-130823.log
-ash: useradd: not found
root@OpenWrt:~#

- Karan: 
    1) Fix DHCP warning issue (dhcp_option)
    2) fix non root user creation issue


- Keyur : 
    1) Move all services to production 
    2) discuss how notification service could be extended to push data over Webhooks or HTTP endpoint to create new service tickets on scogo platform or on 3rd party ticketing system 
    3) Provide notification endpoint to Ishan with correct payload format to send notifications to subscribers
    4) Upload log file to S3 and store it against right serial number in the database

- Ishan : 
    0) Fix API key issue
    1) Double check the submitted PR on aio.sh so that the tags defined in config.json should get auto-applied to devices at the time of registration
    2) Submit PR for device migration script from one fleet to another
    3) Add scogo notification API to Golan's rule engine to send notifications to subscribers in case of device is offline with retries mechanisms
    4) Possiblity of submitting remote commands to device and get output back from the device
```

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

sh -c "$(curl -sSL https://raw.githubusercontent.com/scogonw/Scogo_Edge_Router/prod/aio.sh)"
```
1. Sit back and relax. The script will take care of the rest.
2. Once the script is done, reboot the router.
3. Go to golain dashboard and check if the router is connected.
4. delete the `config.json` file from the router.


# Scogo Edge Router Customer Provisioning / Migration
Today on Golain, projects are seperated at the schema level. This means that each project has its own database schema. This is done to ensure that data is isolated and secure. This also means that each project has its own set of tables and data.

The above makes it challenging to simply migrate / move one device from a project or fleet to another. This is because the device is tied to a specific schema and moving it to another project would mean that the device would need to be re-provisioned.

The migration script would simply delete the device from the current project and re-provision it in the new project. This would mean that the device would lose all its data and would need to be re-configured.

Watch out for:
1. Ensure that the device actually exists in the current project and fleet  (default.scogo-store).
2. migrate.json file should be present in the router to pick up the device details from. This file should be deleted after the migration is complete.
3. Device name will be picked up from UCI config. Ensure that the device name is unique even in the new project.
5. Golain `OrgID` and `api_key` values will remain the same across all migrations, and will be picked up from UCI config.
4. All data tied to the device in the original project would be lost after the migration is complete.
