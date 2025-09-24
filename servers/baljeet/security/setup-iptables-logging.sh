#!/bin/bash
# Setup iptables logging for Minecraft server traffic
# Logs all connection attempts to port 25565 for security monitoring

set -euo pipefail

MINECRAFT_PORT="25565"
LOG_PREFIX="MINECRAFT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root (use sudo)"
  exit 1
fi

# Function to check if rule already exists
rule_exists() {
  iptables -L INPUT -n | grep -q "LOG.*$LOG_PREFIX.*tcp dpt:$MINECRAFT_PORT" 2> /dev/null
}

# Function to add logging rules
setup_logging() {
  log_info "Setting up iptables logging for Minecraft port $MINECRAFT_PORT"

  # Create a custom chain for Minecraft logging
  if ! iptables -L MINECRAFT_LOG -n > /dev/null 2>&1; then
    iptables -N MINECRAFT_LOG
    log_info "Created MINECRAFT_LOG chain"
  fi

  # Clear existing rules in the chain
  iptables -F MINECRAFT_LOG

  # Add logging rule with rate limiting to prevent log spam
  iptables -A MINECRAFT_LOG -m limit --limit 10/min --limit-burst 20 \
    -j LOG --log-prefix "$LOG_PREFIX: " --log-level 4

  # Accept the connection after logging
  iptables -A MINECRAFT_LOG -j ACCEPT

  # Insert rule to jump to logging chain for new connections on Minecraft port
  rule_exists
  if [[ $? -ne 0 ]]; then
    iptables -I INPUT -p tcp --dport "$MINECRAFT_PORT" -m conntrack --ctstate NEW \
      -j MINECRAFT_LOG
    log_info "Added logging rule for new connections to port $MINECRAFT_PORT"
  else
    log_warn "Logging rule already exists for port $MINECRAFT_PORT"
  fi

  # Also log connection attempts that might be rejected/dropped
  # Insert before any DROP rules
  iptables -I INPUT 1 -p tcp --dport "$MINECRAFT_PORT" \
    -m limit --limit 5/min --limit-burst 10 \
    -j LOG --log-prefix "$LOG_PREFIX-ATTEMPT: " --log-level 4

  log_info "iptables logging setup complete"
}

# Function to show current rules
show_rules() {
  echo ""
  log_info "Current iptables rules for Minecraft:"
  echo -e "${BLUE}=== INPUT chain rules ===${NC}"
  iptables -L INPUT -n --line-numbers | grep -E "(Chain|$MINECRAFT_PORT|$LOG_PREFIX)" || echo "No Minecraft-specific rules found"

  echo ""
  echo -e "${BLUE}=== MINECRAFT_LOG chain ===${NC}"
  iptables -L MINECRAFT_LOG -n --line-numbers 2> /dev/null || echo "MINECRAFT_LOG chain not found"
}

# Function to remove logging rules
remove_logging() {
  log_info "Removing iptables logging rules for Minecraft..."

  # Remove rules that jump to MINECRAFT_LOG
  iptables -D INPUT -p tcp --dport "$MINECRAFT_PORT" -m conntrack --ctstate NEW -j MINECRAFT_LOG 2> /dev/null || true

  # Remove direct logging rules
  iptables -D INPUT -p tcp --dport "$MINECRAFT_PORT" -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "$LOG_PREFIX-ATTEMPT: " --log-level 4 2> /dev/null || true

  # Flush and delete the custom chain
  iptables -F MINECRAFT_LOG 2> /dev/null || true
  iptables -X MINECRAFT_LOG 2> /dev/null || true

  log_info "Logging rules removed"
}

# Function to test logging
test_logging() {
  log_info "Testing iptables logging..."
  log_info "You can test by connecting to the Minecraft server and checking:"
  echo "  sudo journalctl -f | grep $LOG_PREFIX"
}

# Main function
main() {
  case "${1:-setup}" in
    "setup" | "install")
      setup_logging
      show_rules
      test_logging
      ;;
    "remove" | "uninstall")
      remove_logging
      ;;
    "show" | "status")
      show_rules
      ;;
    "test")
      test_logging
      ;;
    *)
      echo "Usage: $0 {setup|remove|show|test}"
      echo ""
      echo "Commands:"
      echo "  setup   - Install iptables logging rules (default)"
      echo "  remove  - Remove iptables logging rules"
      echo "  show    - Show current rules"
      echo "  test    - Show how to test logging"
      exit 1
      ;;
  esac
}

main "$@"
