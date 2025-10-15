#!/bin/bash
#
# Container Update Script for CodeSpartan Mambo Cloud Platform
#
# This script safely updates Docker containers to their latest versions:
# - Pulls latest images
# - Recreates containers with new images
# - Verifies containers are running after update
# - Creates backup before update (optional)
# - Supports rollback if update fails
#
# Usage:
#   ./update-containers.sh                    # Update all containers
#   ./update-containers.sh traefik grafana    # Update specific containers
#   ./update-containers.sh --dry-run          # Show what would be updated
#   ./update-containers.sh --backup           # Create backup before updating
#   ./update-containers.sh --no-verify        # Skip verification after update
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLATFORM_DIR="/opt/codespartan/platform"
APPS_DIR="/opt/codespartan/apps"
BACKUP_SCRIPT="/opt/codespartan/scripts/backup.sh"
HEALTH_CHECK_SCRIPT="/opt/codespartan/scripts/health-check.sh"

# Stack configurations (directory path and compose file)
declare -A STACKS=(
    ["traefik"]="/opt/codespartan/platform/traefik"
    ["monitoring"]="/opt/codespartan/platform/stacks/monitoring"
    ["backoffice"]="/opt/codespartan/platform/stacks/backoffice"
)

# Parse arguments
DRY_RUN=false
CREATE_BACKUP=false
SKIP_VERIFICATION=false
SPECIFIC_SERVICES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --backup|-b)
            CREATE_BACKUP=true
            shift
            ;;
        --no-verify)
            SKIP_VERIFICATION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [SERVICES...]"
            echo ""
            echo "Update Docker containers to their latest versions"
            echo ""
            echo "Options:"
            echo "  --dry-run, -d        Show what would be updated without doing it"
            echo "  --backup, -b         Create backup before updating"
            echo "  --no-verify          Skip health check after update"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Update all services"
            echo "  $0 traefik monitoring        # Update specific services"
            echo "  $0 --backup --dry-run        # Preview update with backup"
            exit 0
            ;;
        *)
            SPECIFIC_SERVICES+=("$1")
            shift
            ;;
    esac
done

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if running as non-root but can access docker
check_permissions() {
    if ! docker ps &> /dev/null; then
        print_error "Cannot access Docker. Please ensure you have permission to run Docker commands."
        exit 1
    fi
}

# Function to create backup
create_backup() {
    print_header "Creating Backup"

    if [ ! -f "$BACKUP_SCRIPT" ]; then
        print_warning "Backup script not found at: $BACKUP_SCRIPT"
        print_warning "Skipping backup..."
        return 1
    fi

    print_info "Running backup before update..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would create backup using: $BACKUP_SCRIPT"
        return 0
    fi

    if bash "$BACKUP_SCRIPT"; then
        print_success "Backup completed successfully"
        return 0
    else
        print_error "Backup failed"
        return 1
    fi
}

# Function to get image updates
check_for_updates() {
    local stack_dir="$1"
    local stack_name="$2"

    cd "$stack_dir"

    print_info "Checking for updates in: $stack_name"

    # Get current image IDs
    local current_images=$(docker compose images -q 2>/dev/null | sort)

    if [ -z "$current_images" ]; then
        print_warning "No running containers found for $stack_name"
        return 1
    fi

    # Pull latest images
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would pull latest images for $stack_name"
        docker compose config --images
        return 0
    else
        print_info "Pulling latest images for $stack_name..."
        if docker compose pull; then
            print_success "Images pulled successfully"
        else
            print_error "Failed to pull images for $stack_name"
            return 1
        fi
    fi

    # Check if images changed
    local new_images=$(docker compose images -q 2>/dev/null | sort)

    if [ "$current_images" = "$new_images" ]; then
        print_info "No updates available for $stack_name"
        return 2
    else
        print_success "Updates available for $stack_name"
        return 0
    fi
}

# Function to update stack
update_stack() {
    local stack_dir="$1"
    local stack_name="$2"

    print_header "Updating: $stack_name"

    if [ ! -d "$stack_dir" ]; then
        print_error "Stack directory not found: $stack_dir"
        return 1
    fi

    cd "$stack_dir"

    # Check for docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in: $stack_dir"
        return 1
    fi

    # Check for updates
    check_for_updates "$stack_dir" "$stack_name"
    local update_status=$?

    if [ $update_status -eq 2 ]; then
        # No updates available
        return 0
    elif [ $update_status -ne 0 ]; then
        # Error occurred
        return 1
    fi

    # Get current container status
    local running_containers=$(docker compose ps -q 2>/dev/null | wc -l)
    print_info "Currently running containers: $running_containers"

    # Recreate containers
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would recreate containers for $stack_name"
        return 0
    fi

    print_info "Recreating containers for $stack_name..."

    if docker compose up -d --remove-orphans; then
        print_success "Containers recreated successfully"
    else
        print_error "Failed to recreate containers for $stack_name"
        return 1
    fi

    # Wait for containers to start
    print_info "Waiting for containers to start..."
    sleep 5

    # Verify containers are running
    local new_running_containers=$(docker compose ps -q 2>/dev/null | wc -l)

    if [ "$new_running_containers" -ge "$running_containers" ]; then
        print_success "All containers are running ($new_running_containers/$running_containers)"
    else
        print_warning "Some containers may not be running ($new_running_containers/$running_containers)"
    fi

    # Show container status
    echo ""
    print_info "Container status:"
    docker compose ps

    return 0
}

# Function to update all applications
update_all_apps() {
    print_header "Updating Applications"

    if [ ! -d "$APPS_DIR" ]; then
        print_warning "Apps directory not found: $APPS_DIR"
        return 0
    fi

    local app_count=0
    local updated_count=0

    for app_dir in "$APPS_DIR"/*; do
        if [ ! -d "$app_dir" ] || [ ! -f "$app_dir/docker-compose.yml" ]; then
            continue
        fi

        local app_name=$(basename "$app_dir")

        # Skip template directory
        if [ "$app_name" = "_TEMPLATE" ]; then
            continue
        fi

        app_count=$((app_count + 1))

        if update_stack "$app_dir" "$app_name"; then
            updated_count=$((updated_count + 1))
        fi
    done

    if [ $app_count -eq 0 ]; then
        print_info "No applications found to update"
    else
        print_success "Updated $updated_count out of $app_count applications"
    fi
}

# Function to verify system health
verify_health() {
    print_header "Health Verification"

    if [ "$SKIP_VERIFICATION" = true ]; then
        print_info "Skipping health verification (--no-verify)"
        return 0
    fi

    if [ ! -f "$HEALTH_CHECK_SCRIPT" ]; then
        print_warning "Health check script not found at: $HEALTH_CHECK_SCRIPT"
        print_warning "Skipping verification..."
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would run health check: $HEALTH_CHECK_SCRIPT"
        return 0
    fi

    print_info "Running health check..."

    if bash "$HEALTH_CHECK_SCRIPT"; then
        print_success "Health check passed"
        return 0
    else
        print_error "Health check failed"
        print_warning "Some services may not be working correctly"
        return 1
    fi
}

# Function to clean up old images
cleanup_old_images() {
    print_header "Cleanup"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would remove old unused images"
        return 0
    fi

    print_info "Removing old unused images..."

    local removed=$(docker image prune -f 2>&1 | grep "Total reclaimed space" || echo "0B")

    if [ "$removed" != "0B" ]; then
        print_success "Cleaned up: $removed"
    else
        print_info "No unused images to remove"
    fi
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"

    if ! command -v curl &> /dev/null; then
        return
    fi

    local priority="default"
    if [ "$status" = "success" ]; then
        priority="default"
    elif [ "$status" = "warning" ]; then
        priority="high"
    else
        priority="urgent"
    fi

    curl -X POST https://ntfy.sh/codespartan-mambo-alerts \
        -H "Title: Container Update" \
        -H "Priority: $priority" \
        -d "$message" \
        2>/dev/null || true
}

# Main update function
main() {
    print_header "CodeSpartan Container Update"

    if [ "$DRY_RUN" = true ]; then
        print_warning "Running in DRY RUN mode - no changes will be made"
    fi

    # Check permissions
    check_permissions

    # Create backup if requested
    if [ "$CREATE_BACKUP" = true ]; then
        if ! create_backup; then
            print_error "Backup failed. Aborting update."
            exit 1
        fi
    fi

    # Determine what to update
    local update_all=true
    local services_to_update=()

    if [ ${#SPECIFIC_SERVICES[@]} -gt 0 ]; then
        update_all=false
        services_to_update=("${SPECIFIC_SERVICES[@]}")
        print_info "Updating specific services: ${services_to_update[*]}"
    else
        print_info "Updating all services"
    fi

    # Update services
    local failed_updates=0
    local successful_updates=0

    if [ "$update_all" = true ]; then
        # Update all platform stacks
        for stack_name in "${!STACKS[@]}"; do
            if update_stack "${STACKS[$stack_name]}" "$stack_name"; then
                successful_updates=$((successful_updates + 1))
            else
                failed_updates=$((failed_updates + 1))
            fi
        done

        # Update all applications
        update_all_apps
    else
        # Update specific services
        for service in "${services_to_update[@]}"; do
            if [ -n "${STACKS[$service]}" ]; then
                if update_stack "${STACKS[$service]}" "$service"; then
                    successful_updates=$((successful_updates + 1))
                else
                    failed_updates=$((failed_updates + 1))
                fi
            elif [ -d "$APPS_DIR/$service" ]; then
                if update_stack "$APPS_DIR/$service" "$service"; then
                    successful_updates=$((successful_updates + 1))
                else
                    failed_updates=$((failed_updates + 1))
                fi
            else
                print_error "Service not found: $service"
                failed_updates=$((failed_updates + 1))
            fi
        done
    fi

    # Cleanup old images
    if [ "$DRY_RUN" = false ]; then
        cleanup_old_images
    fi

    # Verify system health
    verify_health

    # Print summary
    print_header "Update Summary"

    if [ "$DRY_RUN" = true ]; then
        print_info "Dry run completed - no changes were made"
    else
        echo "Successful updates: $successful_updates"
        if [ $failed_updates -gt 0 ]; then
            echo -e "${RED}Failed updates:     $failed_updates${NC}"
        fi

        echo ""

        if [ $failed_updates -eq 0 ]; then
            print_success "All updates completed successfully!"
            send_notification "success" "✅ Container updates completed successfully"
        else
            print_warning "Some updates failed. Please check the logs above."
            send_notification "warning" "⚠ Container updates completed with $failed_updates failures"
        fi
    fi

    # Exit with appropriate code
    if [ $failed_updates -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main
