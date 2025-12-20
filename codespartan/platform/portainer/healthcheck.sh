#!/bin/bash
# Portainer External Health Check
# This script runs on the HOST to check Portainer health
# (Portainer container is distroless and has no shell/curl/wget)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_portainer() {
    echo "🔍 Checking Portainer health..."

    # Check 1: Container is running
    if ! docker ps --filter "name=portainer" --filter "status=running" | grep -q portainer; then
        echo -e "${RED}❌ FAIL: Portainer container is not running${NC}"
        return 1
    fi
    echo -e "${GREEN}✓${NC} Portainer container is running"

    # Check 2: Process is alive
    if ! docker top portainer &>/dev/null; then
        echo -e "${RED}❌ FAIL: Cannot list Portainer processes${NC}"
        return 1
    fi
    echo -e "${GREEN}✓${NC} Portainer process is active"

    # Check 3: HTTP endpoint via internal network
    HTTP_STATUS=$(docker run --rm --network web alpine/curl:latest \
        curl -s -o /dev/null -w "%{http_code}" http://portainer:9000/ 2>/dev/null || echo "000")

    if [[ "$HTTP_STATUS" == "000" ]]; then
        echo -e "${RED}❌ FAIL: Portainer HTTP endpoint not responding${NC}"
        return 1
    elif [[ "$HTTP_STATUS" =~ ^(200|30[0-9])$ ]]; then
        echo -e "${GREEN}✓${NC} Portainer HTTP endpoint responding (Status: $HTTP_STATUS)"
    else
        echo -e "${YELLOW}⚠${NC}  Portainer responding with unexpected status: $HTTP_STATUS"
    fi

    # Check 4: No errors in recent logs
    ERROR_COUNT=$(docker logs portainer --tail 50 --since 5m 2>&1 | grep -icE "error|fatal|panic" || echo "0")

    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC}  Found $ERROR_COUNT error(s) in recent logs"
        echo "Recent errors:"
        docker logs portainer --tail 50 --since 5m 2>&1 | grep -iE "error|fatal|panic" | tail -5
    else
        echo -e "${GREEN}✓${NC} No errors in recent logs (last 5 minutes)"
    fi

    # Check 5: Resource usage
    MEM_USAGE=$(docker stats portainer --no-stream --format "{{.MemPerc}}" | tr -d '% \n')
    CPU_USAGE=$(docker stats portainer --no-stream --format "{{.CPUPerc}}" | tr -d '% \n')

    echo -e "${GREEN}✓${NC} Resource usage: CPU ${CPU_USAGE}%, Memory ${MEM_USAGE}%"

    # Check 6: External HTTPS access via Traefik
    HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Host: portainer.mambo-cloud.com" https://localhost/ -k 2>/dev/null || echo "000")

    if [[ "$HTTPS_STATUS" =~ ^(200|30[0-9]|40[0-9])$ ]]; then
        echo -e "${GREEN}✓${NC} External access via Traefik working (Status: $HTTPS_STATUS)"
    else
        echo -e "${YELLOW}⚠${NC}  External access status: $HTTPS_STATUS"
    fi

    echo ""
    echo -e "${GREEN}✅ Portainer is HEALTHY${NC}"
    return 0
}

# Main execution
if check_portainer; then
    exit 0
else
    echo -e "${RED}❌ Portainer health check FAILED${NC}"
    exit 1
fi
