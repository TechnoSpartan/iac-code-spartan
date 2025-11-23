#!/bin/bash
#
# Fail2ban Emergency Unban Script
#
# This script allows you to unban an IP address from Fail2ban
# Use this if you accidentally get banned
#
# Usage:
#   sudo ./unban-ip.sh <IP_ADDRESS>
#   sudo ./unban-ip.sh all  # Unban all IPs
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Fail2ban Emergency Unban Tool${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0 <IP_ADDRESS>"
    exit 1
fi

# Check if Fail2ban is installed
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${RED}Error: Fail2ban is not installed${NC}"
    exit 1
fi

# Check if Fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
    echo -e "${YELLOW}Warning: Fail2ban service is not running${NC}"
    echo "Starting Fail2ban..."
    systemctl start fail2ban
    sleep 2
fi

# Get IP address from argument
IP_ADDRESS=$1

if [ -z "$IP_ADDRESS" ]; then
    echo -e "${RED}Error: IP address not provided${NC}"
    echo ""
    echo "Usage:"
    echo "  sudo $0 <IP_ADDRESS>    # Unban specific IP"
    echo "  sudo $0 all             # Unban all IPs from all jails"
    echo ""
    echo "Current banned IPs:"
    echo ""
    for jail in $(fail2ban-client status | grep "Jail list:" | sed 's/.*:\s*//' | tr ',' ' '); do
        echo -e "${BLUE}Jail: ${jail}${NC}"
        fail2ban-client get $jail banned 2>/dev/null || echo "  (none)"
        echo ""
    done
    exit 1
fi

# Unban all IPs
if [ "$IP_ADDRESS" = "all" ]; then
    echo -e "${YELLOW}Unbanning all IPs from all jails...${NC}"
    echo ""
    
    for jail in $(fail2ban-client status | grep "Jail list:" | sed 's/.*:\s*//' | tr ',' ' '); do
        echo -e "${BLUE}Processing jail: ${jail}${NC}"
        BANNED_IPS=$(fail2ban-client get $jail banned 2>/dev/null | tail -n +2 | awk '{print $NF}' || echo "")
        
        if [ -n "$BANNED_IPS" ]; then
            for ip in $BANNED_IPS; do
                echo -e "  Unbanning: ${ip}"
                fail2ban-client set $jail unbanip $ip 2>/dev/null || true
            done
            echo -e "${GREEN}✓ All IPs unbanned from ${jail}${NC}"
        else
            echo -e "  (no banned IPs)"
        fi
        echo ""
    done
    
    echo -e "${GREEN}✓ All IPs unbanned${NC}"
    exit 0
fi

# Validate IP address format (basic check)
if ! [[ $IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}Error: Invalid IP address format: ${IP_ADDRESS}${NC}"
    exit 1
fi

# Unban IP from all active jails
echo -e "${YELLOW}Unbanning IP: ${IP_ADDRESS}${NC}"
echo ""

UNBANNED=0
for jail in $(fail2ban-client status | grep "Jail list:" | sed 's/.*:\s*//' | tr ',' ' '); do
    # Check if IP is banned in this jail
    if fail2ban-client get $jail banned 2>/dev/null | grep -q "$IP_ADDRESS"; then
        echo -e "${BLUE}Unbanning from jail: ${jail}${NC}"
        if fail2ban-client set $jail unbanip $IP_ADDRESS 2>/dev/null; then
            echo -e "${GREEN}✓ IP ${IP_ADDRESS} unbanned from ${jail}${NC}"
            UNBANNED=1
        else
            echo -e "${RED}✗ Failed to unban from ${jail}${NC}"
        fi
    fi
done

if [ $UNBANNED -eq 0 ]; then
    echo -e "${YELLOW}⚠ IP ${IP_ADDRESS} was not found in any jail${NC}"
    echo "It may not be banned, or may have already been unbanned."
else
    echo ""
    echo -e "${GREEN}✓ IP ${IP_ADDRESS} has been unbanned${NC}"
    echo ""
    echo "You should now be able to connect via SSH."
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

