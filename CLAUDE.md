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

## Setup and Usage Commands

### Initial Setup
```bash
./setup-user
```

This script will automatically configure dotfiles for the current user by creating symbolic links.

## Development Notes

- The project uses shell scripting for automation
- Configuration files are primarily in dotfile format (hidden files starting with .)
- No build/test/lint commands - this is a configuration management repository
- Changes should be tested by running `./setup-user` and verifying symbolic links are created correctly