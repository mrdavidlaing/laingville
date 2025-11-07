#!/usr/bin/env bash
set -euo pipefail

echo "=== Happy-Server Deployment Verification ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
}

check_warn() {
  echo -e "${YELLOW}!${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAPPY_DIR="$(dirname "$SCRIPT_DIR")"

# Check 1: Docker installed
echo "Checking Docker installation..."
if command -v docker &> /dev/null; then
  check_pass "Docker is installed ($(docker --version))"
else
  check_fail "Docker is not installed"
  exit 1
fi

# Check 2: Docker daemon running
echo "Checking Docker daemon..."
if docker info &> /dev/null; then
  check_pass "Docker daemon is running"
else
  check_fail "Docker daemon is not running"
  exit 1
fi

# Check 3: Docker Compose installed
echo "Checking Docker Compose..."
if docker-compose --version &> /dev/null; then
  check_pass "Docker Compose is installed ($(docker-compose --version))"
else
  check_fail "Docker Compose is not installed"
  exit 1
fi

# Check 4: Configuration files exist
echo "Checking configuration files..."
if [ -f "$HAPPY_DIR/docker-compose.yml" ]; then
  check_pass "docker-compose.yml exists"
else
  check_fail "docker-compose.yml not found"
  exit 1
fi

if [ -f "$HAPPY_DIR/.env" ]; then
  check_pass ".env file exists"
else
  check_warn ".env file not found (copy from .env.template)"
fi

# Check 5: Services running
echo "Checking Docker services..."
cd "$HAPPY_DIR"

if docker-compose ps | grep -q "Up"; then
  check_pass "Docker services are running"

  # Check individual services
  if docker-compose ps postgres | grep -q "healthy"; then
    check_pass "PostgreSQL is healthy"
  else
    check_warn "PostgreSQL is not healthy"
  fi

  if docker-compose ps redis | grep -q "healthy"; then
    check_pass "Redis is healthy"
  else
    check_warn "Redis is not healthy"
  fi

  if docker-compose ps happy-server | grep -q "Up"; then
    check_pass "happy-server is running"
  else
    check_warn "happy-server is not running"
  fi
else
  check_warn "Docker services are not running (use: docker-compose up -d)"
fi

# Check 6: Application responding
echo "Checking application endpoints..."
if curl -sf http://localhost:3005/health > /dev/null 2>&1; then
  check_pass "Application health endpoint responding"
else
  check_warn "Application health endpoint not responding"
fi

if curl -sf http://localhost:9090/metrics > /dev/null 2>&1; then
  check_pass "Metrics endpoint responding"
else
  check_warn "Metrics endpoint not responding"
fi

# Check 7: Volumes exist
echo "Checking Docker volumes..."
if docker volume ls | grep -q "happy-postgres-data"; then
  check_pass "PostgreSQL volume exists"
  SIZE=$(docker volume inspect happy-postgres-data | grep -o '"Mountpoint": "[^"]*"' | cut -d'"' -f4 | xargs du -sh 2> /dev/null | cut -f1 || echo "unknown")
  echo "  Size: $SIZE"
else
  check_warn "PostgreSQL volume not found"
fi

if docker volume ls | grep -q "happy-redis-data"; then
  check_pass "Redis volume exists"
else
  check_warn "Redis volume not found"
fi

# Check 8: Network exists
echo "Checking Docker network..."
if docker network ls | grep -q "happy-network"; then
  check_pass "happy-network exists"
else
  check_warn "happy-network not found"
fi

# Check 9: GCS configuration (if .env exists)
if [ -f "$HAPPY_DIR/.env" ]; then
  echo "Checking GCS configuration..."
  if grep -q "S3_ACCESS_KEY=" "$HAPPY_DIR/.env" && ! grep -q "S3_ACCESS_KEY=your-" "$HAPPY_DIR/.env"; then
    check_pass "GCS access key configured"
  else
    check_warn "GCS access key not configured"
  fi

  if grep -q "S3_BUCKET=" "$HAPPY_DIR/.env" && ! grep -q "S3_BUCKET=happy-server-yourname" "$HAPPY_DIR/.env"; then
    check_pass "GCS bucket configured"
  else
    check_warn "GCS bucket not configured"
  fi
fi

echo
echo "=== Verification Complete ==="
echo
echo "Next steps:"
echo "  1. If .env missing: cp .env.template .env && nano .env"
echo "  2. If services down: docker-compose up -d"
echo "  3. View logs: docker-compose logs -f"
echo "  4. Check status: docker-compose ps"
