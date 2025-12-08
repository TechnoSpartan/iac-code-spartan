#!/bin/bash
#
# Fail2ban Verification Script
#
# This script performs a comprehensive verification of Fail2ban installation,
# configuration, and functionality.
#
# Usage:
#   sudo ./verify-fail2ban.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Fail2ban Comprehensive Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

EXIT_CODE=0

# 1. Check if Fail2ban is installed
echo -e "${YELLOW}[1/10] Checking Fail2ban installation...${NC}"
if command -v fail2ban-client >/dev/null 2>&1; then
    VERSION=$(fail2ban-client version | head -1)
    echo -e "${GREEN}✓ Fail2ban is installed: ${VERSION}${NC}"
else
    echo -e "${RED}✗ Fail2ban is not installed${NC}"
    EXIT_CODE=1
fi
echo ""

# 2. Check if Fail2ban service is running
echo -e "${YELLOW}[2/10] Checking Fail2ban service status...${NC}"
if systemctl is-active --quiet fail2ban; then
    UPTIME=$(systemctl show fail2ban --property=ActiveEnterTimestamp --value)
    echo -e "${GREEN}✓ Fail2ban service is running${NC}"
    echo -e "   Started: ${UPTIME}"
else
    echo -e "${RED}✗ Fail2ban service is not running${NC}"
    EXIT_CODE=1
fi
echo ""

# 3. Check if FirewallD is running (needed for ban action)
echo -e "${YELLOW}[3/10] Checking FirewallD status...${NC}"
if systemctl is-active --quiet firewalld; then
    echo -e "${GREEN}✓ FirewallD is running${NC}"
else
    echo -e "${RED}✗ FirewallD is NOT running${NC}"
    echo -e "${YELLOW}   Warning: Fail2ban needs FirewallD to ban IPs${NC}"
    echo -e "${YELLOW}   Fix: sudo systemctl start firewalld${NC}"
    EXIT_CODE=1
fi
echo ""

# 4. Check Fail2ban configuration
echo -e "${YELLOW}[4/10] Checking configuration files...${NC}"
if [ -f /etc/fail2ban/jail.local ]; then
    echo -e "${GREEN}✓ Custom configuration exists: /etc/fail2ban/jail.local${NC}"

    # Show key settings
    echo -e "${BLUE}   Configuration:${NC}"
    grep -E "^bantime|^findtime|^maxretry|^ignoreip" /etc/fail2ban/jail.local | head -4 | while read line; do
        echo -e "     $line"
    done
else
    echo -e "${YELLOW}⚠ No custom configuration found${NC}"
    echo -e "   Using default settings"
fi
echo ""

# 5. Check active jails
echo -e "${YELLOW}[5/10] Checking active jails...${NC}"
JAILS=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | xargs)
if [ -n "$JAILS" ]; then
    echo -e "${GREEN}✓ Active jails: ${JAILS}${NC}"
else
    echo -e "${RED}✗ No active jails found${NC}"
    EXIT_CODE=1
fi
echo ""

# 6. Check SSH jail details
echo -e "${YELLOW}[6/10] Checking SSH jail (sshd)...${NC}"
if fail2ban-client status sshd >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH jail is active${NC}"

    # Get jail statistics
    CURRENTLY_FAILED=$(fail2ban-client status sshd | grep "Currently failed" | awk '{print $NF}')
    CURRENTLY_BANNED=$(fail2ban-client status sshd | grep "Currently banned" | awk '{print $NF}')
    TOTAL_FAILED=$(fail2ban-client status sshd | grep "Total failed" | awk '{print $NF}')
    TOTAL_BANNED=$(fail2ban-client status sshd | grep "Total banned" | awk '{print $NF}')

    echo -e "${BLUE}   Statistics:${NC}"
    echo -e "     Currently failed: ${CURRENTLY_FAILED}"
    echo -e "     Currently banned: ${CURRENTLY_BANNED}"
    echo -e "     Total failed: ${TOTAL_FAILED}"
    echo -e "     Total banned: ${TOTAL_BANNED}"

    # Show banned IPs if any
    if [ "$CURRENTLY_BANNED" -gt 0 ]; then
        echo -e "${BLUE}   Banned IPs:${NC}"
        fail2ban-client status sshd | grep "Banned IP list" | cut -d: -f2 | xargs -n 1 | while read ip; do
            echo -e "     - ${ip}"
        done
    fi
else
    echo -e "${RED}✗ SSH jail is not active${NC}"
    EXIT_CODE=1
fi
echo ""

# 7. Check SSH DDoS jail
echo -e "${YELLOW}[7/10] Checking SSH DDoS jail (sshd-ddos)...${NC}"
if fail2ban-client status sshd-ddos >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH DDoS jail is active${NC}"
else
    echo -e "${YELLOW}⚠ SSH DDoS jail is not active (optional)${NC}"
fi
echo ""

# 8. Check recent logs for activity
echo -e "${YELLOW}[8/10] Checking recent activity (last 24 hours)...${NC}"
BAN_COUNT=$(journalctl -u fail2ban --since "24 hours ago" --no-pager | grep -c "Ban " || echo "0")
UNBAN_COUNT=$(journalctl -u fail2ban --since "24 hours ago" --no-pager | grep -c "Unban " || echo "0")

echo -e "${BLUE}   Last 24 hours:${NC}"
echo -e "     Bans: ${BAN_COUNT}"
echo -e "     Unbans: ${UNBAN_COUNT}"

if [ "$BAN_COUNT" -gt 0 ]; then
    echo -e "${BLUE}   Recent bans:${NC}"
    journalctl -u fail2ban --since "24 hours ago" --no-pager | grep "Ban " | tail -5 | while read line; do
        echo -e "     ${line}"
    done
fi
echo ""

# 9. Check fail2ban-exporter container
echo -e "${YELLOW}[9/10] Checking fail2ban-exporter container...${NC}"
if docker ps | grep -q fail2ban-exporter; then
    if docker ps | grep -q "fail2ban-exporter.*healthy"; then
        echo -e "${GREEN}✓ fail2ban-exporter is running and healthy${NC}"

        # Try to get metrics
        METRICS=$(docker exec fail2ban-exporter wget -q -O- http://localhost:9921/metrics 2>&1 | head -5)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Metrics endpoint is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Could not fetch metrics from exporter${NC}"
            echo -e "${BLUE}   Exporter logs:${NC}"
            docker logs fail2ban-exporter --tail 10 | while read line; do
                echo -e "     ${line}"
            done
        fi
    else
        echo -e "${YELLOW}⚠ fail2ban-exporter is running but not healthy${NC}"
        EXIT_CODE=1
    fi
else
    echo -e "${RED}✗ fail2ban-exporter container is not running${NC}"
    EXIT_CODE=1
fi
echo ""

# 10. Check firewall rules
echo -e "${YELLOW}[10/10] Checking firewall rules...${NC}"
if systemctl is-active --quiet firewalld; then
    RICH_RULES_COUNT=$(firewall-cmd --list-rich-rules 2>/dev/null | wc -l)
    echo -e "${BLUE}   Active rich rules: ${RICH_RULES_COUNT}${NC}"

    if [ "$RICH_RULES_COUNT" -gt 0 ]; then
        echo -e "${BLUE}   Sample rules:${NC}"
        firewall-cmd --list-rich-rules 2>/dev/null | head -3 | while read rule; do
            echo -e "     ${rule}"
        done
    fi
else
    echo -e "${YELLOW}⚠ FirewallD is not active, cannot check ban rules${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ PASS: Fail2ban is properly configured and running${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Some checks failed${NC}"
    echo -e "${YELLOW}    Review the issues above and fix them${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Useful commands
echo -e "${BLUE}📚 Useful Commands:${NC}"
echo "  - Check status:           sudo fail2ban-client status"
echo "  - Check SSH jail:         sudo fail2ban-client status sshd"
echo "  - Show banned IPs:        sudo fail2ban-client get sshd banned"
echo "  - Unban IP:               sudo fail2ban-client set sshd unbanip <IP>"
echo "  - Unban all:              sudo fail2ban-client unban --all"
echo "  - View logs:              sudo journalctl -u fail2ban -f"
echo "  - Check firewall rules:   sudo firewall-cmd --list-rich-rules"
echo "  - Restart service:        sudo systemctl restart fail2ban"
echo ""

exit $EXIT_CODE
