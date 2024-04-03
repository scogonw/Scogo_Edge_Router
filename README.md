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
