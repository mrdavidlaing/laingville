#!/bin/bash
# Clock plugin for Sketchybar
# Format matches Waybar: Day DD Mon HH:MM

sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')"
