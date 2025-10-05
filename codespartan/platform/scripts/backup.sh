#!/bin/bash

###############################################################################
# CodeSpartan Mambo Cloud Platform - Backup Script
###############################################################################
#
# Backs up critical data:
# - Docker volumes (VictoriaMetrics, Loki, Grafana)
# - Configuration files (/opt/codespartan/)
# - SSL certificates (Traefik Let's Encrypt)
#
# Retention:
# - Local: 7 days
# - Remote: 30 days (if remote backup configured)
#
# Schedule: Daily at 3:00 AM via cron
#
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
BACKUP_DIR="/opt/codespartan/backups"
PLATFORM_DIR="/opt/codespartan/platform"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="backup-${DATE}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
RETENTION_DAYS=7

# Remote backup configuration (optional)
ENABLE_REMOTE_BACKUP="${ENABLE_REMOTE_BACKUP:-false}"
REMOTE_BACKUP_TYPE="${REMOTE_BACKUP_TYPE:-none}"  # none, s3, rsync, storage-box
REMOTE_RETENTION_DAYS=30

# Notification webhook (ntfy.sh)
NTFY_TOPIC="${NTFY_TOPIC:-codespartan-mambo-alerts}"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Send notification
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-3}"  # Default: medium priority

    if command -v curl &> /dev/null; then
        curl -s -X POST "${NTFY_URL}" \
            -H "Title: ${title}" \
            -H "Priority: ${priority}" \
            -d "${message}" > /dev/null 2>&1 || true
    fi
}

# Check if user can access Docker
if ! docker ps &> /dev/null; then
   error "This script requires Docker access. Ensure user is in docker group or run as root."
   error "To add user to docker group: sudo usermod -aG docker \$USER"
   exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

log "Starting backup process..."
notify "🔄 Backup Started" "Creating backup: ${BACKUP_NAME}" 3

# Create temporary directory for staging backup files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

log "Temporary staging directory: ${TEMP_DIR}"

###############################################################################
# 1. Backup Docker Volumes
###############################################################################

log "Backing up Docker volumes..."

VOLUMES=("victoria-data" "loki-data" "grafana-data")

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "${volume}" &> /dev/null; then
        log "  - Backing up volume: ${volume}"

        # Create volume backup directory
        mkdir -p "${TEMP_DIR}/volumes/${volume}"

        # Use a temporary container to tar the volume
        docker run --rm \
            -v "${volume}:/data:ro" \
            -v "${TEMP_DIR}/volumes/${volume}:/backup" \
            alpine:latest \
            tar czf "/backup/data.tar.gz" -C /data .

        log "    ✓ Volume ${volume} backed up"
    else
        warn "  - Volume ${volume} not found, skipping"
    fi
done

###############################################################################
# 2. Backup Configuration Files
###############################################################################

log "Backing up configuration files..."

# Backup entire platform directory structure
if [[ -d "${PLATFORM_DIR}" ]]; then
    log "  - Copying platform configuration files"
    mkdir -p "${TEMP_DIR}/platform"

    # Copy platform configs (excluding backups directory)
    rsync -a \
        --exclude 'backups' \
        --exclude '*.log' \
        --exclude '.git' \
        "${PLATFORM_DIR}/" "${TEMP_DIR}/platform/"

    log "    ✓ Platform configs backed up"
else
    warn "  - Platform directory not found: ${PLATFORM_DIR}"
fi

###############################################################################
# 3. Backup SSL Certificates
###############################################################################

log "Backing up SSL certificates..."

TRAEFIK_CERTS="${PLATFORM_DIR}/traefik/letsencrypt"

if [[ -d "${TRAEFIK_CERTS}" ]]; then
    log "  - Copying Traefik Let's Encrypt certificates"
    mkdir -p "${TEMP_DIR}/ssl"
    cp -r "${TRAEFIK_CERTS}" "${TEMP_DIR}/ssl/"
    log "    ✓ SSL certificates backed up"
else
    warn "  - SSL certificates directory not found: ${TRAEFIK_CERTS}"
fi

###############################################################################
# 4. Create Metadata
###############################################################################

log "Creating backup metadata..."

cat > "${TEMP_DIR}/backup-info.txt" <<EOF
CodeSpartan Mambo Cloud Platform - Backup
==========================================

Backup Date: ${DATE}
Hostname: $(hostname)
Server IP: $(hostname -I | awk '{print $1}')

Docker Volumes Backed Up:
$(for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" &> /dev/null; then
        size=$(docker system df -v | grep "$vol" | awk '{print $3}')
        echo "  - $vol (${size:-unknown})"
    fi
done)

Containers Running at Backup Time:
$(docker ps --format "  - {{.Names}} ({{.Image}})" | head -20)

Platform Version:
$(cd ${PLATFORM_DIR}/../../ && git log -1 --pretty=format:"  Commit: %h%n  Date: %ai%n  Message: %s" 2>/dev/null || echo "  Git info not available")

Backup Size: Will be calculated after compression
EOF

log "    ✓ Metadata created"

###############################################################################
# 5. Compress Backup
###############################################################################

log "Compressing backup archive..."

tar czf "${BACKUP_PATH}" -C "${TEMP_DIR}" .

BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
log "    ✓ Backup compressed: ${BACKUP_SIZE}"

# Update metadata with final size
echo "Final Backup Size: ${BACKUP_SIZE}" >> "${TEMP_DIR}/backup-info.txt"

###############################################################################
# 6. Cleanup Old Backups
###############################################################################

log "Cleaning up old local backups (retention: ${RETENTION_DAYS} days)..."

find "${BACKUP_DIR}" -name "backup-*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete

LOCAL_BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "backup-*.tar.gz" -type f | wc -l)
log "    ✓ Local backups retained: ${LOCAL_BACKUP_COUNT}"

###############################################################################
# 7. Remote Backup (Optional)
###############################################################################

if [[ "${ENABLE_REMOTE_BACKUP}" == "true" ]]; then
    log "Uploading backup to remote storage..."

    case "${REMOTE_BACKUP_TYPE}" in
        s3)
            # AWS S3 or S3-compatible (Backblaze B2, Wasabi, etc.)
            if command -v aws &> /dev/null; then
                log "  - Uploading to S3: ${S3_BUCKET}/${BACKUP_NAME}"
                aws s3 cp "${BACKUP_PATH}" "s3://${S3_BUCKET}/${BACKUP_NAME}"

                # Cleanup old remote backups
                log "  - Cleaning up old S3 backups (retention: ${REMOTE_RETENTION_DAYS} days)"
                # This requires a separate script or AWS lifecycle policy
            else
                warn "  - AWS CLI not installed, skipping S3 upload"
            fi
            ;;

        rsync)
            # Rsync to remote server
            if command -v rsync &> /dev/null && [[ -n "${RSYNC_DEST:-}" ]]; then
                log "  - Uploading via rsync to: ${RSYNC_DEST}"
                rsync -avz "${BACKUP_PATH}" "${RSYNC_DEST}/"
            else
                warn "  - Rsync not configured or not installed"
            fi
            ;;

        storage-box)
            # Hetzner Storage Box via rsync/scp
            if command -v rsync &> /dev/null && [[ -n "${STORAGE_BOX_USER:-}" ]] && [[ -n "${STORAGE_BOX_HOST:-}" ]]; then
                log "  - Uploading to Hetzner Storage Box: ${STORAGE_BOX_HOST}"
                rsync -avz -e "ssh -p 23" "${BACKUP_PATH}" "${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:backups/"
            else
                warn "  - Hetzner Storage Box not configured"
            fi
            ;;

        *)
            log "  - Remote backup disabled or unknown type: ${REMOTE_BACKUP_TYPE}"
            ;;
    esac
fi

###############################################################################
# 8. Summary & Notification
###############################################################################

log "Backup completed successfully!"
log ""
log "Summary:"
log "  - Backup file: ${BACKUP_PATH}"
log "  - Backup size: ${BACKUP_SIZE}"
log "  - Local backups: ${LOCAL_BACKUP_COUNT}"
log "  - Retention: ${RETENTION_DAYS} days"
log ""

# Send success notification
notify "✅ Backup Completed" "Backup created successfully: ${BACKUP_NAME} (${BACKUP_SIZE})" 3

exit 0
