#!/bin/bash

###############################################################################
# CodeSpartan Mambo Cloud Platform - Enable Hetzner Automated Backups
###############################################################################
#
# This script enables Hetzner Cloud's automated backup feature for the VPS.
#
# Hetzner Automated Backups:
# - Creates up to 7 backups of your server
# - Backups are created automatically while the server is running
# - Stored in Hetzner's infrastructure (separate from VPS)
# - Can be used to create new servers or restore
# - Cost: 20% of server price
#
# Usage:
#   HCLOUD_TOKEN=your-token ./enable-hetzner-backups.sh <server-id>
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"
SERVER_ID="${1:-}"

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

# Check if API token is provided
if [[ -z "${HCLOUD_TOKEN}" ]]; then
    error "HCLOUD_TOKEN environment variable not set"
    echo ""
    echo "Usage:"
    echo "  HCLOUD_TOKEN=your-token $0 <server-id>"
    echo ""
    echo "Get your token from: https://console.hetzner.cloud → Security → API Tokens"
    exit 1
fi

# Check if server ID is provided
if [[ -z "${SERVER_ID}" ]]; then
    # Try to find server automatically
    log "No server ID provided, searching for CodeSpartan VPS..."

    SERVERS=$(curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/servers")

    SERVER_ID=$(echo "${SERVERS}" | jq -r '.servers[] | select(.name | contains("codespartan")) | .id' | head -1)

    if [[ -z "${SERVER_ID}" ]]; then
        error "Could not find CodeSpartan VPS automatically"
        echo ""
        echo "Available servers:"
        echo "${SERVERS}" | jq -r '.servers[] | "  ID: \(.id) - \(.name) (\(.server_type.name)) - \(.public_net.ipv4.ip)"'
        echo ""
        echo "Usage: $0 <server-id>"
        exit 1
    fi

    log "Found server: ID ${SERVER_ID}"
fi

# Get server details
log "Fetching server details..."

SERVER_DETAILS=$(curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
    "https://api.hetzner.cloud/v1/servers/${SERVER_ID}")

SERVER_NAME=$(echo "${SERVER_DETAILS}" | jq -r '.server.name')
SERVER_IP=$(echo "${SERVER_DETAILS}" | jq -r '.server.public_net.ipv4.ip')
SERVER_TYPE=$(echo "${SERVER_DETAILS}" | jq -r '.server.server_type.name')
BACKUP_ENABLED=$(echo "${SERVER_DETAILS}" | jq -r '.server.backup_window')

info "Server Details:"
echo "  Name: ${SERVER_NAME}"
echo "  IP: ${SERVER_IP}"
echo "  Type: ${SERVER_TYPE}"
echo "  Backup Status: $(if [[ "${BACKUP_ENABLED}" != "null" ]]; then echo "ENABLED (Window: ${BACKUP_ENABLED})"; else echo "DISABLED"; fi)"
echo ""

# Check if backups already enabled
if [[ "${BACKUP_ENABLED}" != "null" ]]; then
    warn "Automated backups are already enabled for this server!"
    echo ""
    info "Backup Window: ${BACKUP_ENABLED}"
    echo ""
    read -p "Do you want to disable backups instead? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Disabling automated backups..."

        RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
            "https://api.hetzner.cloud/v1/servers/${SERVER_ID}/actions/disable_backup")

        ACTION_ID=$(echo "${RESPONSE}" | jq -r '.action.id')

        if [[ "${ACTION_ID}" != "null" ]]; then
            log "✅ Backup disabling initiated (Action ID: ${ACTION_ID})"
            exit 0
        else
            error "Failed to disable backups"
            echo "${RESPONSE}" | jq .
            exit 1
        fi
    else
        log "No changes made."
        exit 0
    fi
fi

# Confirm enabling backups
warn "Enabling automated backups will incur additional cost: 20% of server price"
echo ""
info "Estimated cost for ${SERVER_TYPE}:"

# Calculate cost (approximate)
case "${SERVER_TYPE}" in
    cax11)
        BASE_COST="€4.90"
        BACKUP_COST="€0.98"
        ;;
    cax21)
        BASE_COST="€9.90"
        BACKUP_COST="€1.98"
        ;;
    cax31)
        BASE_COST="€19.90"
        BACKUP_COST="€3.98"
        ;;
    *)
        BASE_COST="unknown"
        BACKUP_COST="unknown"
        ;;
esac

echo "  Server cost: ${BASE_COST}/month"
echo "  Backup cost: ${BACKUP_COST}/month"
echo ""

read -p "Do you want to enable automated backups? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log "Backup enabling cancelled by user"
    exit 0
fi

# Enable automated backups
log "Enabling automated backups for server ${SERVER_NAME} (ID: ${SERVER_ID})..."

RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
    "https://api.hetzner.cloud/v1/servers/${SERVER_ID}/actions/enable_backup")

ACTION_ID=$(echo "${RESPONSE}" | jq -r '.action.id')

if [[ "${ACTION_ID}" != "null" ]] && [[ "${ACTION_ID}" != "" ]]; then
    log "✅ Automated backups enabled successfully!"
    log "Action ID: ${ACTION_ID}"
    echo ""
    info "Backup Details:"
    echo "  - Backups will be created automatically"
    echo "  - Up to 7 backups retained"
    echo "  - Backups stored in Hetzner infrastructure"
    echo "  - Can be used for server recovery"
    echo ""
    info "To view backups:"
    echo "  1. Visit: https://console.hetzner.cloud"
    echo "  2. Go to: Servers → ${SERVER_NAME} → Backups tab"
    echo ""
    info "To restore from backup:"
    echo "  1. Hetzner Console → Servers → ${SERVER_NAME} → Backups"
    echo "  2. Select backup → Restore"
    echo "  OR create new server from backup image"
else
    error "Failed to enable automated backups"
    echo ""
    echo "Response:"
    echo "${RESPONSE}" | jq .
    exit 1
fi

exit 0
