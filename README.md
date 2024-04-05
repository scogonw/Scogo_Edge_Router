## TODO

- Update Banner file for C6UT also in github
- Test if we need to add entries in https://github.com/scogonw/Scogo_Edge_Router/blob/prod/config/scogo if we need to set anything from uci set command. Does the entry in UCI set command is required in the config file?
  
  
- Setup mwan3.user script file, configure as per keyurs API response and run the script
- Enable admin user access to LUCI web interface

- useradd command output is failing and not able to capture the output in the log file. Need to fix this issue.
```
root@OpenWrt:~# useradd -m -s /bin/ash $admin_username  >&1 | tee /tmp/test1-20240403-130823.log
-ash: useradd: not found
root@OpenWrt:~#
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