#!/usr/bin/env bash
# Tailscale Firewalld Configuration Script for baljeet
# Configures firewalld to allow all traffic from Tailscale network (100.64.0.0/10)

set -e

DRY_RUN="${1:-false}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[Tailscale Firewalld]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[Tailscale Firewalld]${NC} $1"; }
log_error() { echo -e "${RED}[Tailscale Firewalld]${NC} $1"; }

# Check if firewalld is installed
if ! command -v firewall-cmd &> /dev/null; then
  log_error "firewalld not found. Please install it first."
  exit 1
fi

# Check if firewalld is running
if ! systemctl is-active --quiet firewalld; then
  log_error "firewalld is not running. Please start it first."
  exit 1
fi

# Tailscale CGNAT range
TAILSCALE_RANGE="100.64.0.0/10"
ZONE="public"
RICH_RULE="rule family=\"ipv4\" source address=\"${TAILSCALE_RANGE}\" accept"

if [[ "${DRY_RUN}" = "true" ]]; then
  log_info "[DRY RUN] Would configure firewalld to allow Tailscale traffic"
  log_info "[DRY RUN] Would add rich rule to zone '${ZONE}': ${RICH_RULE}"
  exit 0
fi

log_info "Configuring firewalld to allow Tailscale traffic from ${TAILSCALE_RANGE}..."

# Check if we need sudo
SUDO=""
if [[ $EUID -ne 0 ]]; then
  if command -v sudo &> /dev/null; then
    SUDO="sudo"
  else
    log_error "This script requires root privileges"
    exit 1
  fi
fi

# Check if the rich rule already exists in the permanent configuration
if $SUDO firewall-cmd --permanent --zone="${ZONE}" --query-rich-rule="${RICH_RULE}" &> /dev/null; then
  log_info "Rich rule already exists in permanent configuration"
else
  # Add the rich rule to permanent configuration
  if $SUDO firewall-cmd --permanent --zone="${ZONE}" --add-rich-rule="${RICH_RULE}"; then
    log_info "Added rich rule to permanent configuration"
  else
    log_error "Failed to add rich rule to permanent configuration"
    exit 1
  fi
fi

# Check if the rich rule exists in runtime configuration
if $SUDO firewall-cmd --zone="${ZONE}" --query-rich-rule="${RICH_RULE}" &> /dev/null; then
  log_info "Rich rule already exists in runtime configuration"
else
  # Add the rich rule to runtime configuration
  if $SUDO firewall-cmd --zone="${ZONE}" --add-rich-rule="${RICH_RULE}"; then
    log_info "Added rich rule to runtime configuration"
  else
    log_error "Failed to add rich rule to runtime configuration"
    exit 1
  fi
fi

log_info "[OK] Firewalld configured to allow all Tailscale traffic"
echo ""
log_info "Current rich rules in zone '${ZONE}':"
$SUDO firewall-cmd --zone="${ZONE}" --list-rich-rules
