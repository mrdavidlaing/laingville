#!/opt/bin/bash
# Configure DHCP static lease reservations for FreshTomato router
# Assigns fixed IP addresses to servers based on MAC addresses
# Configuration sourced from servers/README.md

set -euo pipefail

# Source the table parser
source /tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/parse_server_inventory.bash

echo "Configuring DHCP static lease reservations..."

# Configure DHCP pool to avoid conflicts with static reservations
# Use pool range 192.168.1.100-199 (100 addresses)
# Reserved IPs: .2 (router), .26, .67, .70, .77 (servers)
echo "- Setting DHCP pool range to avoid static reservation conflicts"
nvram set dhcp_start=100              # Start DHCP pool at .100
nvram set dhcp_num=100                # Allocate 100 IPs (.100-.199)
nvram set dhcpd_startip=192.168.1.100 # DHCP start IP (for web UI)
nvram set dhcpd_endip=192.168.1.199   # DHCP end IP (for web UI)
nvram set dhcpd_static_only=0         # Allow dynamic DHCP for other devices

# Configure DHCP static lease reservations
# Format: MAC<IP<hostname>MAC<IP<hostname>...
echo "- Building static DHCP lease reservations from servers/README.md"

# Build the static lease string from server inventory
STATIC_LEASES=$(parse_server_table dhcp | tr '\n' '>')
# Remove trailing '>' if present
STATIC_LEASES=${STATIC_LEASES%>}

if [[ -z "$STATIC_LEASES" ]]; then
  echo "  ⚠ Warning: No DHCP reservations found in server inventory"
else
  echo "  ✓ Found $(parse_server_table dhcp | wc -l) server(s) for DHCP reservation"
fi

nvram set dhcpd_static="$STATIC_LEASES"

echo "- Configuring DHCP server settings"
# Note: lan_dhcp is managed via web UI, do not modify here
# Current working setting: lan_dhcp=0 (managed by dnsmasq directly)
nvram set dhcpd_dmdns=1 # Use internal DNS for DHCP clients

# Configure lease time (24 hours = 1440 minutes)
nvram set dhcp_lease=1440

# Commit NVRAM changes
echo "- Committing NVRAM changes"
nvram commit

# Restart DHCP service to apply changes
echo "- Restarting DHCP service"
service dnsmasq restart
sleep 2

# Verify configuration
echo ""
echo "DHCP Static Lease Configuration Summary:"
echo "  DHCP Pool Range: 192.168.1.100 - 192.168.1.199"
echo "  Static Reservations:"
parse_server_table full | while IFS=':' read -r hostname mac ip; do
  printf "    %-8s (%s) → %s\n" "$hostname" "$mac" "$ip"
done
echo "  Lease Time: 24 hours"
echo ""
echo "Note: Servers will receive reserved IPs on next DHCP renewal"
echo "To force immediate renewal on servers, run: dhclient -r && dhclient"
