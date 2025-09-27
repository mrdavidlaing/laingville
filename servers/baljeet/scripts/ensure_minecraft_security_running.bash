#!/usr/bin/env bash

# Enable and start Minecraft security services
# This script ensures fail2ban is enabled at boot, started, and Minecraft jails are active

set -euo pipefail

echo "Ensuring Minecraft security system is running..."

# Enable fail2ban to start at boot and start it now
sudo systemctl enable --now fail2ban

# Check if fail2ban is running
if systemctl is-active --quiet fail2ban; then
  echo "✓ fail2ban service is running and enabled"

  # Check if Minecraft jails are active
  jail_count=$(sudo fail2ban-client status 2> /dev/null | grep -c "minecraft" || echo "0")
  if [[ $jail_count -gt 0 ]]; then
    echo "✓ Minecraft security jails are active ($jail_count jails)"

    # Show brief status
    echo ""
    echo "Active Minecraft jails:"
    sudo fail2ban-client status | grep "minecraft" | sed 's/^/  /'

    # Check iptables chain
    if sudo iptables -L MINECRAFT_FILTER > /dev/null 2>&1; then
      echo "✓ MINECRAFT_FILTER iptables chain is active"
    else
      echo "⚠ MINECRAFT_FILTER iptables chain missing - may need setup"
    fi

    # Check ipsets
    ireland_count=$(sudo ipset list ireland_ips 2> /dev/null | grep -c "^[0-9]" || echo "0")
    if [[ $ireland_count -gt 0 ]]; then
      echo "✓ Irish IP allowlist active ($ireland_count ranges)"
    else
      echo "⚠ Irish IP allowlist empty - may need update"
    fi

  else
    echo "⚠ fail2ban running but no Minecraft jails found"
    echo "  This may be normal if no attacks have occurred yet"
  fi

else
  echo "✗ Failed to start fail2ban service"
  echo "Checking service status:"
  sudo systemctl status fail2ban --no-pager --lines=5
  exit 1
fi

echo ""
echo "Minecraft security system status: ✓ Active"
