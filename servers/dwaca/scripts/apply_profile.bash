#!/usr/bin/env bash
# Apply user profile configuration for FreshTomato router
# This script runs ON the router via setup-server

set -euo pipefail

# Configuration
CONFIG_DIR="/opt/laingville/servers/dwaca/configs"
PROFILE_PATH="/tmp/home/root/.profile"

echo "Applying user profile configuration..."

# Ensure home directory exists
mkdir -p "/tmp/home/root"

# Apply user profile (for SSH login)
if [[ -f "$CONFIG_DIR/profile" ]]; then
  echo "- Copying user profile for SSH login"
  cp "$CONFIG_DIR/profile" "$PROFILE_PATH"
  chmod 644 "$PROFILE_PATH"
  echo "User profile applied successfully"
else
  echo "Warning: Profile config file not found: $CONFIG_DIR/profile"
  exit 1
fi
