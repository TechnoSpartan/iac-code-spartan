#!/bin/bash
#
# System Cleanup Script for CodeSpartan Mambo Cloud Platform
#
# This script performs maintenance cleanup tasks:
# - Removes unused Docker images, containers, volumes, and networks
# - Cleans old log files
# - Removes old local backups (keeps last 7 days)
# - Displays disk space before and after cleanup
#
# Usage:
#   ./cleanup.sh              # Interactive mode (asks for confirmation)
#   ./cleanup.sh --force      # Non-interactive mode (auto-confirm)
#   ./cleanup.sh --dry-run    # Show what would be cleaned without doing it
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/opt/codespartan/backups"
BACKUP_RETENTION_DAYS=7
LOG_DIR="/var/log"
LOG_RETENTION_DAYS=30

# Parse arguments
FORCE_MODE=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f      Skip confirmation prompts"
            echo "  --dry-run, -d    Show what would be cleaned without doing it"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
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

# Function to ask for confirmation
confirm() {
    if [ "$FORCE_MODE" = true ]; then
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        return 1
    fi

    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" -n 1 -r
    echo

    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Function to show disk space
show_disk_space() {
    echo -e "${BLUE}Disk Space:${NC}"
    df -h / | tail -n 1 | awk '{printf "  Used: %s / %s (%s)\n", $3, $2, $5}'
    echo ""
}

# Function to clean Docker resources
clean_docker() {
    print_header "Docker Cleanup"

    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Skipping Docker cleanup."
        return 1
    fi

    # Show current Docker disk usage
    print_info "Current Docker disk usage:"
    docker system df
    echo ""

    # Clean stopped containers
    local stopped_containers=$(docker ps -aq -f status=exited -f status=dead 2>/dev/null | wc -l)
    if [ "$stopped_containers" -gt 0 ]; then
        print_info "Found $stopped_containers stopped container(s)"
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would remove stopped containers"
        elif confirm "Remove stopped containers?"; then
            docker container prune -f
            print_success "Removed stopped containers"
        fi
    else
        print_success "No stopped containers to remove"
    fi

    # Clean dangling images
    local dangling_images=$(docker images -f dangling=true -q 2>/dev/null | wc -l)
    if [ "$dangling_images" -gt 0 ]; then
        print_info "Found $dangling_images dangling image(s)"
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would remove dangling images"
        elif confirm "Remove dangling images?"; then
            docker image prune -f
            print_success "Removed dangling images"
        fi
    else
        print_success "No dangling images to remove"
    fi

    # Clean unused images (more aggressive)
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would check for unused images"
    elif confirm "Remove ALL unused images (not just dangling)?"; then
        print_warning "This will remove all images not used by any container"
        if confirm "Are you sure?" "n"; then
            docker image prune -af
            print_success "Removed unused images"
        fi
    fi

    # Clean unused volumes
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would check for unused volumes"
    elif confirm "Remove unused volumes?"; then
        print_warning "This will remove volumes not used by any container"
        if confirm "Are you sure?" "n"; then
            docker volume prune -f
            print_success "Removed unused volumes"
        fi
    fi

    # Clean unused networks
    local unused_networks=$(docker network ls -f type=custom -q 2>/dev/null | wc -l)
    if [ "$unused_networks" -gt 0 ]; then
        print_info "Found custom networks"
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would remove unused networks"
        elif confirm "Remove unused networks?"; then
            docker network prune -f
            print_success "Removed unused networks"
        fi
    fi

    # Clean build cache
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would check build cache"
    elif confirm "Remove Docker build cache?"; then
        docker builder prune -f
        print_success "Removed build cache"
    fi

    echo ""
    print_info "Docker disk usage after cleanup:"
    docker system df
}

# Function to clean old backups
clean_old_backups() {
    print_header "Backup Cleanup"

    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "Backup directory not found: $BACKUP_DIR"
        return 0
    fi

    print_info "Cleaning backups older than $BACKUP_RETENTION_DAYS days from: $BACKUP_DIR"

    # Find old backup files
    local old_backups=$(find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f -mtime +"$BACKUP_RETENTION_DAYS" 2>/dev/null)
    local count=$(echo "$old_backups" | grep -c "backup-" || true)

    if [ -n "$old_backups" ] && [ "$count" -gt 0 ]; then
        print_info "Found $count old backup file(s):"
        echo "$old_backups" | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t "%Y-%m-%d" "$file" 2>/dev/null)
            echo "  - $(basename "$file") ($size, $date)"
        done

        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would remove old backups"
        elif confirm "Remove these old backups?"; then
            echo "$old_backups" | xargs rm -f
            print_success "Removed old backups"
        fi
    else
        print_success "No old backups to remove"
    fi
}

# Function to clean old log files
clean_old_logs() {
    print_header "Log File Cleanup"

    if [ ! -d "$LOG_DIR" ]; then
        print_info "Log directory not found: $LOG_DIR"
        return 0
    fi

    print_info "Cleaning log files older than $LOG_RETENTION_DAYS days from: $LOG_DIR"

    # Find old log files
    local old_logs=$(find "$LOG_DIR" -name "*.log.*" -type f -mtime +"$LOG_RETENTION_DAYS" 2>/dev/null || true)
    local count=$(echo "$old_logs" | grep -c ".log." || echo "0")

    if [ -n "$old_logs" ] && [ "$count" -gt 0 ]; then
        print_info "Found $count old log file(s)"

        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would remove old log files"
        elif confirm "Remove old log files?"; then
            echo "$old_logs" | xargs rm -f 2>/dev/null || true
            print_success "Removed old log files"
        fi
    else
        print_success "No old log files to remove"
    fi

    # Clean journalctl logs if systemd is available
    if command -v journalctl &> /dev/null; then
        print_info "Cleaning systemd journal logs older than 30 days"
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would vacuum journal logs"
        elif confirm "Vacuum systemd journal logs?"; then
            sudo journalctl --vacuum-time=30d
            print_success "Vacuumed journal logs"
        fi
    fi
}

# Function to clean APT cache (Debian/Ubuntu)
clean_apt_cache() {
    print_header "APT Cache Cleanup"

    if ! command -v apt-get &> /dev/null; then
        print_info "APT not found. Skipping APT cleanup."
        return 0
    fi

    print_info "Current APT cache size:"
    du -sh /var/cache/apt/archives 2>/dev/null || echo "  N/A"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would clean APT cache"
    elif confirm "Clean APT cache?"; then
        sudo apt-get clean
        sudo apt-get autoclean
        sudo apt-get autoremove -y
        print_success "Cleaned APT cache"
    fi
}

# Function to clean temporary files
clean_temp_files() {
    print_header "Temporary Files Cleanup"

    local temp_dirs=("/tmp" "/var/tmp")

    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_info "Cleaning files older than 7 days in: $dir"
            local old_files=$(find "$dir" -type f -atime +7 2>/dev/null | wc -l)

            if [ "$old_files" -gt 0 ]; then
                print_info "Found $old_files old temporary file(s)"
                if [ "$DRY_RUN" = true ]; then
                    print_info "[DRY RUN] Would remove old temporary files from $dir"
                elif confirm "Remove old files from $dir?"; then
                    sudo find "$dir" -type f -atime +7 -delete 2>/dev/null || true
                    print_success "Removed old temporary files from $dir"
                fi
            else
                print_success "No old temporary files in $dir"
            fi
        fi
    done
}

# Main cleanup function
main() {
    print_header "CodeSpartan System Cleanup"

    if [ "$DRY_RUN" = true ]; then
        print_warning "Running in DRY RUN mode - no changes will be made"
    fi

    if [ "$FORCE_MODE" = true ]; then
        print_warning "Running in FORCE mode - skipping confirmations"
    fi

    # Show initial disk space
    print_info "Disk space before cleanup:"
    show_disk_space

    # Perform cleanup tasks
    clean_docker
    clean_old_backups
    clean_old_logs
    clean_apt_cache
    clean_temp_files

    # Show final disk space
    print_header "Cleanup Complete"
    print_info "Disk space after cleanup:"
    show_disk_space

    if [ "$DRY_RUN" = false ]; then
        print_success "System cleanup completed successfully!"

        # Send notification if ntfy is configured
        if command -v curl &> /dev/null; then
            curl -X POST https://ntfy.sh/codespartan-mambo-alerts \
                -H "Title: System Cleanup" \
                -H "Priority: low" \
                -d "✅ System cleanup completed successfully" \
                2>/dev/null || true
        fi
    else
        print_info "Dry run completed - no changes were made"
    fi
}

# Run main function
main
