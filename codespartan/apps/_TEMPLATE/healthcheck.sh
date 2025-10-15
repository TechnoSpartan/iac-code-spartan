#!/bin/bash
#
# Health Check Script for Docker Container
#
# This script checks if the application is responding correctly.
# Customize the health check logic based on your application needs.
#

set -e

# Configuration
APP_PORT="${APP_PORT:-80}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-/}"
MAX_RETRIES=3
RETRY_DELAY=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check HTTP endpoint
check_http() {
    local url="http://localhost:${APP_PORT}${HEALTH_ENDPOINT}"
    local response

    echo -e "${YELLOW}Checking HTTP endpoint: ${url}${NC}"

    for i in $(seq 1 $MAX_RETRIES); do
        if response=$(wget --quiet --tries=1 --timeout=5 --spider --server-response "$url" 2>&1); then
            if echo "$response" | grep -q "HTTP/1.[01] [23].."; then
                echo -e "${GREEN}✓ Health check passed (attempt $i/$MAX_RETRIES)${NC}"
                return 0
            fi
        fi

        if [ $i -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⚠ Health check failed (attempt $i/$MAX_RETRIES), retrying in ${RETRY_DELAY}s...${NC}"
            sleep $RETRY_DELAY
        fi
    done

    echo -e "${RED}✗ Health check failed after $MAX_RETRIES attempts${NC}"
    return 1
}

# Function to check TCP port
check_tcp() {
    local port="${1:-$APP_PORT}"

    echo -e "${YELLOW}Checking TCP port: ${port}${NC}"

    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/localhost/${port}"; then
        echo -e "${GREEN}✓ Port ${port} is open${NC}"
        return 0
    else
        echo -e "${RED}✗ Port ${port} is not accessible${NC}"
        return 1
    fi
}

# Function to check process
check_process() {
    local process_name="${1:-nginx}"

    echo -e "${YELLOW}Checking process: ${process_name}${NC}"

    if pgrep -x "$process_name" > /dev/null; then
        echo -e "${GREEN}✓ Process ${process_name} is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Process ${process_name} is not running${NC}"
        return 1
    fi
}

# Main health check
main() {
    echo "================================"
    echo "  Application Health Check"
    echo "================================"
    echo ""

    local exit_code=0

    # Check 1: HTTP endpoint (most common)
    if ! check_http; then
        exit_code=1
    fi

    echo ""

    # Check 2: TCP port (alternative if no HTTP endpoint)
    # Uncomment if needed:
    # if ! check_tcp; then
    #     exit_code=1
    # fi

    # Check 3: Process check (for debugging)
    # Uncomment and adjust process name if needed:
    # if ! check_process "nginx"; then
    #     exit_code=1
    # fi

    echo ""
    echo "================================"

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ All health checks passed${NC}"
    else
        echo -e "${RED}✗ Some health checks failed${NC}"
    fi

    echo "================================"

    exit $exit_code
}

# Run main function
main
