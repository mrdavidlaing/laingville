#!/usr/bin/env bash

# Tailscale Configuration Script
# Enables tailscaled service and optionally authenticates with Tailscale

set -e

DRY_RUN="${1:-false}"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Tailscale] [DRY RUN] Would enable tailscaled service"
  if [[ -n "${TS_AUTHKEY:-}" ]]; then
    echo "[Tailscale] [DRY RUN] Would authenticate with TS_AUTHKEY and enable --ssh --accept-routes"
  else
    echo "[Tailscale] [DRY RUN] Would print authentication instructions"
  fi
  exit 0
fi

echo -n "[Tailscale] "

# Detect platform for service management
platform="unknown"
if [[ "$(uname)" == "Darwin" ]]; then
  platform="macos"
elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
  platform="wsl"
elif [[ "$(uname)" == "Linux" ]]; then
  platform="linux"
fi

# Check if tailscale is installed
if ! command -v tailscale &> /dev/null; then
  echo "[ERROR] Tailscale not found. Please install it first."
  exit 1
fi

# Enable and start tailscaled service (platform-specific)
case "${platform}" in
  linux | wsl)
    echo "Enabling tailscaled service..."
    if command -v systemctl &> /dev/null; then
      if ! sudo systemctl is-enabled tailscaled &> /dev/null; then
        sudo systemctl enable tailscaled
      fi
      if ! sudo systemctl is-active tailscaled &> /dev/null; then
        sudo systemctl start tailscaled
      fi
      echo "[Tailscale] Service enabled and started"
    else
      echo "[WARNING] systemctl not found, service management skipped"
    fi
    ;;
  macos)
    # On macOS, Homebrew's tailscale package doesn't auto-start a service
    # The user needs to run tailscaled manually or use the GUI app
    # For CLI-only setup, we can start tailscaled in the background
    if ! pgrep -x tailscaled &> /dev/null; then
      echo "Starting tailscaled daemon..."
      # Start tailscaled in background (requires sudo)
      # Note: For production use, consider using a LaunchDaemon
      sudo tailscaled &> /dev/null &
      sleep 2 # Wait for daemon to start
      echo "[Tailscale] Daemon started"
    else
      echo "[Tailscale] Daemon already running"
    fi
    ;;
  *)
    echo "[WARNING] Unknown platform, service management skipped"
    ;;
esac

# Check if already authenticated
if tailscale status &> /dev/null; then
  current_status=$(tailscale status 2>&1 | head -n 1)
  if [[ ! "${current_status}" =~ "Logged out" ]]; then
    echo "[OK] Tailscale already authenticated"
    echo ""
    tailscale status
    exit 0
  fi
fi

# Authenticate with Tailscale
if [[ -n "${TS_AUTHKEY:-}" ]]; then
  echo "Authenticating with auth key..."
  if sudo tailscale up --authkey="${TS_AUTHKEY}" --ssh --accept-routes; then
    echo "[Tailscale] [OK] Authentication successful"
    echo ""
    tailscale status
  else
    echo "[Tailscale] [ERROR] Authentication failed"
    exit 1
  fi
else
  echo "[OK] Service configured"
  echo ""
  echo "To authenticate Tailscale, run:"
  echo "  sudo tailscale up --ssh --accept-routes"
  echo ""
  echo "This will:"
  echo "  - Open your browser to authenticate"
  echo "  - Enable Tailscale SSH for remote access"
  echo "  - Accept subnet routes from other devices"
  echo ""
  echo "Optional: Set TS_AUTHKEY environment variable for automated authentication"
  echo "  Get auth key from: https://login.tailscale.com/admin/settings/keys"
fi
