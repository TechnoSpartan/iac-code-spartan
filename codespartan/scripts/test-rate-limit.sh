#!/bin/bash
#
# Rate Limiting Test Script
#
# This script tests Traefik rate limiting configuration by sending
# multiple requests to a service and checking for 429 (Too Many Requests) responses
#
# Usage:
#   ./test-rate-limit.sh [URL] [REQUESTS]
#   ./test-rate-limit.sh https://grafana.mambo-cloud.com 150
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
URL="${1:-https://grafana.mambo-cloud.com}"
NUM_REQUESTS="${2:-150}"
PARALLEL_REQUESTS=10

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Rate Limiting Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Target URL: $URL"
echo "Total requests: $NUM_REQUESTS"
echo "Parallel requests: $PARALLEL_REQUESTS"
echo ""

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed${NC}"
    exit 1
fi

# Counters
SUCCESS=0
RATE_LIMITED=0
ERRORS=0

# Create temporary directory for results
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${YELLOW}Sending requests...${NC}"

# Function to make a request and record result
make_request() {
    local id=$1
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" -k "$URL" 2>/dev/null)

    case $response_code in
        200|301|302|304)
            echo "success" > "$TMP_DIR/$id"
            ;;
        429)
            echo "rate_limited" > "$TMP_DIR/$id"
            ;;
        *)
            echo "error_$response_code" > "$TMP_DIR/$id"
            ;;
    esac
}

# Send requests in batches
BATCH_SIZE=$PARALLEL_REQUESTS
for ((i=1; i<=NUM_REQUESTS; i+=BATCH_SIZE)); do
    # Start batch of parallel requests
    for ((j=0; j<BATCH_SIZE && i+j<=NUM_REQUESTS; j++)); do
        make_request $((i+j)) &
    done

    # Wait for batch to complete
    wait

    # Show progress
    COMPLETED=$((i + BATCH_SIZE - 1))
    if [ $COMPLETED -gt $NUM_REQUESTS ]; then
        COMPLETED=$NUM_REQUESTS
    fi
    echo -ne "\rProgress: $COMPLETED/$NUM_REQUESTS requests sent"
done

echo ""
echo ""

# Count results
for file in "$TMP_DIR"/*; do
    result=$(cat "$file")
    case $result in
        success)
            SUCCESS=$((SUCCESS + 1))
            ;;
        rate_limited)
            RATE_LIMITED=$((RATE_LIMITED + 1))
            ;;
        error_*)
            ERRORS=$((ERRORS + 1))
            ;;
    esac
done

# Print results
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Results${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Successful (2xx/3xx):${NC}     $SUCCESS"
echo -e "${YELLOW}Rate Limited (429):${NC}       $RATE_LIMITED"
echo -e "${RED}Errors (other):${NC}           $ERRORS"
echo ""

# Calculate rate limit percentage
if [ $NUM_REQUESTS -gt 0 ]; then
    RATE_LIMIT_PCT=$((RATE_LIMITED * 100 / NUM_REQUESTS))
    echo "Rate limit triggered: ${RATE_LIMIT_PCT}% of requests"
fi

echo ""

# Verdict
if [ $RATE_LIMITED -gt 0 ]; then
    echo -e "${GREEN}✓ Rate limiting is working!${NC}"
    echo "  Traefik is blocking excessive requests with 429 status codes"
    exit 0
elif [ $SUCCESS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Rate limiting may not be configured${NC}"
    echo "  All requests succeeded without hitting rate limits"
    echo "  This could mean:"
    echo "  - Rate limit is higher than test load"
    echo "  - Rate limiting is not enabled"
    echo "  - Try increasing NUM_REQUESTS or PARALLEL_REQUESTS"
    exit 1
else
    echo -e "${RED}✗ Test failed${NC}"
    echo "  Most requests resulted in errors"
    exit 1
fi
