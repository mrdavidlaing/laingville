# Servers

This directory contains configuration and management files for the Laingville home network servers.

## Network Topology

```
Home Network: 192.168.1.0/24
Gateway: 192.168.1.1 (Vodafone Fibre Modem/Router)
DNS: 192.168.1.77 (baljeet - BIND DNS server)
```

## Server Inventory

| Server Name | Hostname | IP Discovery | IP Address | Services | Notes |
|-------------|----------|--------------|------------|----------|-------|
| [baljeet](./baljeet/) | baljeet | Static | 192.168.1.77 | BIND DNS | Primary DNS server for laingville.internal |
| [phineas](./phineas/) | phineas | Static | 192.168.1.70 | TBD | TBD |
| [ferb](./ferb/) | ferb | Static | 192.168.1.67 | TBD | TBD |
| [monogram](./monogram/) | monogram | Static | 192.168.1.26 | TBD | TBD |
| [momac](./momac/) | momac | Static | 192.168.1.46 | TBD | TBD |

## Server Configuration

Each server has its own subdirectory containing:

- `packages.yml` - Package definitions for automated installation
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
- **Role**: Primary DNS server for the Laingville network
- **Key Services**: 
  - BIND (named) - DNS server for laingville.internal domain
  - Provides forward and reverse DNS resolution for all servers
- **Custom Scripts**: 
  - `ensure_bind_configured.bash` - Configures BIND DNS server with zone files and firewall rules
- **Firewall**: 
  - Uses firewalld (if active) 
  - Allows SSH and DNS services
  - Automatically configured by setup script

## DNS Configuration

The Laingville network uses a BIND DNS server running on baljeet (192.168.1.77) to provide:

- **Internal domain**: `laingville.internal`
- **Forward DNS**: Resolves hostnames like `ferb.laingville.internal` to IP addresses
- **Reverse DNS**: Resolves IP addresses back to hostnames
- **External DNS forwarding**: Uses Cloudflare (1.1.1.1, 1.0.0.1) and Google (8.8.8.8, 8.8.4.4) as forwarders

### DNS Setup

The Vodafone Gigabox router is configured to use 192.168.1.77 as the primary DNS server, so all devices on the network automatically use the internal DNS.

### Firewall Considerations

Servers running firewalld must allow the DNS service for external queries to work. The `ensure_bind_configured.bash` script automatically configures this when setting up BIND.

## Shared Configurations

Common server configurations are stored in the `shared/` directory and applied to all servers before hostname-specific configurations.