## TODO
- Setup notification
- Enable admin user access to LUCI web interface


# Scogo Edge Router Configuration
1. Copy `config.json` locally and update the values as needed.
2. Move this file to the router's `/root` directory.
3. Get `aio.sh` file from Internet and move it to the router's `/root` directory.
4. Run the following commands:
```bash
chmod +x aio.sh
./aio.sh
```
1. Sit back and relax. The script will take care of the rest.
2. Once the script is done, reboot the router.
3. Go to golain dashboard and check if the router is connected.
4. delete the `config.json` file from the router.