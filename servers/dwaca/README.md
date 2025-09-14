# dwaca Router Configuration

Configuration management for the Asus DSL-AC68U router running Merlin firmware.

## Directory Structure

```
servers/dwaca/
├── configs/          # Configuration files deployed to router
│   ├── test-motd     # Message of the day
│   ├── profile.add   # JFFS profile additions
│   └── user-profile  # User .profile for SSH login
├── scripts/          # Management scripts
│   ├── apply-configs.sh    # Runs on router to apply configs
│   └── push-to-router.sh   # Push configs from dev machine
└── packages.yaml     # Entware packages to install
```

## Deployment Methods

### Method 1: Git Pull (Production)
SSH into the router and pull latest changes:
```bash
ssh -A admin@192.168.2.1
cd /opt/laingville
git pull
./servers/dwaca/scripts/apply-configs.sh
```

Or use the convenient alias (after first setup):
```bash
ssh admin@192.168.2.1
dwaca-pull  # Pulls and applies in one command
```

### Method 2: Direct Push (Development)
Push changes directly from your dev machine:
```bash
./servers/dwaca/scripts/push-to-router.sh
# or with dry-run:
./servers/dwaca/scripts/push-to-router.sh --dry-run
```

## Configuration Files

### MOTD (Message of the Day)
- **Source**: `configs/test-motd`
- **Deployed to**: `/jffs/configs/motd`
- **Displayed via**: `/tmp/home/root/.profile`

### User Profile
- **Source**: `configs/user-profile`
- **Deployed to**: `/tmp/home/root/.profile`
- **Purpose**: Sets up aliases, displays MOTD on SSH login

### Profile Additions
- **Source**: `configs/profile.add`
- **Deployed to**: `/jffs/configs/profile.add`
- **Purpose**: Sourced by system profile when JFFS scripts enabled

## Adding New Configurations

1. Add config file to `configs/` directory
2. Update `scripts/apply-configs.sh` to handle the new file
3. Commit and push changes
4. Deploy using either method above

## Router Setup

The router has:
- Git installed via Entware: `opkg install git`
- Repository cloned at: `/tmp/mnt/dwaca-usb/repos/laingville`
- Symlink at: `/opt/laingville`
- JFFS scripts enabled: `nvram set jffs2_scripts=1`

## Notes

- MOTD displays on interactive SSH login only
- Configuration changes persist across reboots (stored in JFFS)
- User profile is in `/tmp` so recreated on each boot
- Use SSH agent forwarding (`ssh -A`) for git operations