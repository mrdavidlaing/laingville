#!/usr/bin/env bash
set -euo pipefail

# Happy Server PostgreSQL Backup Script
# Backs up the database and uploads to GCS for off-site storage

# Configuration
BACKUP_DIR="/srv/happy-server/backups"
COMPOSE_DIR="/srv/happy-server"
DB_NAME="handy"
DB_USER="postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/happy-db-${TIMESTAMP}.sql.gz"
GCS_BUCKET="laingville-backups"
GCS_BACKUP_PATH="baljeet/happy-server/database"

# Retention policy
KEEP_DAILY=7  # Keep 7 daily backups
KEEP_WEEKLY=4 # Keep 4 weekly backups

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info &> /dev/null; then
  log_error "Docker daemon is not running"
  exit 1
fi

# Check if happy-server stack is running
if ! docker-compose -f "${COMPOSE_DIR}/docker-compose.yml" ps | grep -q "postgres.*healthy"; then
  log_error "PostgreSQL container is not healthy"
  exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Security: Ensure backup directory has proper permissions (owner-only accessible)
chmod 700 "${BACKUP_DIR}"

log_info "Starting PostgreSQL backup..."
log_info "Backup file: ${BACKUP_FILE}"

# Perform the backup (dump and compress in one step)
if docker-compose -f "${COMPOSE_DIR}/docker-compose.yml" exec -T postgres \
  pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"; then

  # Security: Set restrictive permissions on backup file (owner-only readable)
  chmod 600 "${BACKUP_FILE}"

  BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
  log_info "Backup completed successfully (${BACKUP_SIZE})"
else
  log_error "Database backup failed"
  exit 1
fi

# Upload to GCS
log_info "Uploading backup to GCS..."

# Read GCS credentials from .env file
if [ -f "${COMPOSE_DIR}/.env" ]; then
  # Source the .env file to get S3 credentials
  export "$(grep -E '^S3_ACCESS_KEY=' "${COMPOSE_DIR}/.env" | xargs)"
  export "$(grep -E '^S3_SECRET_KEY=' "${COMPOSE_DIR}/.env" | xargs)"
fi

if [ -z "${S3_ACCESS_KEY:-}" ] || [ -z "${S3_SECRET_KEY:-}" ]; then
  log_warn "GCS credentials not found in .env - backup saved locally only"
elif command -v rclone &> /dev/null; then
  # Use rclone with GCS S3 compatibility mode
  log_info "Uploading to GCS via rclone..."

  # rclone uses environment variables for S3 credentials
  export RCLONE_CONFIG_GCS_TYPE=s3
  export RCLONE_CONFIG_GCS_PROVIDER=GCS
  export RCLONE_CONFIG_GCS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
  export RCLONE_CONFIG_GCS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
  export RCLONE_CONFIG_GCS_ENDPOINT=https://storage.googleapis.com
  export RCLONE_CONFIG_GCS_NO_CHECK_BUCKET=true
  export RCLONE_CONFIG_GCS_LOCATION_CONSTRAINT=""
  export RCLONE_CONFIG_GCS_FORCE_PATH_STYLE=true

  if rclone copy "${BACKUP_FILE}" "gcs:${GCS_BUCKET}/${GCS_BACKUP_PATH}/" --progress --s3-no-check-bucket --s3-upload-cutoff=0; then
    log_info "Backup uploaded to gs://${GCS_BUCKET}/${GCS_BACKUP_PATH}/"
    GCS_UPLOADED="yes"
  else
    log_warn "GCS upload failed - backup saved locally only"
    GCS_UPLOADED="no"
  fi
else
  log_warn "rclone not found - backup saved locally only"
  log_warn "Install rclone for automatic GCS uploads"
  GCS_UPLOADED="no"
fi

# Cleanup old local backups
log_info "Cleaning up old backups..."

# Keep daily backups for the last KEEP_DAILY days
find "${BACKUP_DIR}" -name "happy-db-*.sql.gz" -mtime +"${KEEP_DAILY}" -delete

# Count remaining backups
BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "happy-db-*.sql.gz" | wc -l)
log_info "Local backups retained: ${BACKUP_COUNT}"

log_info "Backup process completed successfully"

# Print backup summary
echo ""
echo "=== Backup Summary ==="
echo "Timestamp:    ${TIMESTAMP}"
echo "File:         ${BACKUP_FILE}"
echo "Size:         ${BACKUP_SIZE}"
echo "GCS Upload:   ${GCS_UPLOADED:-no}"
echo "GCS Location: gs://${GCS_BUCKET}/${GCS_BACKUP_PATH}/"
echo "======================"
