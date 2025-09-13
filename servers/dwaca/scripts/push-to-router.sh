#!/bin/bash
# Push configurations to dwaca router via rsync (for development)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ROUTER_IP="192.168.2.1"
ROUTER_USER="admin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWACA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
fi

echo -e "${GREEN}Pushing dwaca configurations to router...${NC}"
echo "Source: $DWACA_DIR"
echo "Target: $ROUTER_USER@$ROUTER_IP:/opt/laingville/servers/dwaca/"

# Rsync options
RSYNC_OPTS="-av --delete"
if [ "$DRY_RUN" = true ]; then
  RSYNC_OPTS="$RSYNC_OPTS --dry-run"
fi

# Push the dwaca directory to router
echo -e "\n${YELLOW}Syncing files...${NC}"

# Check if rsync is available, otherwise use scp
if command -v rsync &> /dev/null; then
  rsync $RSYNC_OPTS \
    --exclude '.git' \
    --exclude '*.swp' \
    --exclude '.DS_Store' \
    "$DWACA_DIR/" \
    "$ROUTER_USER@$ROUTER_IP:/opt/laingville/servers/dwaca/"
else
  echo "rsync not found, using scp instead..."
  if [ "$DRY_RUN" = true ]; then
    echo "Would copy: $DWACA_DIR/* to $ROUTER_USER@$ROUTER_IP:/opt/laingville/servers/dwaca/"
  else
    scp -r "$DWACA_DIR"/* "$ROUTER_USER@$ROUTER_IP:/opt/laingville/servers/dwaca/"
  fi
fi

if [ "$DRY_RUN" = false ]; then
  echo -e "\n${YELLOW}Running apply-configs.sh on router...${NC}"
  ssh "$ROUTER_USER@$ROUTER_IP" "/opt/laingville/servers/dwaca/scripts/apply-configs.sh"
  echo -e "${GREEN}✓ Configuration pushed and applied successfully${NC}"
else
  echo -e "\n${YELLOW}Would run: ssh $ROUTER_USER@$ROUTER_IP /opt/laingville/servers/dwaca/scripts/apply-configs.sh${NC}"
  echo -e "${GREEN}✓ Dry run completed${NC}"
fi
