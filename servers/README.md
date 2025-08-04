# Servers

This directory contains configuration and management files for the Laingville home network servers.

## Network Topology

```
Home Network: 192.168.1.0/24
Gateway: 192.168.1.1 (Vodafone Fibre Modem/Router)
DNS: Auto-configured via DHCP
```

## Server Inventory

| Server Name | Hostname | IP Discovery | IP Address | Services | Notes |
|-------------|----------|--------------|------------|----------|-------|
| [baljeet](./baljeet/) | baljeet | Static | 192.168.1.77 | k3s, k9s | Kubernetes cluster node |
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
- **Role**: Kubernetes cluster node
- **Key Services**: k3s (Kubernetes), k9s (cluster management)
- **Custom Scripts**: `ensure_k3s_running.bash` - Ensures k3s service is running

## Shared Configurations

Common server configurations are stored in the `shared/` directory and applied to all servers before hostname-specific configurations.