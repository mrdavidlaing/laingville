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

### 2. Clone happy-server source on baljeet

SSH to baljeet and clone the happy-server repository:
```bash
ssh baljeet
cd /opt/laingville/servers/baljeet/happy-server
git clone https://github.com/slopus/happy-server.git happy-server-src
```

### 3. Create .env file on baljeet

Create production environment file:
```bash
cd /opt/laingville/servers/baljeet/happy-server
cp .env.template .env
nano .env  # Fill in secrets
```

### 4. Start services

```bash
docker-compose up -d
```

This will:
- Build the happy-server image from source (first time will take a few minutes)
- Start PostgreSQL and Redis containers
- Wait for health checks
- Start happy-server with your configuration

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
cd /opt/laingville/servers/baljeet/happy-server/happy-server-src
git pull
cd ..
docker-compose build happy-server
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
