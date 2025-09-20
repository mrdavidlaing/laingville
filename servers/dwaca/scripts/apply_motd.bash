#!/usr/bin/env bash
# Apply MOTD configuration for FreshTomato router
# This script runs ON the router via setup-server

set -euo pipefail

# Configuration
CONFIG_DIR="/opt/laingville/servers/dwaca/configs"
JFFS_DIR="/jffs/configs"

echo "Applying MOTD configuration..."

# Ensure directories exist
mkdir -p "$JFFS_DIR"

# Apply MOTD
if [[ -f "$CONFIG_DIR/motd" ]]; then
  echo "- Copying MOTD with current timestamp"
  sed "s/PLACEHOLDER_DATE/$(date '+%Y-%m-%d %H:%M:%S')/" "$CONFIG_DIR/motd" > "$JFFS_DIR/motd"
  echo "MOTD applied successfully"
else
  echo "Warning: MOTD config file not found: $CONFIG_DIR/motd"
  exit 1
fi
