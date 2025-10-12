#!/bin/bash
#
# Fail2ban Installation and Configuration Script
#
# This script installs and configures Fail2ban to protect against brute-force attacks
# - Protects SSH with custom jail
# - Bans after 5 failed attempts
# - Ban duration: 10 minutes
# - Monitoring window: 10 minutes
#
# Usage:
#   sudo ./install-fail2ban.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Fail2ban Installation & Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Install Fail2ban
echo -e "${YELLOW}Installing Fail2ban...${NC}"
apt-get update -qq
apt-get install -y fail2ban

echo -e "${GREEN}✓ Fail2ban installed${NC}"
echo ""

# Create local configuration
echo -e "${YELLOW}Configuring Fail2ban...${NC}"

# Create jail.local with SSH protection
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 10 minutes
bantime = 10m

# A host is banned if it has generated "maxretry" during the last "findtime"
findtime = 10m

# Number of failures before a host gets banned
maxretry = 5

# Destination email for notifications (optional)
# destemail = admin@mambo-cloud.com

# Sender email (optional)
# sender = fail2ban@mambo-cloud.com

# Action to take when banning (ban + optional email)
action = %(action_)s
# For email notifications, use: %(action_mw)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 5
bantime = 10m
findtime = 10m

# Optional: Protect against SSH DDoS
[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 10
findtime = 10m
bantime = 10m
EOF

echo -e "${GREEN}✓ Configuration created at /etc/fail2ban/jail.local${NC}"
echo ""

# Enable and start Fail2ban
echo -e "${YELLOW}Starting Fail2ban service...${NC}"
systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${GREEN}✓ Fail2ban service started${NC}"
echo ""

# Wait for service to start
sleep 2

# Check status
echo -e "${YELLOW}Checking Fail2ban status...${NC}"
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}✓ Fail2ban is running${NC}"

    # Show jail status
    echo ""
    echo -e "${BLUE}Active Jails:${NC}"
    fail2ban-client status

    echo ""
    echo -e "${BLUE}SSH Jail Details:${NC}"
    fail2ban-client status sshd || true
else
    echo -e "${RED}✗ Fail2ban failed to start${NC}"
    echo "Check logs: journalctl -u fail2ban -n 50"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Fail2ban Installation Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Configuration:"
echo "  - Max retries: 5 attempts"
echo "  - Find time: 10 minutes"
echo "  - Ban time: 10 minutes"
echo "  - Protected service: SSH (port 22)"
echo ""
echo "Useful commands:"
echo "  - Check status:        sudo fail2ban-client status"
echo "  - Check SSH jail:      sudo fail2ban-client status sshd"
echo "  - Unban IP:            sudo fail2ban-client set sshd unbanip <IP>"
echo "  - Show banned IPs:     sudo fail2ban-client get sshd banned"
echo "  - View logs:           sudo tail -f /var/log/fail2ban.log"
echo ""
