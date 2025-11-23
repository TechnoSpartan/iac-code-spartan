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

# Detect distribution and install Fail2ban
echo -e "${YELLOW}Detecting distribution...${NC}"
if [ -f /etc/redhat-release ]; then
    # AlmaLinux/RHEL/CentOS
    DISTRO="rhel"
    echo -e "${BLUE}Detected: RHEL-based (AlmaLinux/RHEL/CentOS)${NC}"
elif [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    DISTRO="debian"
    echo -e "${BLUE}Detected: Debian-based (Debian/Ubuntu)${NC}"
else
    echo -e "${RED}Error: Unsupported distribution${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing Fail2ban...${NC}"
if [ "$DISTRO" = "rhel" ]; then
    # Install EPEL repository if not present
    if ! rpm -q epel-release >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing EPEL repository...${NC}"
        dnf install -y epel-release
    fi
    dnf install -y fail2ban fail2ban-systemd
elif [ "$DISTRO" = "debian" ]; then
    apt-get update -qq
    apt-get install -y fail2ban
fi

echo -e "${GREEN}✓ Fail2ban installed${NC}"
echo ""

# Create local configuration
echo -e "${YELLOW}Configuring Fail2ban...${NC}"

# Get current SSH client IP (if available)
CURRENT_IP=""
if [ -n "$SSH_CLIENT" ]; then
    CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
    echo -e "${BLUE}Detected current SSH client IP: ${CURRENT_IP}${NC}"
    echo -e "${YELLOW}This IP will be added to the whitelist${NC}"
fi

# Try to get public IP if SSH_CLIENT is not available
if [ -z "$CURRENT_IP" ]; then
    echo -e "${YELLOW}Trying to detect public IP...${NC}"
    CURRENT_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
    if [ -n "$CURRENT_IP" ]; then
        echo -e "${BLUE}Detected public IP: ${CURRENT_IP}${NC}"
    else
        echo -e "${YELLOW}⚠ Could not detect IP automatically${NC}"
        echo -e "${YELLOW}You can add your IP manually later to /etc/fail2ban/jail.local${NC}"
    fi
fi

# Build ignoreip list
IGNOREIP="127.0.0.1/8 ::1"
if [ -n "$CURRENT_IP" ]; then
    IGNOREIP="${IGNOREIP} ${CURRENT_IP}"
fi

# Create jail.local with SSH protection and whitelist
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban hosts for 10 minutes (increased from default for better protection)
bantime = 10m

# A host is banned if it has generated "maxretry" during the last "findtime"
findtime = 10m

# Number of failures before a host gets banned
maxretry = 5

# IPs to ignore (whitelist) - these will NEVER be banned
# Format: space-separated IPs or CIDR ranges
ignoreip = ${IGNOREIP}

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
# Whitelist applies to all jails by default, but can be overridden per jail
ignoreip = ${IGNOREIP}

# Optional: Protect against SSH DDoS
[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 10
findtime = 10m
bantime = 10m
ignoreip = ${IGNOREIP}
EOF

# Adjust logpath for RHEL-based systems if needed
if [ "$DISTRO" = "rhel" ]; then
    # RHEL-based systems use /var/log/secure instead of /var/log/auth.log
    # The %(sshd_log)s variable should handle this, but we verify
    echo -e "${YELLOW}Verifying SSH log location...${NC}"
    if [ -f /var/log/secure ]; then
        echo -e "${GREEN}✓ SSH logs found at /var/log/secure${NC}"
    else
        echo -e "${YELLOW}⚠ SSH logs not found at /var/log/secure, using default${NC}"
    fi
fi

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
if [ -n "$CURRENT_IP" ]; then
    echo -e "${GREEN}✓ Your current IP (${CURRENT_IP}) is in the whitelist and will NOT be banned${NC}"
else
    echo -e "${YELLOW}⚠ Could not detect your IP. Add it manually to /etc/fail2ban/jail.local${NC}"
fi
echo ""
echo "🚨 EMERGENCY - If you get banned accidentally:"
echo "  1. Use the emergency script: sudo /opt/codespartan/scripts/unban-ip.sh <YOUR_IP>"
echo "  2. Or unban all: sudo /opt/codespartan/scripts/unban-ip.sh all"
echo "  3. Or use GitHub Actions workflow: 'Fail2ban Emergency Unban'"
echo ""
