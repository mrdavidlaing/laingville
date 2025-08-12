#!/usr/bin/env bash

# Configure /etc/hosts with Laingville server hostnames and IPs
# This script ensures all servers can resolve each other by hostname

set -euo pipefail

echo "Configuring /etc/hosts with Laingville server hostnames..."

# Define the server mappings
LAINGVILLE_HOSTS="
# Laingville servers
192.168.1.77    baljeet
192.168.1.70    phineas
192.168.1.67    ferb
192.168.1.26    monogram
192.168.1.46    momac"

# Backup original hosts file
backup_timestamp=$(date +%Y%m%d-%H%M%S)
sudo cp /etc/hosts "/etc/hosts.backup.${backup_timestamp}"

# Remove any existing Laingville entries
sudo sed -i '/# Laingville servers/,/^$/d' /etc/hosts

# Add Laingville server entries
echo "$LAINGVILLE_HOSTS" | sudo tee -a /etc/hosts > /dev/null

echo "✓ /etc/hosts configured with Laingville server hostnames"
echo "Added entries:"
echo "$LAINGVILLE_HOSTS"
