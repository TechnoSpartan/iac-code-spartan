#!/bin/bash

################################################################################
# CodeSpartan Mambo Cloud - Backup Script
#
# Backs up critical infrastructure components:
# - Grafana dashboards and datasources
# - VictoriaMetrics data
# - Loki logs
# - Traefik SSL certificates
# - All configuration files
#
# Usage: ./backup.sh [backup-name]
################################################################################

set -euo pipefail

# Configuration
BACKUP_ROOT="/opt/backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${1:-backup_${BACKUP_DATE}}"
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"
RETENTION_DAYS=7
RETENTION_COUNT=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo"
   exit 1
fi

# Create backup directories
log_info "Creating backup directory: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"/{grafana,victoriametrics,loki,traefik,configs,volumes}

# Start backup
log_info "========================================="
log_info "Starting backup: ${BACKUP_NAME}"
log_info "Date: $(date)"
log_info "========================================="

################################################################################
# 1. BACKUP GRAFANA
################################################################################
log_info "Backing up Grafana..."

if docker ps | grep -q grafana; then
    # Backup Grafana database (SQLite)
    docker exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup /var/lib/grafana/grafana_backup.db" 2>/dev/null || true
    docker cp grafana:/var/lib/grafana/grafana_backup.db "${BACKUP_DIR}/grafana/" 2>/dev/null || log_warn "Could not backup Grafana database"

    # Backup Grafana dashboards via API
    GRAFANA_URL="http://localhost:3000"
    GRAFANA_USER="admin"
    GRAFANA_PASS="codespartan123"

    mkdir -p "${BACKUP_DIR}/grafana/dashboards"

    # Get all dashboard UIDs
    DASHBOARD_UIDS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        "${GRAFANA_URL}/api/search?type=dash-db" | \
        grep -o '"uid":"[^"]*"' | cut -d'"' -f4 || echo "")

    if [ -n "$DASHBOARD_UIDS" ]; then
        for uid in $DASHBOARD_UIDS; do
            curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
                "${GRAFANA_URL}/api/dashboards/uid/${uid}" \
                > "${BACKUP_DIR}/grafana/dashboards/${uid}.json" 2>/dev/null || true
        done
        log_success "Backed up $(echo "$DASHBOARD_UIDS" | wc -w) Grafana dashboards"
    else
        log_warn "No Grafana dashboards found to backup"
    fi

    # Backup datasources
    curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        "${GRAFANA_URL}/api/datasources" \
        > "${BACKUP_DIR}/grafana/datasources.json" 2>/dev/null || log_warn "Could not backup datasources"

    log_success "Grafana backup completed"
else
    log_warn "Grafana container not running, skipping"
fi

################################################################################
# 2. BACKUP VICTORIAMETRICS
################################################################################
log_info "Backing up VictoriaMetrics data..."

if docker ps | grep -q victoriametrics; then
    # Create snapshot
    SNAPSHOT_NAME=$(curl -s http://localhost:8428/snapshot/create | grep -o '"snapshot":"[^"]*"' | cut -d'"' -f4 || echo "")

    if [ -n "$SNAPSHOT_NAME" ]; then
        # Copy snapshot data
        docker cp victoriametrics:/victoria-metrics-data/snapshots/${SNAPSHOT_NAME} \
            "${BACKUP_DIR}/victoriametrics/" 2>/dev/null || log_warn "Could not copy VictoriaMetrics snapshot"

        # Delete remote snapshot to save space
        curl -s "http://localhost:8428/snapshot/delete?snapshot=${SNAPSHOT_NAME}" >/dev/null 2>&1 || true

        log_success "VictoriaMetrics backup completed (snapshot: ${SNAPSHOT_NAME})"
    else
        log_warn "Could not create VictoriaMetrics snapshot"
    fi
else
    log_warn "VictoriaMetrics container not running, skipping"
fi

################################################################################
# 3. BACKUP LOKI (Last 7 days only - full backup too large)
################################################################################
log_info "Backing up Loki configuration and recent data..."

if docker ps | grep -q loki; then
    # Backup Loki config
    docker cp loki:/etc/loki/loki-config.yml "${BACKUP_DIR}/loki/" 2>/dev/null || log_warn "Could not backup Loki config"

    # Note: Full Loki data backup is typically too large
    # We backup configs only, data is ephemeral with 7-day retention
    log_success "Loki configuration backed up"
else
    log_warn "Loki container not running, skipping"
fi

################################################################################
# 4. BACKUP TRAEFIK (SSL Certificates)
################################################################################
log_info "Backing up Traefik SSL certificates..."

if [ -f /opt/codespartan/platform/traefik/letsencrypt/acme.json ]; then
    cp /opt/codespartan/platform/traefik/letsencrypt/acme.json \
        "${BACKUP_DIR}/traefik/" 2>/dev/null || log_warn "Could not backup SSL certificates"
    log_success "Traefik SSL certificates backed up"
else
    log_warn "acme.json not found, skipping SSL backup"
fi

# Backup Traefik configs
if [ -d /opt/codespartan/platform/traefik ]; then
    cp -r /opt/codespartan/platform/traefik/*.yml "${BACKUP_DIR}/traefik/" 2>/dev/null || true
    cp /opt/codespartan/platform/traefik/.env "${BACKUP_DIR}/traefik/" 2>/dev/null || true
    log_success "Traefik configuration backed up"
fi

################################################################################
# 5. BACKUP ALL CONFIGURATIONS
################################################################################
log_info "Backing up all application configurations..."

if [ -d /opt/codespartan ]; then
    # Backup all docker-compose files and configs
    find /opt/codespartan -name "docker-compose.yml" -exec cp --parents {} "${BACKUP_DIR}/configs/" \; 2>/dev/null || true
    find /opt/codespartan -name ".env" -exec cp --parents {} "${BACKUP_DIR}/configs/" \; 2>/dev/null || true
    find /opt/codespartan -name "*.yml" -exec cp --parents {} "${BACKUP_DIR}/configs/" \; 2>/dev/null || true
    find /opt/codespartan -name "*.yaml" -exec cp --parents {} "${BACKUP_DIR}/configs/" \; 2>/dev/null || true

    log_success "Configuration files backed up"
fi

################################################################################
# 6. BACKUP CRITICAL DOCKER VOLUMES
################################################################################
log_info "Backing up critical Docker volumes..."

# List of critical volumes to backup
CRITICAL_VOLUMES=(
    "grafana-data"
    "prometheus-data"
    "loki-data"
)

for volume in "${CRITICAL_VOLUMES[@]}"; do
    if docker volume inspect "$volume" >/dev/null 2>&1; then
        log_info "Backing up volume: $volume"
        docker run --rm \
            -v "${volume}:/source:ro" \
            -v "${BACKUP_DIR}/volumes:/backup" \
            alpine \
            tar czf "/backup/${volume}.tar.gz" -C /source . \
            2>/dev/null || log_warn "Could not backup volume: $volume"
    fi
done

################################################################################
# 7. CREATE METADATA FILE
################################################################################
log_info "Creating backup metadata..."

cat > "${BACKUP_DIR}/backup_metadata.txt" <<EOF
Backup Name: ${BACKUP_NAME}
Backup Date: $(date)
Hostname: $(hostname)
Backup Size: $(du -sh "${BACKUP_DIR}" | cut -f1)

Containers backed up:
$(docker ps --format "- {{.Names}} ({{.Image}})")

Volumes backed up:
$(for vol in "${CRITICAL_VOLUMES[@]}"; do echo "- $vol"; done)

Backup Contents:
$(find "${BACKUP_DIR}" -type f | sed "s|${BACKUP_DIR}/|- |" | sort)
EOF

log_success "Metadata created"

################################################################################
# 8. COMPRESS BACKUP
################################################################################
log_info "Compressing backup..."

cd "${BACKUP_ROOT}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/" 2>/dev/null

if [ -f "${BACKUP_NAME}.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log_success "Backup compressed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

    # Remove uncompressed directory
    rm -rf "${BACKUP_DIR}"
else
    log_error "Failed to compress backup"
    exit 1
fi

################################################################################
# 9. CLEANUP OLD BACKUPS (Keep last N backups)
################################################################################
log_info "Cleaning up old backups (keeping last ${RETENTION_COUNT})..."

cd "${BACKUP_ROOT}"
BACKUP_COUNT=$(ls -1 backup_*.tar.gz 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt "$RETENTION_COUNT" ]; then
    ls -1t backup_*.tar.gz | tail -n +$((RETENTION_COUNT + 1)) | xargs rm -f
    log_success "Removed $((BACKUP_COUNT - RETENTION_COUNT)) old backups"
else
    log_info "No old backups to remove"
fi

################################################################################
# 10. SUMMARY
################################################################################
log_info "========================================="
log_success "Backup completed successfully!"
log_info "Backup file: ${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz"
log_info "Backup size: ${BACKUP_SIZE}"
log_info "Total backups: $(ls -1 ${BACKUP_ROOT}/backup_*.tar.gz 2>/dev/null | wc -l)"
log_info "========================================="

# List all available backups
log_info "Available backups:"
ls -lh "${BACKUP_ROOT}"/backup_*.tar.gz 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'

exit 0
