#!/opt/bin/bash
# Configure FreshTomato's built-in adblock system via NVRAM
# This script runs ON the router via setup-server

set -euo pipefail

echo "Configuring FreshTomato adblock system..."

# Storage configuration
CUSTOM_PATH="/tmp/mnt/dwaca-usb"

# Calculate memory-based limit (similar to FreshTomato's auto-calculation)
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
BLOCKFILE_LIMIT=$((TOTAL_RAM_KB * 100)) # Conservative limit

echo "- Setting up adblock configuration"

# Core adblock settings
nvram set adblock_enable=1
nvram set adblock_logs=3
nvram set adblock_path="$CUSTOM_PATH"
nvram set adblock_limit="$BLOCKFILE_LIMIT"

# Configure blocklists (format: enabled<URL<description>enabled<URL<description>)
# Note: URLs must point to hosts format files - FreshTomato converts to dnsmasq internally
nvram set adblock_blacklist="1<https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.txt<Hagezi Pro>1<https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/doh.txt<Hagezi DoH Bypass>"

# Clear custom blacklist and whitelist (start fresh)
nvram set adblock_blacklist_custom=""
nvram set adblock_whitelist=""

echo "- Enabling DNS enforcement settings"

# DNS enforcement for client compliance (from FreshTomato wiki recommendations)
nvram set dhcpd_dmdns=1 # Use internal DNS
nvram set dns_intcpt=1  # Intercept DNS port
nvram set dhcpd_doh=1   # Prevent client auto DoH

# Commit all NVRAM changes
echo "- Committing NVRAM configuration"
nvram commit

echo "- Starting FreshTomato adblock processing"

# Stop any existing adblock process
adblock stop > /dev/null 2>&1 || true

# Start FreshTomato's adblock system to process the new configuration
adblock start

echo "✅ FreshTomato adblock configured successfully!"
echo ""
echo "Configuration summary:"
echo "  - Adblock: Enabled with error logging"
echo "  - Storage: $CUSTOM_PATH"
echo "  - Memory limit: $BLOCKFILE_LIMIT bytes"
echo "  - Blocklists:"
echo "    • Hagezi Pro (~391k ad/tracking domains)"
echo "    • Hagezi DoH Bypass (~1.6k DoH servers)"
echo "  - DNS enforcement: Enabled (intercept, internal DNS, DoH prevention)"
echo ""
echo "Management commands:"
echo "  - Status: adblock status"
echo "  - Test: adblock test doubleclick.net"
echo "  - Update: adblock update"
echo "  - Web UI: Advanced → Adblock"
