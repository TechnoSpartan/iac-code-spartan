#!/bin/bash

################################################################################
# CodeSpartan Mambo Cloud - Restore Script
#
# Restores from backup created by backup.sh
#
# Usage: ./restore.sh <backup-file.tar.gz> [--component grafana|traefik|all]
################################################################################

set -euo pipefail

# Configuration
BACKUP_ROOT="/opt/backups"
RESTORE_TMP="/tmp/restore_$(date +%Y%m%d_%H%M%S)"

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

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup-file.tar.gz> [--component grafana|traefik|configs|all]"
    echo ""
    echo "Available backups:"
    ls -lh "${BACKUP_ROOT}"/backup_*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    exit 1
fi

BACKUP_FILE="$1"
COMPONENT="${2:-all}"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    # Try finding it in backup root
    if [ -f "${BACKUP_ROOT}/${BACKUP_FILE}" ]; then
        BACKUP_FILE="${BACKUP_ROOT}/${BACKUP_FILE}"
    else
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
fi

log_info "========================================="
log_info "Starting restore from: $(basename $BACKUP_FILE)"
log_info "Component: $COMPONENT"
log_info "Date: $(date)"
log_info "========================================="

# Create temporary restore directory
mkdir -p "$RESTORE_TMP"

# Extract backup
log_info "Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$RESTORE_TMP"

# Find the extracted directory
BACKUP_DIR=$(find "$RESTORE_TMP" -maxdepth 1 -type d -name "backup_*" | head -1)

if [ -z "$BACKUP_DIR" ]; then
    log_error "Could not find backup data in archive"
    rm -rf "$RESTORE_TMP"
    exit 1
fi

log_success "Backup extracted to: $BACKUP_DIR"

# Show backup metadata
if [ -f "$BACKUP_DIR/backup_metadata.txt" ]; then
    log_info "Backup metadata:"
    cat "$BACKUP_DIR/backup_metadata.txt" | head -10
    echo ""
fi

################################################################################
# RESTORE FUNCTIONS
################################################################################

restore_grafana() {
    log_info "Restoring Grafana..."

    if [ ! -d "$BACKUP_DIR/grafana" ]; then
        log_warn "No Grafana backup found in archive"
        return 1
    fi

    # Restore Grafana database
    if [ -f "$BACKUP_DIR/grafana/grafana_backup.db" ]; then
        docker cp "$BACKUP_DIR/grafana/grafana_backup.db" grafana:/var/lib/grafana/grafana.db
        docker restart grafana
        log_success "Grafana database restored"
    fi

    # Restore dashboards via API
    if [ -d "$BACKUP_DIR/grafana/dashboards" ]; then
        GRAFANA_URL="http://localhost:3000"
        GRAFANA_USER="admin"
        GRAFANA_PASS="codespartan123"

        # Wait for Grafana to be ready
        sleep 5

        for dashboard_file in "$BACKUP_DIR/grafana/dashboards"/*.json; do
            if [ -f "$dashboard_file" ]; then
                dashboard_uid=$(basename "$dashboard_file" .json)
                log_info "Restoring dashboard: $dashboard_uid"

                curl -s -X POST -H "Content-Type: application/json" \
                    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
                    -d @"$dashboard_file" \
                    "${GRAFANA_URL}/api/dashboards/db" >/dev/null 2>&1 || log_warn "Could not restore dashboard: $dashboard_uid"
            fi
        done

        log_success "Grafana dashboards restored"
    fi

    log_success "Grafana restore completed"
}

restore_traefik() {
    log_info "Restoring Traefik..."

    if [ ! -d "$BACKUP_DIR/traefik" ]; then
        log_warn "No Traefik backup found in archive"
        return 1
    fi

    # Restore SSL certificates
    if [ -f "$BACKUP_DIR/traefik/acme.json" ]; then
        mkdir -p /opt/codespartan/platform/traefik/letsencrypt
        cp "$BACKUP_DIR/traefik/acme.json" /opt/codespartan/platform/traefik/letsencrypt/
        chmod 600 /opt/codespartan/platform/traefik/letsencrypt/acme.json
        log_success "SSL certificates restored"
    fi

    # Restore configs
    if ls "$BACKUP_DIR/traefik"/*.yml >/dev/null 2>&1; then
        cp "$BACKUP_DIR/traefik"/*.yml /opt/codespartan/platform/traefik/ 2>/dev/null || true
        log_success "Traefik configuration restored"
    fi

    # Restart Traefik
    cd /opt/codespartan/platform/traefik && docker compose restart

    log_success "Traefik restore completed"
}

restore_victoriametrics() {
    log_info "Restoring VictoriaMetrics..."

    if [ ! -d "$BACKUP_DIR/victoriametrics" ]; then
        log_warn "No VictoriaMetrics backup found in archive"
        return 1
    fi

    # Stop VictoriaMetrics
    docker stop victoriametrics || true

    # Find snapshot directory
    SNAPSHOT_DIR=$(find "$BACKUP_DIR/victoriametrics" -maxdepth 1 -type d | tail -1)

    if [ -n "$SNAPSHOT_DIR" ] && [ -d "$SNAPSHOT_DIR" ]; then
        # Copy snapshot to container
        docker cp "$SNAPSHOT_DIR" victoriametrics:/victoria-metrics-data/snapshots/

        # Start VictoriaMetrics
        docker start victoriametrics

        log_success "VictoriaMetrics restore completed"
    else
        log_warn "No VictoriaMetrics snapshot found"
        docker start victoriametrics
    fi
}

restore_configs() {
    log_info "Restoring configurations..."

    if [ ! -d "$BACKUP_DIR/configs" ]; then
        log_warn "No configuration backup found in archive"
        return 1
    fi

    # Restore all configs
    cp -r "$BACKUP_DIR/configs"/opt/codespartan/* /opt/codespartan/ 2>/dev/null || true

    log_success "Configurations restored"
}

restore_volumes() {
    log_info "Restoring Docker volumes..."

    if [ ! -d "$BACKUP_DIR/volumes" ]; then
        log_warn "No volume backups found in archive"
        return 1
    fi

    for volume_backup in "$BACKUP_DIR/volumes"/*.tar.gz; do
        if [ -f "$volume_backup" ]; then
            volume_name=$(basename "$volume_backup" .tar.gz)
            log_info "Restoring volume: $volume_name"

            # Create volume if it doesn't exist
            docker volume create "$volume_name" >/dev/null 2>&1 || true

            # Restore volume data
            docker run --rm \
                -v "${volume_name}:/target" \
                -v "$(dirname $volume_backup):/backup" \
                alpine \
                sh -c "cd /target && tar xzf /backup/$(basename $volume_backup)" \
                2>/dev/null || log_warn "Could not restore volume: $volume_name"
        fi
    done

    log_success "Docker volumes restored"
}

################################################################################
# EXECUTE RESTORE
################################################################################

case "$COMPONENT" in
    grafana)
        restore_grafana
        ;;
    traefik)
        restore_traefik
        ;;
    victoriametrics)
        restore_victoriametrics
        ;;
    configs)
        restore_configs
        ;;
    volumes)
        restore_volumes
        ;;
    all)
        restore_grafana
        restore_traefik
        restore_victoriametrics
        restore_configs
        restore_volumes
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        log_info "Valid components: grafana, traefik, victoriametrics, configs, volumes, all"
        rm -rf "$RESTORE_TMP"
        exit 1
        ;;
esac

################################################################################
# CLEANUP
################################################################################
log_info "Cleaning up temporary files..."
rm -rf "$RESTORE_TMP"

log_info "========================================="
log_success "Restore completed successfully!"
log_info "========================================="

exit 0
