#!/bin/bash
# Update Irish IP ranges for Minecraft server allowlist
# Run weekly via cron to keep Irish IP ranges current

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root (use sudo)"
  exit 1
fi

update_irish_ips() {
  log_info "Updating Irish IP ranges from RIPE database"

  local temp_file="/tmp/irish_ips_$(date +%s).txt"
  local backup_file="/tmp/irish_ips_backup_$(date +%s).txt"

  # Backup current Irish IPs
  ipset save ireland_ips > "$backup_file" 2> /dev/null || true

  # Download fresh Irish IP ranges
  local sources=(
    "http://www.ipdeny.com/ipblocks/data/countries/ie.zone"
    "https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/ie.cidr"
  )

  local downloaded=false
  for source in "${sources[@]}"; do
    log_info "Trying source: $source"
    if curl -s --connect-timeout 10 --max-time 30 -o "$temp_file" "$source"; then
      if [[ -s "$temp_file" ]]; then
        downloaded=true
        break
      fi
    fi
    log_warn "Failed to download from $source"
  done

  if [[ "$downloaded" != true ]]; then
    log_error "Failed to download Irish IP ranges from all sources"
    rm -f "$temp_file" "$backup_file"
    exit 1
  fi

  # Validate downloaded data
  local line_count=$(wc -l < "$temp_file")
  if [[ $line_count -lt 10 ]]; then
    log_error "Downloaded data seems invalid (only $line_count lines)"
    rm -f "$temp_file" "$backup_file"
    exit 1
  fi

  # Create temporary ipset for validation
  local temp_set="ireland_ips_temp_$$"
  ipset create "$temp_set" hash:net comment

  # Add ranges to temporary set
  local count=0
  local errors=0
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Clean the line (remove whitespace)
    line=$(echo "$line" | tr -d '[:space:]')

    # Validate IP range format
    if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
      if ipset add "$temp_set" "$line" 2> /dev/null; then
        ((count++))
      else
        ((errors++))
      fi
    fi
  done < "$temp_file"

  log_info "Processed $count valid IP ranges ($errors errors)"

  if [[ $count -lt 50 ]]; then
    log_error "Too few valid IP ranges found ($count). Aborting update."
    ipset destroy "$temp_set"
    rm -f "$temp_file" "$backup_file"
    exit 1
  fi

  # Swap the sets atomically
  ipset swap "$temp_set" ireland_ips
  ipset destroy "$temp_set"

  log_info "Successfully updated Irish IP allowlist with $count ranges"

  # Clean up
  rm -f "$temp_file"

  # Keep backup for a day
  echo "# Irish IP backup from $(date)" > "${backup_file}.info"
  echo "# Restore with: ipset restore < $backup_file" >> "${backup_file}.info"

  log_info "Backup saved to $backup_file (auto-cleanup in 24h)"

  # Schedule cleanup of old backups
  find /tmp -name "irish_ips_backup_*" -mtime +1 -delete 2> /dev/null || true
}

# Show current statistics
show_stats() {
  echo ""
  echo "=== Irish IP Allowlist Statistics ==="
  local count=$(ipset list ireland_ips | grep -c "^[0-9]" || echo "0")
  echo "Total IP ranges: $count"
  echo "Last update: $(date)"

  if [[ $count -gt 0 ]]; then
    echo ""
    echo "Sample ranges:"
    ipset list ireland_ips | grep "^[0-9]" | head -5
    if [[ $count -gt 5 ]]; then
      echo "... and $((count - 5)) more"
    fi
  fi
}

# Main function
main() {
  case "${1:-update}" in
    "update")
      update_irish_ips
      show_stats
      ;;
    "status" | "show")
      show_stats
      ;;
    *)
      echo "Usage: $0 {update|status}"
      echo ""
      echo "Commands:"
      echo "  update - Update Irish IP ranges (default)"
      echo "  status - Show current statistics"
      exit 1
      ;;
  esac
}

main "$@"
