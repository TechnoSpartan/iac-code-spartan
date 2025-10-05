#!/bin/bash

###############################################################################
# CodeSpartan Mambo Cloud Platform - Restore Script
###############################################################################
#
# Restores backup created by backup.sh
#
# Usage:
#   ./restore.sh <backup-file.tar.gz> [--volumes-only|--configs-only|--full]
#
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
PLATFORM_DIR="/opt/codespartan/platform"
RESTORE_MODE="${2:-full}"  # full, volumes-only, configs-only

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Check arguments
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <backup-file.tar.gz> [--volumes-only|--configs-only|--full]"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [[ ! -f "${BACKUP_FILE}" ]]; then
    error "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

log "Starting restore process..."
log "Backup file: ${BACKUP_FILE}"
log "Restore mode: ${RESTORE_MODE}"
log ""

# Warning prompt
warn "⚠️  WARNING: This will overwrite existing data!"
warn "⚠️  Make sure you have a backup of current state before proceeding."
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log "Restore cancelled by user"
    exit 0
fi

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

log "Extracting backup to temporary directory..."
tar xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Show backup info
if [[ -f "${TEMP_DIR}/backup-info.txt" ]]; then
    info "Backup Information:"
    cat "${TEMP_DIR}/backup-info.txt" | sed 's/^/  /'
    echo ""
fi

###############################################################################
# 1. Restore Docker Volumes
###############################################################################

if [[ "${RESTORE_MODE}" == "full" ]] || [[ "${RESTORE_MODE}" == "--volumes-only" ]]; then
    log "Restoring Docker volumes..."

    VOLUMES_DIR="${TEMP_DIR}/volumes"

    if [[ -d "${VOLUMES_DIR}" ]]; then
        for volume_dir in "${VOLUMES_DIR}"/*; do
            if [[ -d "${volume_dir}" ]]; then
                volume_name=$(basename "${volume_dir}")
                volume_archive="${volume_dir}/data.tar.gz"

                if [[ -f "${volume_archive}" ]]; then
                    log "  - Restoring volume: ${volume_name}"

                    # Stop containers using this volume
                    log "    • Stopping containers using ${volume_name}..."
                    containers=$(docker ps -q --filter "volume=${volume_name}")
                    if [[ -n "${containers}" ]]; then
                        docker stop ${containers} || true
                    fi

                    # Create volume if it doesn't exist
                    if ! docker volume inspect "${volume_name}" &> /dev/null; then
                        log "    • Creating volume: ${volume_name}"
                        docker volume create "${volume_name}"
                    fi

                    # Restore volume data
                    log "    • Restoring data to ${volume_name}..."
                    docker run --rm \
                        -v "${volume_name}:/data" \
                        -v "${volume_dir}:/backup:ro" \
                        alpine:latest \
                        sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null || true && tar xzf /backup/data.tar.gz -C /data"

                    log "    ✓ Volume ${volume_name} restored"
                else
                    warn "    • Archive not found for volume: ${volume_name}"
                fi
            fi
        done
    else
        warn "No volumes found in backup"
    fi
fi

###############################################################################
# 2. Restore Configuration Files
###############################################################################

if [[ "${RESTORE_MODE}" == "full" ]] || [[ "${RESTORE_MODE}" == "--configs-only" ]]; then
    log "Restoring configuration files..."

    PLATFORM_BACKUP="${TEMP_DIR}/platform"

    if [[ -d "${PLATFORM_BACKUP}" ]]; then
        log "  - Stopping all services..."
        cd "${PLATFORM_DIR}" && find . -name "docker-compose.yml" -execdir docker compose down \; 2>/dev/null || true

        log "  - Backing up current configs to ${PLATFORM_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        cp -r "${PLATFORM_DIR}" "${PLATFORM_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

        log "  - Restoring platform configuration files..."
        rsync -a --delete "${PLATFORM_BACKUP}/" "${PLATFORM_DIR}/"

        log "    ✓ Configuration files restored"
    else
        warn "No platform configs found in backup"
    fi
fi

###############################################################################
# 3. Restore SSL Certificates
###############################################################################

if [[ "${RESTORE_MODE}" == "full" ]] || [[ "${RESTORE_MODE}" == "--configs-only" ]]; then
    log "Restoring SSL certificates..."

    SSL_BACKUP="${TEMP_DIR}/ssl/letsencrypt"
    TRAEFIK_CERTS="${PLATFORM_DIR}/traefik/letsencrypt"

    if [[ -d "${SSL_BACKUP}" ]]; then
        log "  - Restoring Traefik Let's Encrypt certificates..."
        mkdir -p "$(dirname "${TRAEFIK_CERTS}")"
        rsync -a --delete "${SSL_BACKUP}/" "${TRAEFIK_CERTS}/"

        # Fix permissions for acme.json
        if [[ -f "${TRAEFIK_CERTS}/acme.json" ]]; then
            chmod 600 "${TRAEFIK_CERTS}/acme.json"
        fi

        log "    ✓ SSL certificates restored"
    else
        warn "No SSL certificates found in backup"
    fi
fi

###############################################################################
# 4. Restart Services
###############################################################################

if [[ "${RESTORE_MODE}" == "full" ]]; then
    log "Restarting all services..."

    # Start Traefik first
    if [[ -f "${PLATFORM_DIR}/traefik/docker-compose.yml" ]]; then
        log "  - Starting Traefik..."
        cd "${PLATFORM_DIR}/traefik" && docker compose up -d
        sleep 5
    fi

    # Start monitoring stack
    if [[ -f "${PLATFORM_DIR}/stacks/monitoring/docker-compose.yml" ]]; then
        log "  - Starting monitoring stack..."
        cd "${PLATFORM_DIR}/stacks/monitoring" && docker compose up -d
        sleep 5
    fi

    # Start other services
    log "  - Starting remaining services..."
    cd "${PLATFORM_DIR}" && find ./stacks -name "docker-compose.yml" -not -path "*/monitoring/*" -execdir docker compose up -d \; 2>/dev/null || true

    log "    ✓ All services restarted"
fi

###############################################################################
# 5. Summary
###############################################################################

log ""
log "Restore completed successfully!"
log ""
log "Summary:"
log "  - Backup file: ${BACKUP_FILE}"
log "  - Restore mode: ${RESTORE_MODE}"
log ""

if [[ "${RESTORE_MODE}" == "full" ]]; then
    log "Next steps:"
    log "  1. Verify services are running: docker ps"
    log "  2. Check Traefik dashboard: https://traefik.mambo-cloud.com"
    log "  3. Check Grafana: https://grafana.mambo-cloud.com"
    log "  4. Review logs: docker compose logs -f"
fi

log ""
log "✅ Restore process complete!"

exit 0
