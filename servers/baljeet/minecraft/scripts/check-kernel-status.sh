#!/bin/bash
# Check if kernel reboot is needed for ipset support

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Kernel Status Check ===${NC}"

RUNNING_KERNEL=$(uname -r)
INSTALLED_KERNEL=$(pacman -Q linux | cut -d' ' -f2)

echo "Running kernel: $RUNNING_KERNEL"
echo "Installed kernel: $INSTALLED_KERNEL"

# Check if ipset modules are available
if modprobe ip_set 2> /dev/null && modprobe ip_set_hash_net 2> /dev/null; then
  log_info "✅ ipset modules loaded successfully"
  log_info "✅ Minecraft security system ready to deploy"
  echo ""
  echo "Run: sudo ./setup-minecraft-firewall.sh"
else
  log_warn "❌ ipset modules not available"

  # Check if modules exist for current kernel
  if [[ -d "/lib/modules/$RUNNING_KERNEL" ]]; then
    if find "/lib/modules/$RUNNING_KERNEL" -name "*ip_set*" -type f | grep -q .; then
      log_error "Modules exist but failed to load - check dmesg"
    else
      log_warn "Modules missing for running kernel"
    fi
  fi

  # Check if reboot would help
  AVAILABLE_KERNELS=$(ls /lib/modules/ | grep -v build | sort -V | tail -1)
  if [[ "$RUNNING_KERNEL" != "$AVAILABLE_KERNELS" ]]; then
    log_warn "🔄 REBOOT REQUIRED"
    echo ""
    echo "After reboot:"
    echo "  • Kernel will be: $AVAILABLE_KERNELS"
    echo "  • ipset modules will be available"
    echo "  • Run: sudo ./setup-minecraft-firewall.sh"
    echo ""
    echo "To reboot now: sudo reboot"
  else
    log_error "Kernel is current but ipset still unavailable"
    echo "Check if CONFIG_NETFILTER_NETLINK_LOG is enabled"
  fi
fi

echo ""
echo -e "${BLUE}=== Current Security Status ===${NC}"

# Check existing iptables rules
if iptables -L MINECRAFT_FILTER > /dev/null 2>&1; then
  log_info "MINECRAFT_FILTER chain exists"
else
  echo "MINECRAFT_FILTER chain: Not created"
fi

# Check fail2ban
if systemctl is-active --quiet fail2ban; then
  log_info "fail2ban service: Running"
else
  echo "fail2ban service: Not running"
fi

# Check current Minecraft connections
if ss -tuln | grep -q ":25565"; then
  log_info "Minecraft server: Listening on port 25565"
else
  echo "Minecraft server: Not detected on port 25565"
fi
