#!/opt/bin/bash
# Apply DNS security configuration for FreshTomato router
# Note: WAN DNS servers handled by apply_network_config.bash
# Note: Ad blocking handled by apply_freshtomato_adblock.bash

set -euo pipefail

echo "Applying DNS security configuration..."

# Enable DNS rebind protection
nvram set dns_norebind=1

# Commit NVRAM changes
nvram commit

echo "DNS security configuration applied successfully"
