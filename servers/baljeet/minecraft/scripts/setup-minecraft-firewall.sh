#!/bin/bash
# Minecraft Server Security Setup Script
# Sets up intelligent firewall protection for Minecraft server

set -euo pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINECRAFT_DIR="$(dirname "$SCRIPT_DIR")"
MINECRAFT_PORT="25565"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Create necessary ipsets
setup_ipsets() {
  log_step "Setting up IP sets for efficient filtering"

  # Create ipset for Irish IP ranges
  if ! ipset list ireland_ips > /dev/null 2>&1; then
    ipset create ireland_ips hash:net comment
    log_info "Created ireland_ips ipset"
  fi

  # Create ipset for temporarily blocked scanners
  if ! ipset list temp_scanners > /dev/null 2>&1; then
    ipset create temp_scanners hash:ip timeout 3600 comment
    log_info "Created temp_scanners ipset with 1-hour timeout"
  fi
}

# Setup fail2ban configuration
setup_fail2ban() {
  log_step "Configuring fail2ban for Minecraft protection"

  # Create symlinks for fail2ban configuration
  local jail_source="$MINECRAFT_DIR/fail2ban/jail.d/minecraft.conf"
  local jail_target="/etc/fail2ban/jail.d/minecraft.conf"

  if [[ ! -L "$jail_target" ]]; then
    ln -sf "$jail_source" "$jail_target"
    log_info "Symlinked minecraft jail configuration"
  fi

  # Create symlinks for filters
  local filter_dir="/etc/fail2ban/filter.d"
  for filter in minecraft-scanner minecraft-flood; do
    local filter_source="$MINECRAFT_DIR/fail2ban/filter.d/${filter}.conf"
    local filter_target="$filter_dir/${filter}.conf"

    if [[ ! -L "$filter_target" ]]; then
      ln -sf "$filter_source" "$filter_target"
      log_info "Symlinked $filter filter"
    fi
  done
}

# Setup iptables rules for intelligent filtering
setup_iptables_rules() {
  log_step "Setting up intelligent iptables rules"

  # Create custom chain for Minecraft filtering
  if ! iptables -L MINECRAFT_FILTER > /dev/null 2>&1; then
    iptables -N MINECRAFT_FILTER
    log_info "Created MINECRAFT_FILTER chain"
  else
    # Clear existing rules
    iptables -F MINECRAFT_FILTER
    log_info "Cleared existing MINECRAFT_FILTER rules"
  fi

  # Rule 1: Always allow local network (unlimited)
  iptables -A MINECRAFT_FILTER -s 192.168.0.0/16 -j ACCEPT
  iptables -A MINECRAFT_FILTER -s 10.0.0.0/8 -j ACCEPT
  iptables -A MINECRAFT_FILTER -s 172.16.0.0/12 -j ACCEPT
  log_info "Added local network allow rules"

  # Rule 2: Allow Irish IPs with generous rate limiting
  iptables -A MINECRAFT_FILTER -m set --match-set ireland_ips src \
    -m limit --limit 40/hour --limit-burst 10 -j ACCEPT
  log_info "Added Irish IP preferential treatment"

  # Rule 3: Block temporarily flagged scanners
  iptables -A MINECRAFT_FILTER -m set --match-set temp_scanners src \
    -j LOG --log-prefix "MC-TEMP-BLOCKED: " --log-level 4
  iptables -A MINECRAFT_FILTER -m set --match-set temp_scanners src -j DROP
  log_info "Added temporary scanner blocking"

  # Rule 4: Detect and temporarily block SYN-only scanners
  # Mark IPs that only send SYN packets (typical scanners)
  iptables -A MINECRAFT_FILTER -p tcp --tcp-flags FIN,SYN,RST,ACK SYN \
    -m length --length 40:60 -m recent --name scanner_detection --set
  iptables -A MINECRAFT_FILTER -p tcp --tcp-flags FIN,SYN,RST,ACK SYN \
    -m recent --name scanner_detection --update --seconds 10 --hitcount 3 \
    -j SET --add-set temp_scanners src --exist
  log_info "Added SYN scanner detection"

  # Rule 5: Rate limit non-Irish external IPs
  iptables -A MINECRAFT_FILTER -m set ! --match-set ireland_ips src \
    -m limit --limit 5/hour --limit-burst 2 \
    -j LOG --log-prefix "MC-RATE-LIMITED: " --log-level 4
  iptables -A MINECRAFT_FILTER -m set ! --match-set ireland_ips src \
    -m limit --limit 5/hour --limit-burst 2 -j ACCEPT
  log_info "Added rate limiting for non-Irish IPs"

  # Rule 6: Log and drop everything else
  iptables -A MINECRAFT_FILTER -j LOG --log-prefix "MC-BLOCKED: " --log-level 4
  iptables -A MINECRAFT_FILTER -j DROP
  log_info "Added default deny with logging"

  # Apply filter to Minecraft port
  if ! iptables -L INPUT | grep -q "MINECRAFT_FILTER"; then
    # Insert before existing Minecraft logging rules
    local line_num=$(iptables -L INPUT --line-numbers | grep "MINECRAFT_LOG" | head -1 | cut -d' ' -f1)
    if [[ -n "$line_num" ]]; then
      iptables -I INPUT "$line_num" -p tcp --dport "$MINECRAFT_PORT" -j MINECRAFT_FILTER
    else
      iptables -I INPUT 1 -p tcp --dport "$MINECRAFT_PORT" -j MINECRAFT_FILTER
    fi
    log_info "Applied MINECRAFT_FILTER to port $MINECRAFT_PORT"
  fi
}

# Start and enable services
enable_services() {
  log_step "Enabling and starting security services"

  # Enable and start fail2ban
  systemctl enable fail2ban
  if systemctl is-active --quiet fail2ban; then
    systemctl reload fail2ban
    log_info "Reloaded fail2ban configuration"
  else
    systemctl start fail2ban
    log_info "Started fail2ban service"
  fi
}

# Update Irish IP ranges
update_irish_ips() {
  log_step "Updating Irish IP ranges"

  local temp_file="/tmp/irish_ips.txt"

  # Download Irish IP ranges from RIPE database
  if wget -q -O "$temp_file" "http://www.ipdeny.com/ipblocks/data/countries/ie.zone"; then
    # Clear existing Irish IPs
    ipset flush ireland_ips 2> /dev/null || true

    # Add new ranges
    local count=0
    while IFS= read -r ip_range; do
      if [[ -n "$ip_range" && ! "$ip_range" =~ ^# ]]; then
        ipset add ireland_ips "$ip_range" 2> /dev/null && ((count++))
      fi
    done < "$temp_file"

    log_info "Added $count Irish IP ranges to allowlist"
    rm -f "$temp_file"
  else
    log_warn "Failed to download Irish IP ranges - using existing set"
  fi
}

# Show current status
show_status() {
  log_step "Current Minecraft security status"

  echo ""
  echo -e "${BLUE}=== fail2ban Status ===${NC}"
  fail2ban-client status minecraft-scanner 2> /dev/null || echo "minecraft-scanner jail not active yet"

  echo ""
  echo -e "${BLUE}=== IP Sets ===${NC}"
  echo "Ireland IPs: $(ipset list ireland_ips | grep -c "^[0-9]" || echo "0") ranges"
  echo "Temp scanners: $(ipset list temp_scanners | grep -c "^[0-9]" || echo "0") IPs"

  echo ""
  echo -e "${BLUE}=== iptables Rules ===${NC}"
  iptables -L MINECRAFT_FILTER -n --line-numbers 2> /dev/null || echo "MINECRAFT_FILTER chain not found"
}

# Main setup function
main() {
  log_info "Starting Minecraft server security setup"

  check_root
  setup_ipsets
  setup_fail2ban
  setup_iptables_rules
  update_irish_ips
  enable_services
  show_status

  echo ""
  log_info "Minecraft security setup complete!"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "1. Monitor logs: sudo journalctl -f | grep 'MC-'"
  echo "2. Check fail2ban status: sudo fail2ban-client status"
  echo "3. Analyze patterns: ./analyze-banned-ips.sh"
  echo "4. Update Irish IPs weekly: ./update-irish-ips.sh"
}

# Handle command line arguments
case "${1:-setup}" in
  "setup" | "install")
    main
    ;;
  "status" | "show")
    show_status
    ;;
  "update-ips")
    check_root
    update_irish_ips
    ;;
  *)
    echo "Usage: $0 {setup|status|update-ips}"
    echo ""
    echo "Commands:"
    echo "  setup      - Full security setup (default)"
    echo "  status     - Show current security status"
    echo "  update-ips - Update Irish IP ranges"
    exit 1
    ;;
esac
