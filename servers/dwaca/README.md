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
│   ├── apply_network_config.bash # Configures network settings
│   ├── apply_dhcp_reservations.bash # Configures DHCP static leases
│   ├── apply_dns_config.bash  # Configures internal DNS and dnsmasq
│   ├── apply_freshtomato_adblock.bash # Configures adblock settings
│   ├── parse_server_inventory.bash # Parses server data from README
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
- **Web UI**: Basic -> Network
- **WAN0 Settings**: Type: Disabled
- **LAN**: Bridge: br0 | STP: (unchecked) | IP Address: `192.168.1.2` | Netmask: `255.255.255.0` | IP Range: 192.168.1.100 - 200 | Lease Time: 1440
- **Automatic IP**: (unchecked)
- **Default Gateway**: `192.168.1.1`
- **Statis DNS**: `1.1.1.1`, `8.8.8.8`

**WiFi Networks:**
- **2.4GHz Network**: Set SSID to "The Promised LAN (DWACA)"
- **5GHz Network**: Set SSID to "The Promised LAN (DWACA) 5GHz"
- **Security**: WPA2 Personal
- **Password**: Get from 1Password > Laing Family > Family (all) > The Promised LAN (DWACA)

**4 LAN Ethernet ports**
- **Web UI**: Advanced -> VLAN
- **VLAN1: LAN0 (br0)**: DSL: unchecked, All others: checked
- **VLAN2: WAN0 bridge**: DSL: checked, All others: unchecked

**Admin password**
- **Web UI**: Administration -> Username / Password -> Password
- **Password**: Get from 1Password > Laing Family > Family (all) > dwaca - DSL-AC68U 192.168.1.2

**SSH Access:**
- **Enable SSH**: Administration → SSH → Enable SSH Daemon
- **SSH Port**: `22` (default)
- **Add SSH Key**: Paste your public SSH key in "Authorized Keys"
- **Disable Rate Limiting**: Uncheck "Limit SSH Access" (prevents connection drops)

**JFFS Storage (Required for MOTD persistence):**
- **Enable JFFS**: Administration → JFFS → Check "Enable" checkbox
- **Format JFFS**: Click "Format & Load" button
- **Save Settings**: Click "Save" to apply changes
- **Leave "Execute when mounted" field empty** (we use Init scripts instead)

**USB Storage (Required for Entware):**
- **USB Support**: USB and NAS → USB Support → Enable USB options: Core, 2.0, Storage, Filesystem: Ext2 / 3 / 4
- **Format USB Drive**: Must be formatted as ext4 filesystem (label optional but "ENTWARE" recommended)
- **Auto-mount**: Enable USB storage auto-mounting
- **Mount Point**: USB SanDisk 3.2Gen should mount at `/tmp/mnt/dwaca-usb`

### 3. Sync Files and Bootstrap Entware
First sync the configuration files to the router:
```bash
./bin/remote-setup-server dwaca --sync-only
```

Then SSH to the router and run the bootstrap script:
```bash
ssh root@192.168.1.2
sh /tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/bootstrap.sh
```

This installs:
- DNS configuration (Cloudflare 1.1.1.1 + Google 8.8.8.8)
- Network gateway setup (192.168.1.1)
- Entware package manager with 2500+ packages
- bash shell and rsync for full development workflow
- Auto-start/stop scripts for persistence

**Reboot after bootstrap** to activate auto-start scripts.

## Configuration Updates

Use the remote setup tool to deploy configuration changes:
```bash
./bin/remote-setup-server dwaca                  # Deploy and configure
./bin/remote-setup-server dwaca --dry-run        # Preview changes
./bin/remote-setup-server dwaca --sync-only      # Just sync files
```

## DNS and DHCP Configuration

The dwaca router serves as the primary DNS and DHCP server for the Laingville network.

### Internal DNS Server
- **Domain**: `laingville.internal`
- **DNS Server**: `192.168.1.2` (dwaca router)
- **Forward DNS**: Resolves hostnames like `baljeet.laingville.internal` to IP addresses
- **Reverse DNS**: Resolves IP addresses back to hostnames
- **External DNS**: Forwards to Cloudflare (1.1.1.1) and Google (8.8.8.8)

### DHCP Static Lease Reservations
The router assigns fixed IP addresses to servers based on MAC addresses.

**Configuration Source**: Network configuration is automatically sourced from the server inventory table in `servers/README.md`. This ensures a single source of truth for all network configuration.

To modify server IP assignments or MAC addresses, edit the table in `servers/README.md` and run `./bin/remote-setup-server dwaca` to deploy the changes.

### DHCP Pool Configuration
- **Pool Range**: 192.168.1.100 - 192.168.1.199 (100 addresses)
- **Reserved IPs**: .2 (router), .26, .67, .70, .77 (servers)
- **Lease Time**: 24 hours
- **Gateway**: 192.168.1.1 (Vodafone router)
- **DNS Server**: 192.168.1.2 (dwaca router)

### DNS Management Commands
```bash
# Test internal DNS resolution
nslookup baljeet.laingville.internal 192.168.1.2

# Test reverse DNS resolution
nslookup 192.168.1.77 192.168.1.2

# View current DHCP leases
cat /var/lib/dhcp/dhcpd.leases

# Restart DNS/DHCP service
service dnsmasq restart
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

### Local DNS Hosts
- **Source**: Generated from `servers/README.md`
- **Deployed to**: `/jffs/configs/hosts.local`
- **Applied by**: `scripts/apply_dns_config.bash`
- **Purpose**: Internal DNS entries for laingville.internal domain
- **Note**: File is automatically generated - do not edit manually

### Server Inventory Parser
- **Script**: `scripts/parse_server_inventory.bash`
- **Purpose**: Extracts network configuration from `servers/README.md`
- **Formats**: Supports dhcp, hosts, and full output formats
- **Testing**: Run with `--test` flag for validation
- **Usage**: Sources table data for DHCP and DNS configuration

### Init Script Configuration
- **Applied by**: `scripts/setup_init_scripts.bash`
- **Stored in**: FreshTomato NVRAM (Administration → Scripts → Init)
- **Purpose**: Automatically runs configuration scripts at boot
- **Includes**: Network, DHCP, DNS, adblock, and UI configuration

## Adding New Configurations

1. Add config file to `configs/` directory
2. Create or update corresponding `scripts/apply_*.bash` script
3. Add script name to `packages.yaml` custom section
4. Commit and push changes
5. Deploy using `./bin/remote-setup-server dwaca`

## Managing Network Configuration

### Adding/Modifying Servers
1. Edit the server inventory table in `servers/README.md`
2. Add new entries with format: `| [hostname](./hostname/) | hostname | DHCP (Reserved) | IP | MAC | Services | Notes |`
3. Deploy changes: `./bin/remote-setup-server dwaca`

### Single Source of Truth
All network configuration (IP addresses, MAC addresses, hostnames) is sourced from `servers/README.md`. The router automatically:
- Generates DHCP static lease reservations from the server table
- Creates DNS host entries for internal resolution
- Updates configuration dynamically when the table changes

**Do not manually edit**:
- `/jffs/configs/hosts.local` (generated from table)
- NVRAM DHCP settings (configured from table)

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
cd /opt/laingville/servers/dwaca/scripts
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
- Repository synced to: `/opt/laingville`
- SSH access on port 22 with rate limiting disabled

## Notes

### FreshTomato Specifics
- **DNS troubleshooting**: If internet access fails, restart dnsmasq: `service dnsmasq restart`
- **SSH rate limiting**: Disabled to prevent development workflow issues
- **Root filesystem**: Read-only, cannot create symlinks to `/opt`
- **Persistent storage**: USB drive required for packages and data persistence
- **Service management**: Use `service <name> restart` to reload configurations

### Deployment Notes
- MOTD displays on interactive SSH login only
- Configuration changes persist across reboots (stored in JFFS)
- User profile is in `/tmp` so recreated on each boot
- Use 1Password SSH agent via Windows SSH for authentication
