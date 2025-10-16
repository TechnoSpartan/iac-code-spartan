#!/bin/bash

################################################################################
# CodeSpartan Mambo Cloud - Setup Automated Backups
#
# Configures weekly automatic backups via cron
#
# Usage: sudo ./setup-cron.sh
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo"
   exit 1
fi

log_info "========================================="
log_info "Setting up automated backups"
log_info "========================================="

# Create backup directory
mkdir -p /opt/backups
chmod 755 /opt/backups

# Make scripts executable
chmod +x /opt/codespartan/platform/stacks/backups/backup.sh
chmod +x /opt/codespartan/platform/stacks/backups/restore.sh

log_success "Backup scripts are executable"

# Configure log rotation for backup logs
log_info "Configuring log rotation..."

cat > /etc/logrotate.d/codespartan-backups <<EOF
/var/log/codespartan-backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF

log_success "Log rotation configured"

# Add cron job (weekly on Sundays at 2 AM)
log_info "Configuring cron job (Sundays at 2:00 AM)..."

CRON_JOB="0 2 * * 0 /opt/codespartan/platform/stacks/backups/backup.sh >> /var/log/codespartan-backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    log_warn "Cron job already exists, skipping"
else
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    log_success "Cron job added"
fi

# Display current crontab
log_info "Current backup schedule:"
crontab -l | grep backup.sh || echo "No backup jobs found"

# Create initial backup
log_info ""
read -p "Do you want to create an initial backup now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Creating initial backup..."
    /opt/codespartan/platform/stacks/backups/backup.sh
fi

log_info "========================================="
log_success "Automated backups configured successfully!"
log_info ""
log_info "Backup schedule: Sundays at 2:00 AM"
log_info "Backup location: /opt/backups"
log_info "Backup logs: /var/log/codespartan-backup.log"
log_info "Retention: Last 7 backups"
log_info ""
log_info "Commands:"
log_info "  - Manual backup:  sudo /opt/codespartan/platform/stacks/backups/backup.sh"
log_info "  - List backups:   ls -lh /opt/backups/"
log_info "  - Restore backup: sudo /opt/codespartan/platform/stacks/backups/restore.sh <backup-file>"
log_info "  - View cron jobs: crontab -l"
log_info "========================================="

exit 0
