#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAPPY_DIR="${SCRIPT_DIR}/../happy-server"
COMPOSE_FILE="${HAPPY_DIR}/docker-compose.yml"

echo "Ensuring happy-server Docker stack is running..."

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed"
  exit 1
fi

if ! docker info &> /dev/null; then
  echo "ERROR: Docker daemon is not running"
  exit 1
fi

# Check if docker-compose exists
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "WARNING: $COMPOSE_FILE not found - skipping happy-server startup"
  exit 0
fi

# Check if .env exists
if [ ! -f "${HAPPY_DIR}/.env" ]; then
  echo "WARNING: ${HAPPY_DIR}/.env not found"
  echo "Copy .env.template to .env and configure secrets before starting"
  exit 0
fi

# Start the stack (docker-compose up -d is idempotent)
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
