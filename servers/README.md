# Servers

This directory contains configuration and management files for the Laingville home network servers.

## Network Topology

```
Home Network: 192.168.1.0/24
Gateway: 192.168.1.1 (Vodafone Fibre Modem/Router)
DNS: 192.168.1.2 (dwaca - FreshTomato dnsmasq server)
```

## Server Inventory

| Server Name | Hostname | IP Discovery | IP Address | MAC Address | Services | Notes |
|-------------|----------|--------------|------------|-------------|----------|-------|
| [dwaca](./dwaca/) | dwaca | Static (Router) | 192.168.1.2 | N/A | DNS, DHCP, WiFi | FreshTomato router, primary DNS/DHCP server |
| [baljeet](./baljeet/) | baljeet | DHCP (Reserved) | 192.168.1.77 | 98:5A:EB:C9:0C:A0 | General purpose | Former DNS server |
| [phineas](./phineas/) | phineas | DHCP (Reserved) | 192.168.1.70 | C8:69:CD:AA:4E:0A | TBD | TBD |
| [ferb](./ferb/) | ferb | DHCP (Reserved) | 192.168.1.67 | 80:E6:50:24:50:78 | TBD | TBD |
| [monogram](./monogram/) | monogram | DHCP (Reserved) | 192.168.1.26 | FC:34:97:BA:A9:06 | TBD | TBD |

## Server Configuration

Each server has its own subdirectory containing:

- `packages.yaml` - Package definitions for automated installation
- `scripts/` - Server-specific automation scripts
- Additional configuration files as needed

### Package Management

Servers use the same package management system as user configurations:
- `arch.pacman` - Official Arch Linux packages
- `arch.aur` - AUR packages (requires yay)
- `arch.custom` - Custom installation scripts
- `windows.winget` - Windows packages (for Windows servers)

### Setup

To configure a server, run:

```bash
./setup-server
```

The script automatically detects the hostname and applies the appropriate configuration.

## Services Overview

### baljeet
- **Role**: General purpose server
- **Key Services**:
  - General computing tasks (DNS services migrated to dwaca router)
- **Custom Scripts**:
  - `ensure_sshd_running` - Ensures SSH daemon is running
- **Firewall**:
  - Uses firewalld (if active)
  - Allows SSH services
  - Automatically configured by setup script

## DNS and DHCP Configuration

The Laingville network uses dwaca (FreshTomato router) as the primary DNS and DHCP server.

### DNS Server (dwaca - 192.168.1.2)
- **Internal domain**: `laingville.internal`
- **Forward DNS**: Resolves hostnames like `ferb.laingville.internal` to IP addresses
- **Reverse DNS**: Resolves IP addresses back to hostnames
- **External DNS forwarding**: Uses Cloudflare (1.1.1.1) and Google (8.8.8.8) as forwarders
- **Implementation**: Native FreshTomato dnsmasq with custom hosts file

### DHCP Configuration
- **DHCP Pool**: 192.168.1.100 - 192.168.1.199 (100 addresses)
- **Static Reservations**: MAC-based assignments for all servers
- **Lease Time**: 24 hours
- **Gateway**: 192.168.1.1 (Vodafone router)
- **DNS Server**: 192.168.1.2 (dwaca router)

### Network Services Migration
DNS and DHCP services were centralized on dwaca router using native FreshTomato features for:
- Simplified management (no additional packages required)
- Better integration between DNS and DHCP services
- Lower resource usage on dedicated hardware
- Centralized network service management

## Shared Configurations

Common server configurations are stored in the `shared/` directory and applied to all servers before hostname-specific configurations.