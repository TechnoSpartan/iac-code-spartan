#!/bin/bash
#
# SSL Certificate Renewal Verification Script
#
# This script checks SSL certificate auto-renewal configuration in Traefik
# and provides information about certificate expiry and renewal status
#
# Usage:
#   ./check-ssl-renewal.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SSL Certificate Renewal Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Domains to check
DOMAINS=(
    "traefik.mambo-cloud.com"
    "grafana.mambo-cloud.com"
    "backoffice.mambo-cloud.com"
)

ACME_FILE="/opt/codespartan/platform/traefik/letsencrypt/acme.json"

# Check if Traefik is running
if ! docker ps | grep -q traefik; then
    echo -e "${RED}✗ Traefik container is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Traefik is running${NC}"
echo ""

# Check acme.json file
echo -e "${YELLOW}Checking ACME configuration file...${NC}"

if [ ! -f "$ACME_FILE" ]; then
    echo -e "${RED}✗ ACME file not found at: $ACME_FILE${NC}"
    echo "  Certificate auto-renewal may not be configured"
    exit 1
fi

echo -e "${GREEN}✓ ACME file exists${NC}"

# Check file permissions
PERMS=$(stat -c %a "$ACME_FILE" 2>/dev/null || stat -f %A "$ACME_FILE" 2>/dev/null)
if [ "$PERMS" != "600" ]; then
    echo -e "${YELLOW}⚠ ACME file permissions: $PERMS (should be 600)${NC}"
else
    echo -e "${GREEN}✓ ACME file permissions correct (600)${NC}"
fi

# Check file size
SIZE=$(stat -c %s "$ACME_FILE" 2>/dev/null || stat -f %z "$ACME_FILE" 2>/dev/null)
if [ "$SIZE" -lt 100 ]; then
    echo -e "${YELLOW}⚠ ACME file is very small ($SIZE bytes) - may not contain certificates yet${NC}"
else
    echo -e "${GREEN}✓ ACME file contains data ($SIZE bytes)${NC}"
fi

echo ""

# Check Traefik configuration
echo -e "${YELLOW}Checking Traefik configuration...${NC}"

# Check if Let's Encrypt challenge is enabled
if docker inspect traefik | grep -q "certificatesresolvers.le.acme.httpchallenge"; then
    echo -e "${GREEN}✓ HTTP Challenge enabled${NC}"
else
    echo -e "${RED}✗ HTTP Challenge not found in configuration${NC}"
fi

# Check email configuration
EMAIL=$(docker inspect traefik | grep "certificatesresolvers.le.acme.email" | head -1 | sed 's/.*email=\([^"]*\).*/\1/')
if [ -n "$EMAIL" ]; then
    echo -e "${GREEN}✓ ACME email configured: $EMAIL${NC}"
else
    echo -e "${YELLOW}⚠ ACME email not found${NC}"
fi

echo ""

# Check certificate expiry for each domain
echo -e "${YELLOW}Checking certificate expiry dates...${NC}"
echo ""

ALL_OK=true

for domain in "${DOMAINS[@]}"; do
    echo -e "${BLUE}Domain: $domain${NC}"

    # Get certificate expiry
    EXPIRY=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

    if [ -z "$EXPIRY" ]; then
        echo -e "  ${RED}✗ Could not retrieve certificate${NC}"
        ALL_OK=false
        echo ""
        continue
    fi

    # Calculate days remaining
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRY" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_REMAINING=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

    # Get issuer
    ISSUER=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
        openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')

    echo "  Issuer: $ISSUER"
    echo "  Expires: $EXPIRY"

    if [ "$DAYS_REMAINING" -gt 30 ]; then
        echo -e "  ${GREEN}✓ Valid for $DAYS_REMAINING more days${NC}"
    elif [ "$DAYS_REMAINING" -gt 7 ]; then
        echo -e "  ${YELLOW}⚠ Valid for $DAYS_REMAINING more days (renewal recommended)${NC}"
    elif [ "$DAYS_REMAINING" -gt 0 ]; then
        echo -e "  ${RED}✗ Expires in $DAYS_REMAINING days (renewal urgent!)${NC}"
        ALL_OK=false
    else
        echo -e "  ${RED}✗ Certificate has expired!${NC}"
        ALL_OK=false
    fi

    echo ""
done

# Information about Let's Encrypt auto-renewal
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Let's Encrypt Auto-Renewal Information${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Traefik automatically renews Let's Encrypt certificates:"
echo "  - Renewal check: Every 24 hours"
echo "  - Renewal trigger: Certificates < 30 days from expiry"
echo "  - Challenge type: HTTP-01 (port 80)"
echo "  - Storage: $ACME_FILE"
echo ""
echo "Manual renewal is not needed, Traefik handles it automatically."
echo ""

# How to force renewal
echo -e "${YELLOW}To force certificate renewal (if needed):${NC}"
echo "  1. Backup acme.json:"
echo "     cp $ACME_FILE ${ACME_FILE}.backup"
echo ""
echo "  2. Remove certificates (this will trigger renewal):"
echo "     docker exec traefik rm $ACME_FILE"
echo "     docker restart traefik"
echo ""
echo "  3. Wait 2-3 minutes and check:"
echo "     docker logs traefik | grep -i acme"
echo ""

# Check Traefik logs for recent ACME activity
echo -e "${YELLOW}Recent ACME activity in Traefik logs:${NC}"
docker logs traefik 2>&1 | grep -i "acme\|certificate\|let's encrypt" | tail -10 || echo "  No recent ACME activity found"
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✓ All certificates are valid and auto-renewal is configured${NC}"
    echo -e "${GREEN}✓ No action required${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some certificates need attention${NC}"
    echo "  Review the details above and consider forcing renewal if needed"
    exit 1
fi
