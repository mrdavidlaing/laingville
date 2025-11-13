#!/usr/bin/env bash
set -euo pipefail

# Ensure Happy Server is configured and running
# This script:
# 1. Symlinks configuration files from repo to /srv/happy-server
# 2. Starts the Docker stack if not already running
# 3. Waits for services to become healthy

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../happy-server" && pwd)"
HAPPY_DIR="/srv/happy-server"
COMPOSE_FILE="${HAPPY_DIR}/docker-compose.yml"

echo "Ensuring happy-server Docker stack is running..."

# Check if production directory exists
if [ ! -d "$HAPPY_DIR" ]; then
  echo "INFO: $HAPPY_DIR does not exist yet"
  echo "This is normal for first-time setup - run initial setup manually:"
  echo "  ssh baljeet"
  echo "  sudo mkdir -p /srv/happy-server"
  echo "  sudo chown \$USER:\$USER /srv/happy-server"
  echo "  cd /srv/happy-server"
  echo "  git clone https://github.com/slopus/happy-server.git happy-server-src"
  echo "  cp ${REPO_DIR}/.env.template .env"
  echo "  nano .env  # Configure secrets"
  exit 0
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed"
  exit 1
fi

if ! docker info &> /dev/null; then
  echo "ERROR: Docker daemon is not running"
  exit 1
fi

# Check if .env exists
if [ ! -f "${HAPPY_DIR}/.env" ]; then
  echo "WARNING: ${HAPPY_DIR}/.env not found"
  echo "Copy .env.template to .env and configure secrets before starting"
  exit 0
fi

# Symlink configuration files from repo to production
echo "Symlinking configuration files..."

symlink_file() {
  local filename="$1"
  local src="${REPO_DIR}/${filename}"
  local dst="${HAPPY_DIR}/${filename}"

  if [ ! -f "$src" ]; then
    echo "WARNING: Source file not found: $src"
    return 1
  fi

  # If destination is already a symlink pointing to the right place
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "  $filename is already correctly symlinked"
    return 0
  fi

  # If destination exists but is not the correct symlink, remove it
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "  Removing existing $filename"
    rm "$dst"
  fi

  # Create symlink
  echo "  Symlinking $filename -> $src"
  ln -s "$src" "$dst"
  return 0
}

symlink_file "docker-compose.yml"
symlink_file "Caddyfile"

# Security: Ensure .env has proper permissions (owner-only readable)
chmod 600 "${HAPPY_DIR}/.env"

# Start the stack (docker-compose up -d is idempotent)
echo "Starting services..."
cd "$HAPPY_DIR"
docker-compose up -d

# Wait for health checks
echo "Waiting for services to become healthy..."
timeout 60s bash -c 'until docker-compose ps | grep -q "healthy"; do sleep 2; done' || {
  echo "WARNING: Services did not become healthy within 60 seconds"
  docker-compose ps
  exit 0
}

echo "Happy-server stack is running:"
docker-compose ps
