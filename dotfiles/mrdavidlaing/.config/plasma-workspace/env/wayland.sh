#!/bin/bash
# Enable Wayland for various applications

# Firefox/Zen Browser
export MOZ_ENABLE_WAYLAND=1

# Qt applications
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# GTK applications
export GDK_BACKEND=wayland

# SDL applications
export SDL_VIDEODRIVER=wayland

# Clutter
export CLUTTER_BACKEND=wayland

# Java applications
export _JAVA_AWT_WM_NONREPARENTING=1

# XDG session type
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE

# Enable Wayland for Electron apps
export ELECTRON_OZONE_PLATFORM_HINT=wayland
