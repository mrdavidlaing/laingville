#!/usr/bin/env bash

# Enable and start SSH daemon
# This script ensures sshd is enabled at boot and started immediately

set -euo pipefail

echo "Enabling and starting SSH daemon..."

# Enable sshd to start at boot and start it now
sudo systemctl enable --now sshd

# Check if it's running
if systemctl is-active --quiet sshd; then
  echo "✓ SSH daemon is running and enabled"
  systemctl status sshd --no-pager --lines=3
else
  echo "✗ Failed to start SSH daemon"
  exit 1
fi
