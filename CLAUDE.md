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
Each user and server can define packages to install in their respective `packages.yaml` files:
- `arch.pacman` - Official Arch Linux packages
- `arch.aur` - AUR packages (requires yay)
- `windows.winget` - Windows packages via winget
- `windows.scoop` - Windows packages via Scoop package manager
- `windows.psmodule` - PowerShell modules from PowerShell Gallery

For Scoop packages, you can specify packages from specific buckets using the format `bucket/package` (e.g., `versions/wezterm-nightly`). The system will automatically install Scoop if it's not already present and add required buckets before installing packages.

Server package configurations follow the same format but are located in `servers/[hostname]/packages.yaml`.

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

## PowerShell Testing

**IMPORTANT: Always run PowerShell tests after making changes to .ps1 files**

### Framework
The repository uses **Pester v5** for PowerShell testing, which provides BDD-style syntax similar to ShellSpec:
- `Describe` blocks for grouping tests
- `Context` blocks for scenarios  
- `It` blocks for individual test cases
- `Should` assertions for expectations

### Run PowerShell Tests

#### From Windows PowerShell/PowerShell Core
```powershell
# Run all PowerShell tests
Invoke-Pester

# Run with configuration file
$config = Import-PowerShellDataFile '.\.pester.ps1'
Invoke-Pester -Configuration $config

# Run specific test file
Invoke-Pester -Path .\spec\powershell\shared.functions.Tests.ps1
```

#### From WSL (Windows Subsystem for Linux)
When working in WSL, you can run PowerShell tests using these commands:

```bash
# Run all PowerShell tests
pwsh.exe -NoProfile -Command "Invoke-Pester -Path ./spec/powershell -Output Detailed"

# Run specific test file
pwsh.exe -NoProfile -File spec/powershell/shared.functions.Tests.ps1

# Run individual test files to isolate issues
pwsh.exe -NoProfile -File spec/powershell/logging.functions.Tests.ps1
pwsh.exe -NoProfile -File spec/powershell/security.functions.Tests.ps1
pwsh.exe -NoProfile -File spec/powershell/yaml.functions.Tests.ps1
pwsh.exe -NoProfile -File spec/powershell/setup-user.functions.Tests.ps1
```

**Note**: The `-NoProfile` flag prevents PowerShell profile loading issues that can occur in WSL environments.

### PowerShell Test Files
- `spec/powershell/shared.functions.Tests.ps1` - Tests for shared PowerShell functions
- `spec/powershell/yaml.functions.Tests.ps1` - Tests for YAML parsing functions
- `spec/powershell/security.functions.Tests.ps1` - Tests for security validation functions
- `spec/powershell/logging.functions.Tests.ps1` - Tests for logging functions
- `spec/powershell/setup-user.functions.Tests.ps1` - Tests for user setup functions

### PowerShell Test Coverage
Tests cover:
- Package installation with winget (including mocked external calls)
- YAML parsing for packages and symlinks
- Security validation (safe filenames and paths)
- Logging functions with correct formatting and colors
- User mapping and platform-specific path handling
- Symlink creation with proper error handling

### When to Run PowerShell Tests
- After modifying any `.ps1` files in `lib/` or `bin/`
- After changing PowerShell function implementations
- Before committing PowerShell script changes
- When adding new PowerShell functionality

### Continuous Integration
PowerShell tests automatically run on Windows runners in GitHub Actions:
- Installs Pester if not available
- Executes all tests in `spec/powershell/`
- Generates test results and code coverage reports
- Uploads artifacts for analysis

Both bash (ShellSpec) and PowerShell (Pester) test suites must pass for CI to succeed.

## Supported Platforms

The repository supports multiple platforms with automatic detection:

### Server Platforms
- **arch** - Arch Linux systems (pacman + yay)
- **wsl** - Windows Subsystem for Linux
- **macos** - macOS systems (Homebrew)
- **nix** - NixOS and systems with Nix package manager
- **freshtomato** - ASUS routers with FreshTomato firmware (opkg/Entware)
- **linux** - Generic Linux (fallback)

### Desktop Platforms
- **windows** - Windows systems (winget + scoop + PowerShell modules)

Platform detection is automatic and used for:
- Package manager selection
- Service management (systemctl vs init.d)
- Path conventions
- Custom scripts

## Development Workflow

### remote-setup-server Tool

For rapid development on remote servers, use the universal `remote-setup-server` tool:

```bash
# Sync and deploy changes to any remote server
./bin/remote-setup-server <hostname> [--dry-run] [--sync-only]

# Examples:
./bin/remote-setup-server dwaca              # Deploy to router
./bin/remote-setup-server baljeet            # Deploy to server
./bin/remote-setup-server dwaca --dry-run    # Preview changes
./bin/remote-setup-server dwaca --sync-only  # Just sync files
```

#### Configuration

Each server has a `settings.yaml` config file (committed to git):

**`servers/dwaca/settings.yaml`**:
```yaml
connection:
  host: 192.168.1.2
  user: root
  port: 22

deployment:
  remote_path: /opt/laingville
```

**`servers/baljeet/settings.yaml`** (example):
```yaml
connection:
  host: baljeet.local
  user: david
  port: 22

deployment:
  remote_path: /home/david/laingville
```

The tool will:
1. Sync the server's directory to the remote host
2. Sync `servers/shared/` if it exists
3. Run `setup-server` on the remote host
4. Display the output locally

### Development vs Production Deployment

#### Development (Fast Iteration)
```bash
# Edit files locally in Claude Code
vim servers/dwaca/configs/motd

# Test changes immediately
./bin/remote-setup-server dwaca

# Iterate until working
# No git commits needed for testing
```

#### Production (Clean Deployment)
```bash
# Commit and push when ready
git add servers/dwaca/
git commit -m "Update dwaca configuration"
git push

# Deploy on target server
ssh admin@192.168.2.1
cd /opt/laingville
git pull
./bin/setup-server
```

This approach provides fast development iteration while keeping git history clean.