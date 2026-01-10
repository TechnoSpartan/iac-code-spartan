#!/bin/bash
#
# Blue/Green Deployment Script
# Usage: ./deploy.sh <app-name> <image> [compose-file]
#
# Example: ./deploy.sh cyberdyne-frontend ghcr.io/technospartan/ft-rc-bko-trackworks:latest
#
set -euo pipefail

APP_NAME="${1:-}"
IMAGE="${2:-}"
COMPOSE_FILE="${3:-docker-compose.yml}"
HEALTH_TIMEOUT=120
HEALTH_INTERVAL=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ -z "$APP_NAME" || -z "$IMAGE" ]]; then
    echo "Usage: $0 <app-name> <image> [compose-file]"
    echo "Example: $0 cyberdyne-frontend ghcr.io/org/app:latest"
    exit 1
fi

BLUE_CONTAINER="${APP_NAME}-blue"
GREEN_CONTAINER="${APP_NAME}-green"

# Determine which slot is currently active
get_active_slot() {
    if docker ps --format '{{.Names}}' | grep -q "^${BLUE_CONTAINER}$"; then
        echo "blue"
    elif docker ps --format '{{.Names}}' | grep -q "^${GREEN_CONTAINER}$"; then
        echo "green"
    else
        echo "none"
    fi
}

# Get the inactive slot
get_inactive_slot() {
    local active=$(get_active_slot)
    if [[ "$active" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Wait for container to be healthy
wait_for_healthy() {
    local container=$1
    local elapsed=0

    log_info "Waiting for $container to be healthy..."

    while [[ $elapsed -lt $HEALTH_TIMEOUT ]]; do
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not-found")

        if [[ "$status" == "healthy" ]]; then
            log_success "$container is healthy!"
            return 0
        fi

        echo -n "."
        sleep $HEALTH_INTERVAL
        elapsed=$((elapsed + HEALTH_INTERVAL))
    done

    echo ""
    log_error "$container failed to become healthy within ${HEALTH_TIMEOUT}s"
    return 1
}

# Main deployment logic
main() {
    local active_slot=$(get_active_slot)
    local target_slot=$(get_inactive_slot)
    local target_container="${APP_NAME}-${target_slot}"
    local active_container="${APP_NAME}-${active_slot}"

    log_info "=== Blue/Green Deployment ==="
    log_info "App: $APP_NAME"
    log_info "Image: $IMAGE"
    log_info "Active slot: $active_slot"
    log_info "Target slot: $target_slot"
    echo ""

    # Step 1: Pull new image
    log_info "Step 1: Pulling new image..."
    docker pull "$IMAGE"
    log_success "Image pulled"

    # Step 2: Stop old target container if exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${target_container}$"; then
        log_info "Step 2: Removing old $target_slot container..."
        docker rm -f "$target_container" 2>/dev/null || true
    fi

    # Step 3: Start new container in target slot
    log_info "Step 3: Starting $target_container..."

    # Generate dynamic compose with the target slot
    docker run -d \
        --name "$target_container" \
        --restart unless-stopped \
        --network web \
        --health-cmd "curl --fail --silent http://localhost:80/ || exit 1" \
        --health-interval 10s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.${APP_NAME}.rule=Host(\`www.cyberdyne-systems.es\`)" \
        --label "traefik.http.routers.${APP_NAME}.entrypoints=websecure" \
        --label "traefik.http.routers.${APP_NAME}.tls=true" \
        --label "traefik.http.routers.${APP_NAME}.tls.certresolver=le" \
        --label "traefik.http.services.${APP_NAME}.loadbalancer.server.port=80" \
        --label "traefik.docker.network=web" \
        --label "deployment.slot=${target_slot}" \
        "$IMAGE"

    log_success "$target_container started"

    # Step 4: Wait for health check
    log_info "Step 4: Waiting for health check..."
    if ! wait_for_healthy "$target_container"; then
        log_error "Deployment failed - rolling back"
        docker rm -f "$target_container" 2>/dev/null || true
        exit 1
    fi

    # Step 5: Stop old container (Traefik will automatically route to the new one)
    if [[ "$active_slot" != "none" ]]; then
        log_info "Step 5: Stopping old $active_slot container..."
        docker rm -f "$active_container" 2>/dev/null || true
        log_success "Old container removed"
    fi

    # Step 6: Cleanup
    log_info "Step 6: Cleaning up old images..."
    docker image prune -f > /dev/null 2>&1 || true

    echo ""
    log_success "=== Deployment Complete ==="
    log_info "Active container: $target_container"
    docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
}

main
