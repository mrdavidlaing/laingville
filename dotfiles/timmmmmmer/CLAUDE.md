# CLAUDE.md - Timmmmmmer's Dotfiles

This file provides guidance for working with Timmmmmmer's personal dotfile configurations.

## Configuration Overview

Timmmmmmer's setup is focused on a modern Linux desktop environment using Hyprland (Wayland compositor) with custom theming and application shortcuts.

## Key Components

### Hyprland Configuration (`.config/hypr/hyprland.conf`)
- **Window Manager**: Hyprland with custom animations and styling
- **Keyboard Layout**: Irish (ie) keyboard layout
- **Applications**: 
  - Terminal: kgx (Gnome Console)
  - File Manager: Thunar
  - Menu: Rofi
  - Browser: Vivaldi
- **Custom Keybindings**:
  - `Super + W`: Launch browser (Vivaldi)
  - `Super + G`: Launch GIMP
  - `Super + T`: Launch Sober (Roblox emulator)
  - `Super + K`: Launch Minecraft
  - `Super + F`: Fullscreen toggle

### Waybar Configuration (`.config/waybar/config.jsonc`)
- **Position**: Bottom of screen
- **Custom Modules**: Quick-launch buttons for Sober, Minecraft, Terminal, Browser
- **Integration**: Hyprland workspaces, system tray, clock, audio controls
- **Media Player**: Integrated media player controls

### Qt6ct Theming (`.config/qt6ct/qt6ct.conf`)
- **Theme**: Darker color scheme with Fusion style
- **Icons**: Breeze Dark icon theme
- **Fonts**: Noto Sans family

## Configuration Management

When modifying configurations:
1. Edit the dotfiles directly in this directory
2. Run `../../setup-user` from repository root to update symlinks
3. Hyprland will automatically reload if running and configuration changes

## Application-Specific Notes

- **Minecraft**: Custom launcher path at `/home/timmy/minecraft/minecraft-launcher/src/minecraft-launcher/minecraft-launcher`
- **Sober**: Flatpak application for Roblox emulation
- **Media Controls**: Waybar includes custom media player script integration