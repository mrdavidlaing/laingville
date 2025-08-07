# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Laingville is a family home network management repository for organizing dotfiles and server configurations. The repository contains personal configuration files for family members and Linux server configurations.

## Project Structure

### Dotfiles Management
- `dotfiles/timmmmmmer/` - Timmmmmmer's personal dotfiles
- `dotfiles/mrdavidlaing/` - mrdavidlaing's personal dotfiles  
- `dotfiles/shared/` - Common configurations used by both family members

### Server Management  
- `servers/baljeet/` - Configuration for baljeet server (k3s and server tools)
- `servers/shared/` - Common server configurations used by all servers
- `servers/[hostname]/` - Additional server configurations by hostname

### Key Components

The repository centers around two main bash scripts:

#### User Configuration (`setup-user`)
- Automatically detects the current user
- Maps users to their appropriate dotfiles folders (timmy → timmmmmmer, david → mrdavidlaing, others → shared)
- Creates symbolic links from home directory to dotfiles
- Handles directory structure recursively
- Automatically reloads Hyprland configuration if present
- Installs packages defined in each user's `packages.yml` file
- Supports `--dry-run` flag for previewing changes before execution

#### Server Configuration (`setup-server`)  
- Automatically detects the current hostname
- Maps hostnames to their appropriate server folders (baljeet → servers/baljeet)
- Processes shared server configurations first, then hostname-specific configs
- Installs packages defined in each server's `packages.yml` file  
- Supports `--dry-run` flag for previewing changes before execution
- Uses same package management system as user setup (pacman, aur, winget)

## Setup and Usage Commands

### User Setup
```bash
./setup-user
```

This script will automatically configure dotfiles for the current user by creating symbolic links and installing packages.

### Server Setup
```bash
./setup-server
```

This script will automatically configure the current server based on hostname and install server-specific packages.

### Preview Changes (Recommended)
```bash
./setup-user --dry-run
./setup-server --dry-run
```

Use dry-run mode to preview what changes will be made before executing them.

### Package Management
Each user and server can define packages to install in their respective `packages.yml` files:
- `arch.pacman` - Official Arch Linux packages
- `arch.aur` - AUR packages (requires yay)
- `windows.winget` - Windows packages via winget

Server package configurations follow the same format but are located in `servers/[hostname]/packages.yml`.

## Development Notes

- The project uses shell scripting for automation
- Configuration files are primarily in dotfile format (hidden files starting with .)
- Functions are separated into multiple files for maintainability:
  - `shared.functions.bash` - Common functions used by both user and server setup
  - `setup-user.functions.bash` - User-specific functions  
  - `setup-server.functions.bash` - Server-specific functions

## Testing

**IMPORTANT: Always run tests after making changes to scripts like setup-user or setup-server**

### Run All Tests
```bash
shellspec
```

### Run Specific Test Files
```bash
shellspec spec/setup_user_spec.sh
shellspec spec/setup_server_spec.sh
shellspec spec/security_spec.sh
```

### Test Coverage
Tests cover essential functionality:
- `--dry-run` mode works correctly for both user and server setup
- Error handling for invalid arguments
- YAML parsing extracts packages from real configs  
- Missing `packages.yml` handled gracefully
- Hostname detection and server directory mapping
- Package extraction from server configurations
- Security validation and sanitization functions
- Cross-platform polyfill functions
- macOS-specific functionality

### When to Run Tests
- After modifying `setup-user` or `setup-server` scripts
- After changing any `.functions.bash` files
- After updating package configurations
- Before committing any script changes

Tests use shellspec framework and provide comprehensive coverage of all functionality.

### Continuous Integration
Tests automatically run on:
- All pull requests to main branch  
- All pushes to main branch

The GitHub Actions workflow ensures code quality and prevents regressions from being merged.