# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Laingville is a family home network management repository for organizing dotfiles and server configurations. The repository contains personal configuration files for family members and Linux server configurations.

## Project Structure

### Dotfiles Management
- `dotfiles/timmmmmmer/` - Timmmmmmer's personal dotfiles
- `dotfiles/mrdavidlaing/` - mrdavidlaing's personal dotfiles  
- `dotfiles/shared/` - Common configurations used by both family members
- `servers/` - Linux server configurations (planned structure)

### Key Components

The repository centers around a bash script (`setup-user`) that:
- Automatically detects the current user
- Maps users to their appropriate dotfiles folders (timmy → timmmmmmer, david → mrdavidlaing, others → shared)
- Creates symbolic links from home directory to dotfiles
- Handles directory structure recursively
- Automatically reloads Hyprland configuration if present
- Installs packages defined in each user's `packages.yml` file
- Supports `--dry-run` flag for previewing changes before execution

## Setup and Usage Commands

### Initial Setup
```bash
./setup-user
```

This script will automatically configure dotfiles for the current user by creating symbolic links and installing packages.

### Preview Changes (Recommended)
```bash
./setup-user --dry-run
```

Use dry-run mode to preview what changes will be made before executing them.

### Package Management
Each user can define packages to install in their `packages.yml` file:
- `arch.pacman` - Official Arch Linux packages
- `arch.aur` - AUR packages (requires yay)
- `windows.winget` - Windows packages via winget

## Development Notes

- The project uses shell scripting for automation
- Configuration files are primarily in dotfile format (hidden files starting with .)
- Functions are separated into `setup-user.functions.bash` for maintainability

## Testing

**IMPORTANT: Always run tests after making changes to scripts like setup-user**

### Run All Tests
```bash
./tests/run_tests.sh
```

### Run Tests Manually
```bash
bats tests/test_setup_user.bats
```

### Test Coverage
Tests cover essential functionality:
- `--dry-run` mode works correctly
- Error handling for invalid arguments
- YAML parsing extracts packages from real configs  
- Missing `packages.yml` handled gracefully

### When to Run Tests
- After modifying `setup-user` script
- After changing `setup-user.functions.bash`
- After updating package configurations
- Before committing any script changes

Tests use real dotfiles as fixtures and provide clear error messages when failures occur.

### Continuous Integration
Tests automatically run on:
- All pull requests to main branch  
- All pushes to main branch

The GitHub Actions workflow ensures code quality and prevents regressions from being merged.