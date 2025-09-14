#!/bin/sh
# Apply configurations on dwaca router
# This script runs ON the router

set -e

# Configuration
CONFIG_DIR="/opt/laingville/servers/dwaca/configs"
JFFS_DIR="/jffs/configs"
LOG_FILE="/tmp/dwaca-apply.log"

# Simple logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting configuration apply for dwaca"

# Ensure directories exist
mkdir -p "$JFFS_DIR"

# Apply test MOTD
if [ -f "$CONFIG_DIR/test-motd" ]; then
  log "Applying test MOTD..."
  # Update the date placeholder
  sed "s/PLACEHOLDER_DATE/$(date '+%Y-%m-%d %H:%M:%S')/" "$CONFIG_DIR/test-motd" > /tmp/motd
  cp /tmp/motd "$JFFS_DIR/motd"
  log "✓ MOTD updated"
fi

# Apply profile additions (for SSH login customization)
if [ -f "$CONFIG_DIR/profile.add" ]; then
  log "Applying profile additions..."
  cp "$CONFIG_DIR/profile.add" "$JFFS_DIR/profile.add"
  chmod +x "$JFFS_DIR/profile.add"
  log "✓ Profile additions updated"
fi

# Apply Diversion allowlist (if exists)
if [ -f "$CONFIG_DIR/diversion-allowlist" ]; then
  log "Applying Diversion allowlist..."
  cp "$CONFIG_DIR/diversion-allowlist" /opt/share/diversion/list/allowlist
  log "✓ Diversion allowlist updated"
fi

# Apply Diversion denylist (if exists)
if [ -f "$CONFIG_DIR/diversion-denylist" ]; then
  log "Applying Diversion denylist..."
  cp "$CONFIG_DIR/diversion-denylist" /opt/share/diversion/list/denylist
  log "✓ Diversion denylist updated"
fi

# Apply dnsmasq configuration additions (if exists)
if [ -f "$CONFIG_DIR/dnsmasq.conf.add" ]; then
  log "Applying dnsmasq configuration..."
  cp "$CONFIG_DIR/dnsmasq.conf.add" "$JFFS_DIR/dnsmasq.conf.add"
  # Restart dnsmasq to apply changes
  service restart_dnsmasq
  log "✓ dnsmasq configuration updated and service restarted"
fi

# Apply custom firewall rules (if exists)
if [ -f "$CONFIG_DIR/firewall-start" ]; then
  log "Applying firewall rules..."
  cp "$CONFIG_DIR/firewall-start" /jffs/scripts/firewall-start
  chmod +x /jffs/scripts/firewall-start
  log "✓ Firewall rules updated"
fi

log "Configuration apply completed successfully"

# Display MOTD to show it worked
if [ -f "$JFFS_DIR/motd" ]; then
  echo ""
  cat "$JFFS_DIR/motd"
fi
