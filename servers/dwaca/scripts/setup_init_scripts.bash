#!/opt/bin/bash
# Configure FreshTomato Init script to run configuration scripts at boot
# This script runs ON the router via setup-server

set -euo pipefail

echo "Configuring FreshTomato Init script..."

# Set the Init script in NVRAM to run our configuration scripts at boot
nvram set script_init='#!/bin/sh
# Laingville dwaca router configuration - runs at boot

# Wait for USB mount (max 3 minutes)
USB_TIMEOUT=180
USB_ELAPSED=0
while [ ! -d /tmp/mnt/dwaca-usb ] && [ $USB_ELAPSED -lt $USB_TIMEOUT ]; do
    sleep 5
    USB_ELAPSED=$((USB_ELAPSED + 5))
done

# Wait for JFFS to be ready (max 1 minute)
JFFS_TIMEOUT=60
JFFS_ELAPSED=0
while [ ! -w /jffs ] && [ $JFFS_ELAPSED -lt $JFFS_TIMEOUT ]; do
    sleep 2
    JFFS_ELAPSED=$((JFFS_ELAPSED + 2))
done

# Run configuration scripts using Entware bash shebangs
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_time_sync.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_motd.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_profile.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_network_config.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_dhcp_reservations.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_dns_config.bash
/tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/apply_freshtomato_adblock.bash
'

# Commit NVRAM changes to persist them
nvram commit

echo "Init script configured successfully in NVRAM"
echo ""
echo "The following scripts will run at boot:"
echo "  - apply_time_sync.bash (configures NTP time synchronization)"
echo "  - apply_motd.bash (sets up MOTD)"
echo "  - apply_profile.bash (sets up SSH user profile)"
echo "  - apply_network_config.bash (configures gateway, DNS, routing)"
echo "  - apply_dhcp_reservations.bash (configures DHCP static leases)"
echo "  - apply_dns_config.bash (configures internal DNS and dnsmasq)"
echo "  - apply_freshtomato_adblock.bash (configures FreshTomato adblock)"
echo ""
echo "To verify: Check Administration → Scripts → Init in FreshTomato web UI"
