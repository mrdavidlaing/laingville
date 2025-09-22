#!/opt/bin/bash
# Apply DNS configuration for FreshTomato router
# Configures internal DNS for laingville.internal domain
# Note: WAN DNS servers handled by apply_network_config.bash
# Note: Ad blocking handled by apply_freshtomato_adblock.bash

set -euo pipefail

echo "Applying DNS configuration..."

# Configure local domain settings
echo "- Setting up laingville.internal domain"
nvram set lan_domain="laingville.internal"
nvram set dns_fwd_local=1 # Forward local domain queries

# DNS rebind protection - disable for local domains to work properly
echo "- Configuring DNS security features"
nvram set dns_norebind=0 # Disable rebind protection to allow local domain resolution

# Configure dnsmasq for internal DNS
echo "- Configuring dnsmasq for internal DNS resolution"

# Custom dnsmasq configuration for local hosts and domain
# Configure dnsmasq custom settings using actual newlines
DNSMASQ_CUSTOM=$(printf "expand-hosts\ndomain=laingville.internal\nlocal=/laingville.internal/\naddn-hosts=/jffs/configs/hosts.local\nlocal=/1.168.192.in-addr.arpa/\nserver=1.1.1.1\nserver=8.8.8.8")
nvram set dnsmasq_custom="$DNSMASQ_CUSTOM"

# Debug: Show what we're setting (line count and first few lines)
echo "  ℹ Debug: dnsmasq_custom configuration ($(echo "$DNSMASQ_CUSTOM" | wc -l) lines):"
echo "$DNSMASQ_CUSTOM" | head -4 | sed 's/^/    /'

# Ensure dnsmasq uses the hosts file for resolution
nvram set dnsmasq_no_hosts=0 # Enable /etc/hosts parsing

# Commit NVRAM changes
echo "- Committing NVRAM changes"
nvram commit

# Create the hosts file directory if it doesn't exist
mkdir -p /jffs/configs

# Generate the local hosts file from server inventory
echo "- Generating local hosts file from servers/README.md"
source /tmp/mnt/dwaca-usb/laingville/servers/dwaca/scripts/parse_server_inventory.bash

{
  echo "# Laingville Internal DNS Entries"
  echo "# Generated from servers/README.md on $(date)"
  echo "# DO NOT EDIT - Edit servers/README.md instead"
  echo ""
  echo "# Router"
  echo "192.168.1.2  dwaca.laingville.internal dwaca"
  echo ""
  echo "# Servers (DHCP Reserved)"
  parse_server_table hosts
} > /jffs/configs/hosts.local
echo "  ✓ hosts.local generated from server inventory"

# Restart dnsmasq to apply changes
echo "- Restarting dnsmasq service"
service dnsmasq restart
echo "- Waiting for DNS service to stabilize..."
sleep 8

# Test DNS configuration
echo ""
echo "Testing DNS configuration:"

# Test local forward resolution (use router's IP as DNS server)
# Wait a bit more and try multiple times
for i in 1 2 3; do
  if nslookup dwaca.laingville.internal 192.168.1.2 > /dev/null 2>&1; then
    echo "  ✓ Local forward DNS resolution working"
    break
  elif [ $i -eq 3 ]; then
    echo "  ⚠ Warning: Local forward DNS resolution test failed after 3 attempts"
    # Try alternative test
    if getent hosts dwaca.laingville.internal > /dev/null 2>&1; then
      echo "  ✓ Local DNS working via getent"
    else
      echo "  ℹ Debug: hosts file content:"
      head -5 /jffs/configs/hosts.local 2> /dev/null | sed 's/^/    /'
      echo "  ℹ Debug: dnsmasq status:"
      ps | grep dnsmasq | grep -v grep | sed 's/^/    /'
    fi
  else
    sleep 2
  fi
done

# Test reverse resolution
if nslookup 192.168.1.2 192.168.1.2 > /dev/null 2>&1; then
  echo "  ✓ Reverse DNS resolution working"
else
  echo "  ⚠ Warning: Reverse DNS resolution test failed"
fi

# Test external DNS forwarding (use router as DNS server)
if nslookup google.com 192.168.1.2 > /dev/null 2>&1; then
  echo "  ✓ External DNS forwarding working"
else
  echo "  ⚠ Warning: External DNS forwarding failed"
  # Try using upstream DNS directly as fallback test
  if nslookup google.com 1.1.1.1 > /dev/null 2>&1; then
    echo "  ✓ Internet connectivity confirmed (upstream DNS works)"
    echo "  ℹ Debug: Issue is with dnsmasq forwarding, not connectivity"
  fi
fi

echo ""
echo "DNS Configuration Summary:"
echo "  Local Domain: laingville.internal"
echo "  Internal DNS: Enabled (hosts file + dnsmasq)"
echo "  DNS Rebind Protection: Disabled (for local domain access)"
echo "  Hosts File: /jffs/configs/hosts.local"
echo ""
echo "Configured hosts:"
cat /jffs/configs/hosts.local | grep -v '^#' | grep -v '^$' | while read -r line; do
  echo "  $line"
done
