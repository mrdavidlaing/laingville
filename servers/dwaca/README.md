# dwaca Router Configuration

Configuration management for the Asus DSL-AC68U router running FreshTomato firmware.

## Directory Structure

```
servers/dwaca/
├── configs/                   # Configuration files deployed to router
│   ├── motd                   # Message of the day
│   └── profile                # User .profile for SSH login
├── scripts/                   # Custom scripts
│   ├── apply_motd.bash        # Applies MOTD configuration
│   ├── apply_profile.bash     # Applies user profile configuration
│   ├── setup_init_scripts.bash # Configures FreshTomato Init scripts
│   └── bootstrap.sh           # Fresh Entware installation with DNS setup
├── packages.yaml              # Router packages (freshtomato platform)
└── settings.yaml              # Server connection and deployment settings
```

## Initial Setup (First Time)

### 1. Flash FreshTomato Firmware
1. **Download firmware**: Get FreshTomato from [freshtomato.org](https://freshtomato.org)
   - For DSL-AC68U: Use ARM build (e.g., `freshtomato-K26ARM_USB-2025.3-AIO-64K.trx`)
2. **Flash firmware**: Upload via router web interface (Administration → Upgrade)
3. **Factory reset**: Recommended after flashing

### 2. Basic Router Configuration
Access router web interface and configure:

**Network Settings:**
- **LAN IP**: Set to `192.168.1.2` (Administration → LAN)
- **Gateway**: Ensure router can reach internet via `192.168.1.1`

**SSH Access:**
- **Enable SSH**: Administration → SSH → Enable SSH Daemon
- **SSH Port**: `22` (default)
- **Add SSH Key**: Paste your public SSH key in "Authorized Keys"
- **Disable Rate Limiting**: Uncheck "Limit SSH Access" (prevents connection drops)

**WiFi Networks:**
- **2.4GHz Network**: Set SSID to "The Promised LAN (dwaca)"
- **5GHz Network**: Set SSID to "The Promised LAN (dwaca) 5GHz"
- **Security**: WPA2 Personal
- **Password**: [Please provide the WiFi password]

**JFFS Storage (Required for MOTD persistence):**
- **Enable JFFS**: Administration → JFFS → Check "Enable" checkbox
- **Format JFFS**: Click "Format & Load" button
- **Save Settings**: Click "Save" to apply changes
- **Leave "Execute when mounted" field empty** (we use Init scripts instead)

**USB Storage (Required for Entware):**
- **USB Support**: USB and NAS → USB Support → Enable all USB options
- **Format USB Drive**: Format as ext4 with label "ENTWARE" (recommended)
- **Auto-mount**: Enable USB storage auto-mounting

### 3. Bootstrap Entware Environment
Run the bootstrap script to install full Linux environment:
```bash
ssh root@192.168.1.2
# Files will be uploaded here, then run:
cd /tmp/laingville/servers/dwaca/scripts
sh bootstrap.sh
```

This installs:
- DNS configuration (Cloudflare 1.1.1.1 + Google 8.8.8.8)
- Network gateway setup (192.168.1.1)
- Entware package manager with 2500+ packages
- bash shell and rsync for full development workflow
- Auto-start/stop scripts for persistence

**Reboot after bootstrap** to activate auto-start scripts.

## Development Workflow

### Method 1: Remote Server Setup (Development)
Use the remote setup tool from your development machine:
```bash
./bin/remote-setup-server dwaca                  # Deploy and configure
./bin/remote-setup-server dwaca --dry-run        # Preview changes
./bin/remote-setup-server dwaca --sync-only      # Just sync files
```

### Method 2: Git Pull (Production)
SSH into the router and run setup-server (requires Entware):
```bash
ssh root@192.168.1.2
cd /opt/laingville
git pull
/opt/bin/bash ./bin/setup-server
```

## Configuration Files

### MOTD (Message of the Day)
- **Source**: `configs/motd`
- **Deployed to**: `/jffs/configs/motd`
- **Applied by**: `scripts/apply_motd.bash`
- **Displayed via**: SSH user profile

### User Profile
- **Source**: `configs/profile`
- **Deployed to**: `/tmp/home/root/.profile`
- **Applied by**: `scripts/apply_profile.bash`
- **Purpose**: Sets up aliases, prompt, displays MOTD on SSH login

### Init Script Configuration
- **Applied by**: `scripts/setup_init_scripts.bash`
- **Stored in**: FreshTomato NVRAM (Administration → Scripts → Init)
- **Purpose**: Automatically runs configuration scripts at boot
- **Recreates**: User profile and MOTD on each reboot

## Adding New Configurations

1. Add config file to `configs/` directory
2. Create or update corresponding `scripts/apply_*.bash` script
3. Add script name to `packages.yaml` custom section
4. Commit and push changes
5. Deploy using `./bin/remote-setup-server dwaca`

## Router Setup

### FreshTomato Firmware Characteristics
- **Filesystem**: Root filesystem is read-only; `/tmp` is writable
- **Services**: Managed via `service <name> <action>` command
- **DNS**: Uses dnsmasq with config at `/etc/dnsmasq.conf` and upstream servers in `/etc/resolv.dnsmasq`
- **Default shell**: `/bin/sh` (BusyBox), no bash by default
- **Package manager**: None by default, requires Entware installation

### Entware Package Management
Entware provides a full Linux package ecosystem for routers:

**Installation**: Run the bootstrap script for fresh setup:
```bash
cd /tmp/laingville/servers/dwaca/scripts
sh bootstrap.sh
```

**Manual Entware setup**:
1. USB drive mounted at `/tmp/mnt/dwaca-usb` (ext4 filesystem required)
2. Entware installed to `/tmp/mnt/dwaca-usb/entware`
3. Bind mounted to `/opt` via: `mount --bind /tmp/mnt/dwaca-usb/entware /opt`
4. Auto-start/stop scripts: `.autorun` and `.autostop` on USB root

**Essential packages installed**:
- `bash` - Full bash shell at `/opt/bin/bash`
- `rsync` - File synchronization tool
- DNS upstream servers: Cloudflare (1.1.1.1) and Google (8.8.8.8)

### Current Setup
The router has:
- FreshTomato 2025.3 K26ARM USB AIO-64K firmware
- USB drive with Entware at `/tmp/mnt/dwaca-usb`
- Repository synced to: `/tmp/laingville` (development) or `/opt/laingville` (production)
- SSH access on port 22 with rate limiting disabled

## Notes

### FreshTomato Specifics
- **DNS troubleshooting**: If internet access fails, restart dnsmasq: `service dnsmasq restart`
- **SSH rate limiting**: Disabled to prevent development workflow issues
- **Root filesystem**: Read-only, cannot create symlinks to `/opt`
- **Persistent storage**: USB drive required for packages and data persistence
- **Service management**: Use `service <name> restart` to reload configurations

### Development Workflow
- MOTD displays on interactive SSH login only
- Configuration changes persist across reboots (stored in JFFS)
- User profile is in `/tmp` so recreated on each boot
- Use 1Password SSH agent via Windows SSH for authentication