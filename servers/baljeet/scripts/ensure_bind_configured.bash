#!/usr/bin/env bash

# Configure BIND DNS server for Laingville internal network
# This script sets up BIND to resolve internal hostnames and forward external queries

set -euo pipefail

# Handle both --dry-run and true formats
DRY_RUN="false"
if [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "true" ]]; then
  DRY_RUN="true"
fi

echo "Configuring BIND DNS server for Laingville network..."

# Define the server mappings (same as hosts file)
LAINGVILLE_SERVERS="
192.168.1.77    baljeet
192.168.1.70    phineas
192.168.1.67    ferb
192.168.1.26    monogram
192.168.1.46    momac"

# Get the script directory to find config files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIND_CONFIG_DIR="${SCRIPT_DIR}/bind"

if [[ "${DRY_RUN}" = true ]]; then
  echo "Would configure BIND with the following actions:"
  echo "1. Copy ${BIND_CONFIG_DIR}/named.conf -> /etc/named.conf"
  echo "2. Copy ${BIND_CONFIG_DIR}/laingville.internal.zone -> /var/named/laingville.internal.zone"
  echo "3. Copy ${BIND_CONFIG_DIR}/1.168.192.in-addr.arpa.zone -> /var/named/1.168.192.in-addr.arpa.zone"
  echo "4. Set proper file permissions for BIND"
  echo "5. Configure firewall to allow DNS service (if firewalld is active)"
  echo "6. Enable and start named.service"
  echo "7. Configure zones for these servers:"
  echo "${LAINGVILLE_SERVERS}"
  exit 0
fi

# Verify config files exist
if [[ ! -f "${BIND_CONFIG_DIR}/named.conf" ]]; then
  echo "Error: ${BIND_CONFIG_DIR}/named.conf not found"
  exit 1
fi
if [[ ! -f "${BIND_CONFIG_DIR}/laingville.internal.zone" ]]; then
  echo "Error: ${BIND_CONFIG_DIR}/laingville.internal.zone not found"
  exit 1
fi
if [[ ! -f "${BIND_CONFIG_DIR}/1.168.192.in-addr.arpa.zone" ]]; then
  echo "Error: ${BIND_CONFIG_DIR}/1.168.192.in-addr.arpa.zone not found"
  exit 1
fi

# Create /var/named directory if it doesn't exist
sudo mkdir -p /var/named

# Copy configuration files to system locations (can't use symlinks due to permissions)
echo "Copying /etc/named.conf..."
sudo cp "${BIND_CONFIG_DIR}/named.conf" /etc/named.conf

echo "Copying forward zone file..."
sudo cp "${BIND_CONFIG_DIR}/laingville.internal.zone" /var/named/laingville.internal.zone

echo "Copying reverse zone file..."
sudo cp "${BIND_CONFIG_DIR}/1.168.192.in-addr.arpa.zone" /var/named/1.168.192.in-addr.arpa.zone

# Set proper permissions
echo "Setting file permissions..."
sudo chmod 644 /etc/named.conf
sudo chown root:named /var/named/laingville.internal.zone
sudo chown root:named /var/named/1.168.192.in-addr.arpa.zone
sudo chmod 640 /var/named/laingville.internal.zone
sudo chmod 640 /var/named/1.168.192.in-addr.arpa.zone

# Check configuration syntax
echo "Checking BIND configuration syntax..."
sudo named-checkconf /etc/named.conf
sudo named-checkzone laingville.internal /var/named/laingville.internal.zone
sudo named-checkzone 1.168.192.in-addr.arpa /var/named/1.168.192.in-addr.arpa.zone

# Configure firewall to allow DNS
echo "Configuring firewall to allow DNS..."
if systemctl is-active firewalld > /dev/null 2>&1; then
  sudo firewall-cmd --add-service=dns --permanent
  sudo firewall-cmd --reload
  echo "✓ Firewall configured to allow DNS"
else
  echo "✓ Firewalld not active, skipping firewall configuration"
fi

# Enable and start BIND service
echo "Enabling and starting BIND service..."
sudo systemctl daemon-reload
sudo systemctl enable named.service
sudo systemctl restart named.service

# Verify service is running
if sudo systemctl is-active named.service > /dev/null; then
  echo "✓ BIND DNS server is running"
else
  echo "✗ BIND DNS server failed to start"
  exit 1
fi

# Test DNS resolution
echo "Testing DNS resolution..."
echo "Forward lookup test:"
nslookup baljeet.laingville.internal 127.0.0.1 || echo "Forward lookup test failed"

echo "Reverse lookup test:"
nslookup 192.168.1.77 127.0.0.1 || echo "Reverse lookup test failed"

echo "External DNS test:"
nslookup google.com 127.0.0.1 || echo "External DNS forwarding test failed"

echo "✓ BIND DNS server configured successfully"
echo "DNS server is listening on 192.168.1.77:53"
echo "Configure clients to use 192.168.1.77 as their DNS server"
