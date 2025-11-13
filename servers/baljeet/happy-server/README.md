# Happy-Server Docker Deployment

Docker Compose configuration for running happy-server on baljeet.

## Directory Structure

**Development (Git-tracked):**
```
~/workspace/laingville/servers/baljeet/happy-server/
├── docker-compose.yml    # Service definitions (tracked in git)
├── .env.template         # Template for secrets (tracked in git)
├── README.md            # This file (tracked in git)
└── scripts/             # Management scripts (tracked in git)
```

**Production (Not in git):**
```
/srv/happy-server/       # FHS-compliant service location
├── docker-compose.yml   # Symlink to ~/workspace/laingville/servers/baljeet/happy-server/
├── Caddyfile           # Symlink to ~/workspace/laingville/servers/baljeet/happy-server/
├── happy-server-src/    # Cloned from github.com/slopus/happy-server
├── .env                 # Production secrets (NOT in git)
└── logs/                # Runtime logs (NOT in git)
```

## Prerequisites

- Docker and Docker Compose installed (via `setup-server`)
- GCS bucket created with HMAC keys
- `.env` file created from `.env.template`

## Initial Setup

### 1. Clone happy-server source

SSH to baljeet and clone the happy-server repository:
```bash
ssh baljeet
cd /srv/happy-server
git clone https://github.com/slopus/happy-server.git happy-server-src
```

### 2. Copy and configure secrets

```bash
# Copy and configure .env (one-time setup)
cp ~/workspace/laingville/servers/baljeet/happy-server/.env.template /srv/happy-server/.env
nano /srv/happy-server/.env  # Fill in secrets

# Configuration files (docker-compose.yml, Caddyfile) are automatically symlinked
# by setup-server, so no manual copying needed!
```

### 3. Start services

```bash
cd /srv/happy-server
docker-compose up -d
```

This will:
- Build the happy-server image from source (first time will take a few minutes)
- Start PostgreSQL and Redis containers
- Wait for health checks
- Start happy-server with your configuration
- Start Caddy reverse proxy with automatic HTTPS

### 4. Enable automatic startup

The `ensure_happy_server_running.bash` script (run via `setup-server`) automatically starts the services on boot.

## Daily Operations

All operations should be run from `/srv/happy-server/`:

### Start/Stop
```bash
cd /srv/happy-server
docker-compose up -d      # Start
docker-compose down       # Stop
docker-compose restart    # Restart all
```

### View Logs
```bash
cd /srv/happy-server
tail -f logs/server.log               # Application logs
docker-compose logs -f happy-server   # Container logs
```

### Health Check
```bash
cd /srv/happy-server
docker-compose ps                      # Service status
curl http://localhost:3005/health      # Application health (internal)
curl https://baljeet-tailnet/health    # Application health (via HTTPS)
curl http://localhost:9090/metrics     # Prometheus metrics (internal)
```

### Accessing the Web Interface

**For Claude Code web app (https://app.happy.engineering):**
```
Server URL: https://baljeet-tailnet
```

**For mobile app:**
```
Server URL: https://baljeet-tailnet
```

**Direct browser access:**
```
https://baljeet-tailnet/health  # Health check
https://baljeet-tailnet/stats   # Server statistics
```

Note: The Caddy reverse proxy automatically obtains and renews SSL certificates. The first HTTPS connection may take a few seconds while Caddy provisions the certificate.

## Updates

### Update happy-server source
```bash
cd /srv/happy-server/happy-server-src
git pull
cd ..
docker-compose build happy-server
docker-compose up -d happy-server
```

### Update configuration (docker-compose.yml or Caddyfile)
```bash
# 1. Edit in laingville repo (in Claude Code or your editor)
nano ~/workspace/laingville/servers/baljeet/happy-server/docker-compose.yml
# or
nano ~/workspace/laingville/servers/baljeet/happy-server/Caddyfile

# 2. Commit to git (optional but recommended)
git add servers/baljeet/happy-server/
git commit -m "chore: update happy-server configuration"
git push

# 3. Run setup-server to automatically sync and restart
cd ~/workspace/laingville
./bin/setup-server

# This will:
# - Symlink updated configuration files to /srv/happy-server
# - Restart services with updated configuration
# - Wait for health checks to pass
```

## Backups

### Automated Backups

Automated PostgreSQL backups run daily at 2 AM via cron job:
- **Script**: `~/workspace/laingville/servers/baljeet/scripts/backup-happy-server.bash`
- **Local backups**: `/srv/happy-server/backups/` (7 daily backups retained)
- **Off-site backups**: `gs://laingville-backups/baljeet/happy-server/database/`
- **Log file**: `/srv/happy-server/backups/backup.log`

Check backup status:
```bash
# View recent backups
ls -lh /srv/happy-server/backups/

# Check backup log
tail -f /srv/happy-server/backups/backup.log

# List backups in GCS
cd /srv/happy-server
source .env
export RCLONE_CONFIG_GCS_TYPE=s3 \
       RCLONE_CONFIG_GCS_PROVIDER=GCS \
       RCLONE_CONFIG_GCS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
       RCLONE_CONFIG_GCS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
       RCLONE_CONFIG_GCS_ENDPOINT=https://storage.googleapis.com \
       RCLONE_CONFIG_GCS_NO_CHECK_BUCKET=true \
       RCLONE_CONFIG_GCS_LOCATION_CONSTRAINT="" \
       RCLONE_CONFIG_GCS_FORCE_PATH_STYLE=true
rclone ls gcs:laingville-backups/baljeet/happy-server/database/
```

### Manual Backup

Create an on-demand backup:
```bash
~/workspace/laingville/servers/baljeet/scripts/backup-happy-server.bash
```

### Restore from Backup

**1. Restore from local backup:**
```bash
cd /srv/happy-server
# Stop happy-server to ensure clean restore
docker-compose stop happy-server

# Restore from local backup file
zcat backups/happy-db-20251111_114009.sql.gz | \
  docker-compose exec -T postgres psql -U postgres handy

# Restart happy-server
docker-compose start happy-server
```

**2. Restore from GCS backup:**
```bash
cd /srv/happy-server
source .env

# Configure rclone environment
export RCLONE_CONFIG_GCS_TYPE=s3 \
       RCLONE_CONFIG_GCS_PROVIDER=GCS \
       RCLONE_CONFIG_GCS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
       RCLONE_CONFIG_GCS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
       RCLONE_CONFIG_GCS_ENDPOINT=https://storage.googleapis.com \
       RCLONE_CONFIG_GCS_NO_CHECK_BUCKET=true \
       RCLONE_CONFIG_GCS_LOCATION_CONSTRAINT="" \
       RCLONE_CONFIG_GCS_FORCE_PATH_STYLE=true

# Download backup from GCS
rclone copy gcs:laingville-backups/baljeet/happy-server/database/happy-db-20251111_114009.sql.gz .

# Stop happy-server
docker-compose stop happy-server

# Restore database
zcat happy-db-20251111_114009.sql.gz | \
  docker-compose exec -T postgres psql -U postgres handy

# Restart happy-server
docker-compose start happy-server
```

**3. Complete database rebuild (if needed):**
```bash
cd /srv/happy-server

# Stop all services
docker-compose down

# Remove postgres volume (WARNING: destroys all data)
docker volume rm happy-server_postgres-data

# Start postgres
docker-compose up -d postgres

# Wait for postgres to be healthy
sleep 10

# Restore from backup
zcat backups/happy-db-20251111_114009.sql.gz | \
  docker-compose exec -T postgres psql -U postgres handy

# Start all services
docker-compose up -d
```

## Troubleshooting

### Service won't start
```bash
cd /srv/happy-server
docker-compose ps           # Check status
docker-compose logs <svc>   # View logs
```

### Database connection errors
```bash
cd /srv/happy-server
docker-compose exec postgres pg_isready -U postgres
```

### GCS upload failures
```bash
cd /srv/happy-server
curl -I https://storage.googleapis.com
docker-compose logs happy-server | grep S3
```

## Configuration Management

**What's in git (laingville repo):**
- `docker-compose.yml` - Service definitions (auto-symlinked to production)
- `Caddyfile` - Reverse proxy config (auto-symlinked to production)
- `.env.template` - Template for secrets
- `README.md` - Documentation
- `scripts/ensure_happy_server_running.bash` - Symlinks configs and starts services

**What's NOT in git (production only):**
- `happy-server-src/` - External git repo
- `.env` - Secrets (one-time manual setup)
- `logs/` - Runtime data
- `*.crt`, `*.key` - Tailscale HTTPS certificates

**Deploying changes (automatic):**
1. Edit files in `~/workspace/laingville/servers/baljeet/happy-server/`
2. Commit to git (optional but recommended)
3. Run `./bin/setup-server` on baljeet

This will:
- Symlink updated configuration files (like dotfiles!)
- Restart services automatically with docker-compose
- Wait for health checks to pass

**How it works:**
- `setup-server` calls `ensure_happy_server_running.bash`
- Script symlinks docker-compose.yml and Caddyfile to `/srv/happy-server/`
- Then starts/restarts services with `docker-compose up -d` (idempotent)
- Changes to repo files are immediately reflected in production
