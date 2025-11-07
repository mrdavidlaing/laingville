# Happy-Server Docker Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy happy-server (Claude Code sync service) on baljeet server using Docker Compose with PostgreSQL, Redis, and Google Cloud Storage.

**Architecture:** Three-container stack (PostgreSQL 15, Redis 7, happy-server) orchestrated via Docker Compose on dedicated bridge network. GCS provides S3-compatible image storage. Configuration managed via laingville repository.

**Tech Stack:** Docker Compose, PostgreSQL 15, Redis 7, Node.js/Fastify, Google Cloud Storage, Prisma ORM

---

## Task 1: Create happy-server directory structure in baljeet server config

**Files:**
- Create: `servers/baljeet/happy-server/.gitkeep`
- Create: `servers/baljeet/happy-server/docker-compose.yml`
- Create: `servers/baljeet/happy-server/.env.template`
- Create: `servers/baljeet/happy-server/README.md`

**Step 1: Create directory and placeholder**

```bash
mkdir -p servers/baljeet/happy-server
touch servers/baljeet/happy-server/.gitkeep
```

**Step 2: Create docker-compose.yml**

File: `servers/baljeet/happy-server/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: happy-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: handy
    volumes:
      - happy-postgres-data:/var/lib/postgresql/data
    networks:
      - happy-network
    mem_limit: 1g
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: happy-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - happy-redis-data:/data
    networks:
      - happy-network
    mem_limit: 512m
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  happy-server:
    image: slopus/happy-server:latest
    container_name: happy-server
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/handy
      REDIS_URL: redis://redis:6379
      S3_HOST: storage.googleapis.com
      S3_PORT: 443
      S3_USE_SSL: true
      NODE_ENV: production
      METRICS_ENABLED: true
      METRICS_PORT: 9090
    env_file:
      - .env
    volumes:
      - ./logs:/app/.logs
    ports:
      - "3005:3005"
      - "9090:9090"
    networks:
      - happy-network
    mem_limit: 1g

volumes:
  happy-postgres-data:
  happy-redis-data:

networks:
  happy-network:
    driver: bridge
```

**Step 3: Create environment template**

File: `servers/baljeet/happy-server/.env.template`

```bash
# Happy Server Configuration Template
# Copy this to .env and fill in the values

# REQUIRED: Master secret for authentication (generate with: openssl rand -base64 32)
HANDY_MASTER_SECRET=your-secret-here

# REQUIRED: PostgreSQL password (generate with: openssl rand -base64 32)
POSTGRES_PASSWORD=your-postgres-password-here

# REQUIRED: Google Cloud Storage HMAC credentials
# Generate at: https://console.cloud.google.com/storage/settings;tab=interoperability
S3_ACCESS_KEY=your-gcs-hmac-access-key
S3_SECRET_KEY=your-gcs-hmac-secret
S3_BUCKET=happy-server-yourname
S3_PUBLIC_URL=https://storage.googleapis.com/happy-server-yourname

# OPTIONAL: AI debugging (set to false in production)
DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=false
```

**Step 4: Create README documentation**

File: `servers/baljeet/happy-server/README.md`

```markdown
# Happy-Server Docker Deployment

Docker Compose configuration for running happy-server on baljeet.

## Prerequisites

- Docker and Docker Compose installed (via `setup-server`)
- GCS bucket created with HMAC keys
- `.env` file created from `.env.template`

## Initial Setup

### 1. Deploy configuration to baljeet

From laingville repository:
```bash
./bin/remote-setup-server baljeet
```

### 2. Create .env file on baljeet

SSH to baljeet and create production environment:
```bash
ssh baljeet
cd /opt/laingville/servers/baljeet/happy-server
cp .env.template .env
nano .env  # Fill in secrets
```

### 3. Start services

```bash
docker-compose up -d
```

### 4. Initialize database

```bash
# Wait for health checks (~30 seconds)
docker-compose ps

# Run migrations (if using git clone method)
# docker-compose exec happy-server yarn generate
# docker-compose exec happy-server yarn migrate
```

## Daily Operations

### Start/Stop
```bash
docker-compose up -d    # Start
docker-compose down     # Stop
docker-compose restart  # Restart all
```

### View Logs
```bash
tail -f logs/server.log               # Application logs
docker-compose logs -f happy-server   # Container logs
```

### Health Check
```bash
docker-compose ps                      # Service status
curl http://localhost:3005/health      # Application health
curl http://localhost:9090/metrics     # Prometheus metrics
```

## Updates

### Update happy-server
```bash
docker-compose pull happy-server
docker-compose up -d happy-server
```

### Backup database
```bash
docker-compose exec postgres pg_dump -U postgres handy > ~/backups/happy-$(date +%Y%m%d).sql
```

### Restore database
```bash
cat ~/backups/happy-20250107.sql | docker-compose exec -T postgres psql -U postgres handy
```

## Troubleshooting

### Service won't start
```bash
docker-compose ps           # Check status
docker-compose logs <svc>   # View logs
```

### Database connection errors
```bash
docker-compose exec postgres pg_isready -U postgres
```

### GCS upload failures
```bash
curl -I https://storage.googleapis.com
docker-compose logs happy-server | grep S3
```

## Configuration Management

This directory is managed via laingville repository:
- `docker-compose.yml` - Committed to git
- `.env.template` - Committed to git
- `.env` - **NOT in git** (contains secrets)
- `logs/` - **NOT in git** (runtime data)

Deploy changes:
```bash
# From laingville repo
git add servers/baljeet/happy-server/
git commit -m "Update happy-server config"
./bin/remote-setup-server baljeet
```
```

**Step 5: Verify files created**

```bash
ls -la servers/baljeet/happy-server/
```

Expected output:
```
.gitkeep
docker-compose.yml
.env.template
README.md
```

**Step 6: Commit**

```bash
git add servers/baljeet/happy-server/
git commit -m "feat(baljeet): add happy-server Docker Compose configuration

Add Docker Compose stack for happy-server with PostgreSQL and Redis.
Uses GCS for image storage. Configuration managed via laingville.

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 2: Add .gitignore rules for happy-server runtime files

**Files:**
- Create: `servers/baljeet/happy-server/.gitignore`

**Step 1: Create .gitignore**

File: `servers/baljeet/happy-server/.gitignore`

```gitignore
# Environment secrets
.env

# Runtime logs
logs/
*.log

# Backup files
*.sql
*.dump

# Docker volumes (managed by Docker)
postgres-data/
redis-data/
```

**Step 2: Verify .gitignore works**

```bash
cd servers/baljeet/happy-server
touch .env logs/test.log backups/test.sql
git status
```

Expected: `.env`, `logs/`, and `*.sql` files should NOT appear in untracked files.

**Step 3: Clean up test files**

```bash
rm .env logs/test.log backups/test.sql
```

**Step 4: Commit**

```bash
git add servers/baljeet/happy-server/.gitignore
git commit -m "feat(baljeet): add .gitignore for happy-server secrets and runtime files

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 3: Update baljeet packages.yaml to add docker service

**Files:**
- Modify: `servers/baljeet/packages.yaml:21-21`

**Step 1: Read current packages.yaml**

```bash
cat servers/baljeet/packages.yaml
```

**Step 2: Add ensure_happy_server_running custom package**

Modify line 21 from:
```yaml
    - ensure_docker_running
```

To:
```yaml
    - ensure_docker_running
    - ensure_happy_server_running
```

**Step 3: Verify syntax**

```bash
cat servers/baljeet/packages.yaml | grep -A 3 custom
```

Expected:
```yaml
  custom:
    - ensure_sshd_running
    - ensure_minecraft_security_running
    - ensure_docker_running
    - ensure_happy_server_running
```

**Step 4: Commit**

```bash
git add servers/baljeet/packages.yaml
git commit -m "feat(baljeet): add ensure_happy_server_running to packages

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 4: Create ensure_happy_server_running script

**Files:**
- Create: `servers/baljeet/scripts/ensure_happy_server_running.bash`

**Step 1: Create the script**

File: `servers/baljeet/scripts/ensure_happy_server_running.bash`

```bash
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
```

**Step 2: Make script executable**

```bash
chmod +x servers/baljeet/scripts/ensure_happy_server_running.bash
```

**Step 3: Test script locally (dry-run)**

```bash
bash -n servers/baljeet/scripts/ensure_happy_server_running.bash
```

Expected: No syntax errors

**Step 4: Commit**

```bash
git add servers/baljeet/scripts/ensure_happy_server_running.bash
git commit -m "feat(baljeet): add ensure_happy_server_running startup script

Ensures happy-server Docker stack starts automatically via setup-server.
Handles missing .env gracefully with warning message.

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 5: Add documentation for GCS setup

**Files:**
- Create: `servers/baljeet/happy-server/docs/gcs-setup.md`

**Step 1: Create docs directory**

```bash
mkdir -p servers/baljeet/happy-server/docs
```

**Step 2: Create GCS setup guide**

File: `servers/baljeet/happy-server/docs/gcs-setup.md`

```markdown
# Google Cloud Storage Setup for Happy-Server

Happy-server uses Google Cloud Storage (GCS) with S3-compatible API for image uploads.

## Prerequisites

- Google Cloud Project
- `gcloud` CLI installed and authenticated
- Billing enabled on GCP project

## One-Time Setup

### 1. Create GCS Bucket

```bash
# Set your preferred region (us-central1, europe-west1, etc.)
REGION="us-central1"
BUCKET_NAME="happy-server-$(whoami)"
GCP_PROJECT="your-gcp-project-id"

# Create bucket
gsutil mb -p "$GCP_PROJECT" -c STANDARD -l "$REGION" "gs://${BUCKET_NAME}"
```

### 2. Enable Public Read Access

This allows uploaded images to be accessed via direct URLs:

```bash
gsutil iam ch allUsers:objectViewer "gs://${BUCKET_NAME}"
```

**Security Note:** This makes all uploaded images publicly readable. For private deployments, configure application-level authentication instead.

### 3. Generate HMAC Keys

HMAC keys allow happy-server to use GCS via S3-compatible API.

**Via Console:**
1. Go to [Cloud Storage > Settings > Interoperability](https://console.cloud.google.com/storage/settings;tab=interoperability)
2. Click "Create a key for a service account"
3. Select service account or create new one
4. Copy the **Access Key** and **Secret**

**Via gcloud:**
```bash
# Create service account
gcloud iam service-accounts create happy-server-storage \
    --display-name="Happy Server Storage Access"

# Grant storage admin permissions
gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member="serviceAccount:happy-server-storage@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

# Generate HMAC key
gcloud storage hmac create happy-server-storage@${GCP_PROJECT}.iam.gserviceaccount.com
```

**Save the output** - you'll need it for `.env` configuration.

### 4. Configure .env

Add to `servers/baljeet/happy-server/.env`:

```bash
S3_ACCESS_KEY=GOOG1E...  # From HMAC generation
S3_SECRET_KEY=...         # From HMAC generation
S3_BUCKET=happy-server-yourname
S3_PUBLIC_URL=https://storage.googleapis.com/happy-server-yourname
```

## Verification

### Test Upload (Optional)

```bash
# Create test file
echo "Hello from happy-server" > test.txt

# Upload using gsutil
gsutil cp test.txt "gs://${BUCKET_NAME}/"

# Test public access
curl "https://storage.googleapis.com/${BUCKET_NAME}/test.txt"

# Clean up
gsutil rm "gs://${BUCKET_NAME}/test.txt"
```

Expected: `curl` returns "Hello from happy-server"

## Cost Management

### Free Tier (Always Free)
- 5 GB storage
- 1 GB network egress to North America per month
- 5,000 Class A operations
- 50,000 Class B operations

For personal use (2-3 devices), you'll likely stay within free tier.

### Monitoring Usage

```bash
# Check bucket size
gsutil du -sh "gs://${BUCKET_NAME}"

# List all objects
gsutil ls -r "gs://${BUCKET_NAME}"
```

### Cost Estimate
- Average image: 500KB
- 10 images/day × 30 days = 150MB/month
- **Stays within 5GB free tier**

## Backup Strategy

**No manual backups needed!**

GCS provides:
- 99.999999999% (11 nines) annual durability
- Automatic redundancy across multiple availability zones
- Versioning available (optional)

Images stored in GCS are more durable than local backups.

## Troubleshooting

### HMAC Key Errors

```bash
# List existing HMAC keys
gcloud storage hmac list

# Delete invalid key
gcloud storage hmac delete ACCESS_KEY_ID
```

### Permission Denied

```bash
# Check bucket IAM policy
gsutil iam get "gs://${BUCKET_NAME}"

# Re-add public read
gsutil iam ch allUsers:objectViewer "gs://${BUCKET_NAME}"
```

### Bucket Not Found

```bash
# List all buckets in project
gsutil ls -p "$GCP_PROJECT"

# Verify bucket name in .env matches actual bucket
```

## Security Best Practices

1. **Rotate HMAC keys periodically** (every 90 days)
2. **Use service account** instead of user account for HMAC
3. **Enable audit logging** for storage access
4. **Consider bucket versioning** for accidental deletion protection
5. **Monitor costs** via GCP billing dashboard

## Alternative: Private Images

To make images private (requires authentication):

```bash
# Remove public access
gsutil iam ch -d allUsers:objectViewer "gs://${BUCKET_NAME}"

# Generate signed URLs in application code
# (Requires code changes to happy-server)
```

---

**Reference:** See `docker-compose.yml` and `.env.template` for integration configuration.
```

**Step 3: Commit**

```bash
git add servers/baljeet/happy-server/docs/
git commit -m "docs(baljeet): add GCS setup guide for happy-server

Complete instructions for creating bucket, HMAC keys, and cost monitoring.

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 6: Update main implementation plan to reference laingville integration

**Files:**
- Modify: `/home/mrdavidlaing/workspace/pensive/docs/plans/2025-11-06-happy-server-docker-deployment.md:569-584`

**Step 1: Read current checklist section**

```bash
grep -A 20 "## Implementation Checklist" /home/mrdavidlaing/workspace/pensive/docs/plans/2025-11-06-happy-server-docker-deployment.md
```

**Step 2: Replace implementation checklist**

Replace the current checklist with laingville-integrated approach:

```markdown
## Implementation Checklist

### Prerequisites (One-Time)
- [ ] Install Docker and Docker Compose on baljeet (automated via `setup-server`)
- [ ] Add user to docker group and re-login
- [ ] Create GCS bucket with public read access (see `servers/baljeet/happy-server/docs/gcs-setup.md`)
- [ ] Generate GCS HMAC keys

### Deployment (From Laingville Repo)
- [ ] Commit happy-server configuration to laingville repository
- [ ] Deploy to baljeet: `./bin/remote-setup-server baljeet`
- [ ] SSH to baljeet and create `.env` from template
- [ ] Start services: `docker-compose up -d` (automated via `ensure_happy_server_running`)
- [ ] Verify services healthy: `docker-compose ps`
- [ ] Test application: `curl http://localhost:3005/health`
- [ ] Configure Claude Code clients to use `http://baljeet:3005`
- [ ] Create initial database backup

### Maintenance
- [ ] Document backup procedure in personal notes
- [ ] Set calendar reminder for HMAC key rotation (90 days)
- [ ] Add monitoring check (optional)
```

**Step 3: Verify change**

```bash
grep -A 25 "## Implementation Checklist" /home/mrdavidlaing/workspace/pensive/docs/plans/2025-11-06-happy-server-docker-deployment.md
```

**Step 4: Commit in pensive repo**

```bash
cd /home/mrdavidlaing/workspace/pensive
git add docs/plans/2025-11-06-happy-server-docker-deployment.md
git commit -m "docs: update happy-server implementation checklist for laingville integration

Reference automated deployment via remote-setup-server and GCS docs.

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Task 7: Create deployment verification script

**Files:**
- Create: `servers/baljeet/happy-server/scripts/verify-deployment.sh`

**Step 1: Create scripts directory**

```bash
mkdir -p servers/baljeet/happy-server/scripts
```

**Step 2: Create verification script**

File: `servers/baljeet/happy-server/scripts/verify-deployment.sh`

```bash
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
    SIZE=$(docker volume inspect happy-postgres-data | grep -o '"Mountpoint": "[^"]*"' | cut -d'"' -f4 | xargs du -sh 2>/dev/null | cut -f1 || echo "unknown")
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
```

**Step 3: Make script executable**

```bash
chmod +x servers/baljeet/happy-server/scripts/verify-deployment.sh
```

**Step 4: Test syntax**

```bash
bash -n servers/baljeet/happy-server/scripts/verify-deployment.sh
```

Expected: No errors

**Step 5: Commit**

```bash
git add servers/baljeet/happy-server/scripts/
git commit -m "feat(baljeet): add deployment verification script for happy-server

Checks Docker, services, volumes, network, and endpoints.
Provides colored output and actionable next steps.

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

## Verification

After implementing all tasks:

1. **Verify git status is clean:**
   ```bash
   git status
   ```

2. **Verify directory structure:**
   ```bash
   tree servers/baljeet/happy-server/
   ```

   Expected:
   ```
   servers/baljeet/happy-server/
   ├── .gitignore
   ├── .env.template
   ├── README.md
   ├── docker-compose.yml
   ├── docs/
   │   └── gcs-setup.md
   └── scripts/
       └── verify-deployment.sh
   ```

3. **Test deployment (dry-run):**
   ```bash
   ./bin/setup-server --dry-run
   ```

## Post-Implementation

After completing all tasks, the configuration is ready for deployment:

```bash
# Commit and push
git push origin main

# Deploy to baljeet
./bin/remote-setup-server baljeet

# SSH to baljeet and complete setup
ssh baljeet
cd /opt/laingville/servers/baljeet/happy-server
cp .env.template .env
nano .env  # Configure secrets
docker-compose up -d
./scripts/verify-deployment.sh
```

---

**Implementation Notes:**
- All secrets stay on baljeet server (never committed to git)
- Configuration is version-controlled and reproducible
- Deployment is automated via `remote-setup-server`
- Service starts automatically via `ensure_happy_server_running`
