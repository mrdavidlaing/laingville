#!/usr/bin/env bash

# Enable and start Docker daemon, and configure user permissions
# This script ensures Docker is enabled at boot, started immediately,
# and current user is added to docker group

set -euo pipefail

CURRENT_USER=$(whoami)

echo "Enabling and starting Docker daemon..."

# Enable Docker to start at boot and start it now
sudo systemctl enable --now docker

# Check if it's running
if systemctl is-active --quiet docker; then
  echo "✓ Docker daemon is running and enabled"
  systemctl status docker --no-pager --lines=3
else
  echo "✗ Failed to start Docker daemon"
  exit 1
fi

echo ""
echo "Configuring Docker group permissions for user: $CURRENT_USER"

# Check if user is already in docker group
if groups "$CURRENT_USER" | grep -q '\bdocker\b'; then
  echo "✓ User '$CURRENT_USER' is already in the docker group"
else
  echo "Adding user '$CURRENT_USER' to docker group..."
  sudo usermod -aG docker "$CURRENT_USER"
  echo "✓ User added to docker group"
  echo ""
  echo "IMPORTANT: You must log out and log back in for group membership to take effect"
  echo "Alternatively, run: newgrp docker"
fi
