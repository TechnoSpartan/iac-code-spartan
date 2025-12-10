#!/bin/bash
#
# System Health Check Script for CodeSpartan Mambo Cloud Platform
#
# This script verifies the health of all platform components:
# - Docker daemon status
# - All expected containers running
# - SSL certificates validity
# - Disk space availability
# - Service accessibility (HTTP checks)
# - DNS resolution
# - Resource usage (CPU, RAM, Disk)
#
# Usage:
#   ./health-check.sh              # Run all checks
#   ./health-check.sh --verbose    # Detailed output
#   ./health-check.sh --json       # Output in JSON format
#   ./health-check.sh --notify     # Send results to ntfy.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EXPECTED_CONTAINERS=(
    "traefik"
    "victoriametrics"
    "vmagent"
    "vmalert"
    "loki"
    "promtail"
    "grafana"
    "cadvisor"
    "node-exporter"
    "backoffice"
)

SERVICES_TO_CHECK=(
    "https://traefik.mambo-cloud.com|Traefik Dashboard"
    "https://grafana.mambo-cloud.com|Grafana"
    "https://backoffice.mambo-cloud.com|Backoffice"
)

DNS_RECORDS=(
    "traefik.mambo-cloud.com"
    "grafana.mambo-cloud.com"
    "backoffice.mambo-cloud.com"
)

# Thresholds
CPU_THRESHOLD=80
RAM_THRESHOLD=90
DISK_THRESHOLD=85
CERT_EXPIRY_THRESHOLD=7  # days

# Parse arguments
VERBOSE=false
JSON_OUTPUT=false
SEND_NOTIFICATION=false

for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --notify|-n)
            SEND_NOTIFICATION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Show detailed output"
            echo "  --json, -j       Output results in JSON format"
            echo "  --notify, -n     Send results to ntfy.sh"
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

# Initialize results tracking
declare -A CHECK_RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function to record check result
record_check() {
    local check_name="$1"
    local status="$2"  # pass, fail, warn
    local message="$3"

    CHECK_RESULTS["$check_name"]="$status|$message"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    case $status in
        pass)
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        fail)
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        warn)
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
    esac
}

# Function to print check result
print_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"

    if [ "$JSON_OUTPUT" = true ]; then
        return
    fi

    case $status in
        pass)
            echo -e "${GREEN}✓${NC} $check_name: $message"
            ;;
        fail)
            echo -e "${RED}✗${NC} $check_name: $message"
            ;;
        warn)
            echo -e "${YELLOW}⚠${NC} $check_name: $message"
            ;;
    esac

    if [ "$VERBOSE" = true ] && [ -n "${CHECK_DETAILS:-}" ]; then
        echo "    $CHECK_DETAILS"
        CHECK_DETAILS=""
    fi
}

# Function to print section header
print_header() {
    if [ "$JSON_OUTPUT" = true ]; then
        return
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check Docker daemon
check_docker() {
    print_header "Docker Daemon"

    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            record_check "docker_daemon" "pass" "Running"
            print_check "docker_daemon" "pass" "Docker daemon is running"
        else
            record_check "docker_daemon" "fail" "Not responding"
            print_check "docker_daemon" "fail" "Docker daemon is not responding"
        fi
    else
        record_check "docker_daemon" "fail" "Not installed"
        print_check "docker_daemon" "fail" "Docker is not installed"
    fi
}

# Check containers
check_containers() {
    print_header "Container Status"

    local running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)

    for container in "${EXPECTED_CONTAINERS[@]}"; do
        if echo "$running_containers" | grep -q "^${container}$"; then
            # Check container health
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                record_check "container_$container" "pass" "Running"
                print_check "container_$container" "pass" "$container is running"

                if [ "$VERBOSE" = true ]; then
                    local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container" | xargs date -d 2>/dev/null | awk '{print $1, $2, $3, $4}' || echo "unknown")
                    CHECK_DETAILS="Started: $uptime"
                    print_check "container_$container" "pass" ""
                fi
            elif [ "$health" = "starting" ]; then
                record_check "container_$container" "warn" "Starting"
                print_check "container_$container" "warn" "$container is starting"
            else
                record_check "container_$container" "fail" "Unhealthy"
                print_check "container_$container" "fail" "$container is unhealthy"
            fi
        else
            record_check "container_$container" "fail" "Not running"
            print_check "container_$container" "fail" "$container is not running"
        fi
    done

    # Check for unexpected containers
    if [ "$VERBOSE" = true ]; then
        local unexpected=$(docker ps --format "{{.Names}}" | while read -r name; do
            if [[ ! " ${EXPECTED_CONTAINERS[*]} " =~ " ${name} " ]]; then
                echo "$name"
            fi
        done)

        if [ -n "$unexpected" ]; then
            echo -e "${YELLOW}ℹ${NC} Unexpected containers found:"
            echo "$unexpected" | while read -r name; do
                echo "    - $name"
            done
        fi
    fi
}

# Check disk space
check_disk_space() {
    print_header "Disk Space"

    local disk_usage=$(df -h / | tail -n 1 | awk '{print $5}' | sed 's/%//')

    if [ "$disk_usage" -lt "$DISK_THRESHOLD" ]; then
        record_check "disk_space" "pass" "${disk_usage}% used"
        print_check "disk_space" "pass" "Disk usage: ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
    elif [ "$disk_usage" -lt 95 ]; then
        record_check "disk_space" "warn" "${disk_usage}% used"
        print_check "disk_space" "warn" "Disk usage: ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
    else
        record_check "disk_space" "fail" "${disk_usage}% used"
        print_check "disk_space" "fail" "Disk usage: ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
    fi

    if [ "$VERBOSE" = true ]; then
        df -h / | tail -n 1 | awk '{printf "    Used: %s / %s\n", $3, $2}'
    fi
}

# Check CPU usage
check_cpu_usage() {
    print_header "CPU Usage"

    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    cpu_usage=${cpu_usage%.*}  # Convert to integer

    if [ "$cpu_usage" -lt "$CPU_THRESHOLD" ]; then
        record_check "cpu_usage" "pass" "${cpu_usage}%"
        print_check "cpu_usage" "pass" "CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
    else
        record_check "cpu_usage" "warn" "${cpu_usage}%"
        print_check "cpu_usage" "warn" "CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
    fi
}

# Check RAM usage
check_ram_usage() {
    print_header "Memory Usage"

    local ram_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')

    if [ "$ram_usage" -lt "$RAM_THRESHOLD" ]; then
        record_check "ram_usage" "pass" "${ram_usage}%"
        print_check "ram_usage" "pass" "RAM usage: ${ram_usage}% (threshold: ${RAM_THRESHOLD}%)"
    else
        record_check "ram_usage" "warn" "${ram_usage}%"
        print_check "ram_usage" "warn" "RAM usage: ${ram_usage}% (threshold: ${RAM_THRESHOLD}%)"
    fi

    if [ "$VERBOSE" = true ]; then
        free -h | grep Mem | awk '{printf "    Used: %s / %s\n", $3, $2}'
    fi
}

# Check SSL certificates
check_ssl_certificates() {
    print_header "SSL Certificates"

    if [ ! -d "/opt/codespartan/platform/traefik/letsencrypt" ]; then
        record_check "ssl_certificates" "warn" "Certificate directory not found"
        print_check "ssl_certificates" "warn" "Certificate directory not found"
        return
    fi

    # Check if acme.json exists
    if [ -f "/opt/codespartan/platform/traefik/letsencrypt/acme.json" ]; then
        for domain in "${DNS_RECORDS[@]}"; do
            local expiry=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

            if [ -n "$expiry" ]; then
                local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
                local now_epoch=$(date +%s)
                local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

                if [ "$days_remaining" -gt "$CERT_EXPIRY_THRESHOLD" ]; then
                    record_check "ssl_$domain" "pass" "${days_remaining} days remaining"
                    print_check "ssl_$domain" "pass" "$domain certificate valid for ${days_remaining} days"
                elif [ "$days_remaining" -gt 0 ]; then
                    record_check "ssl_$domain" "warn" "${days_remaining} days remaining"
                    print_check "ssl_$domain" "warn" "$domain certificate expires in ${days_remaining} days"
                else
                    record_check "ssl_$domain" "fail" "Expired"
                    print_check "ssl_$domain" "fail" "$domain certificate has expired"
                fi
            else
                record_check "ssl_$domain" "warn" "Could not verify"
                print_check "ssl_$domain" "warn" "$domain certificate could not be verified"
            fi
        done
    else
        record_check "ssl_certificates" "warn" "acme.json not found"
        print_check "ssl_certificates" "warn" "acme.json not found"
    fi
}

# Check HTTP services
check_http_services() {
    print_header "HTTP Services"

    for service_info in "${SERVICES_TO_CHECK[@]}"; do
        IFS='|' read -r url name <<< "$service_info"

        if timeout 10 curl -sSf -k "$url" > /dev/null 2>&1; then
            record_check "http_${name// /_}" "pass" "Accessible"
            print_check "http_${name// /_}" "pass" "$name is accessible ($url)"
        else
            record_check "http_${name// /_}" "fail" "Not accessible"
            print_check "http_${name// /_}" "fail" "$name is not accessible ($url)"
        fi
    done
}

# Check DNS resolution
check_dns() {
    print_header "DNS Resolution"

    for domain in "${DNS_RECORDS[@]}"; do
        if host "$domain" > /dev/null 2>&1; then
            local ip=$(host "$domain" | grep "has address" | awk '{print $4}' | head -n1)
            record_check "dns_$domain" "pass" "Resolves to $ip"
            print_check "dns_$domain" "pass" "$domain resolves to $ip"
        else
            record_check "dns_$domain" "fail" "Does not resolve"
            print_check "dns_$domain" "fail" "$domain does not resolve"
        fi
    done
}

# Output results in JSON format
output_json() {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"summary\": {"
    echo "    \"total\": $TOTAL_CHECKS,"
    echo "    \"passed\": $PASSED_CHECKS,"
    echo "    \"failed\": $FAILED_CHECKS,"
    echo "    \"warnings\": $WARNING_CHECKS"
    echo "  },"
    echo "  \"checks\": {"

    local first=true
    for check_name in "${!CHECK_RESULTS[@]}"; do
        IFS='|' read -r status message <<< "${CHECK_RESULTS[$check_name]}"

        if [ "$first" = false ]; then
            echo ","
        fi
        first=false

        echo -n "    \"$check_name\": {\"status\": \"$status\", \"message\": \"$message\"}"
    done

    echo ""
    echo "  }"
    echo "}"
}

# Send notification
send_notification() {
    if ! command -v curl &> /dev/null; then
        return
    fi

    local title="Health Check Report"
    local priority="default"
    local emoji="✅"

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        priority="urgent"
        emoji="❌"
    elif [ "$WARNING_CHECKS" -gt 0 ]; then
        priority="high"
        emoji="⚠"
    fi

    local message="$emoji Health Check: $PASSED_CHECKS passed, $FAILED_CHECKS failed, $WARNING_CHECKS warnings"

    curl -X POST https://ntfy.sh/codespartan-mambo-alerts \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -d "$message" \
        2>/dev/null || true
}

# Print summary
print_summary() {
    if [ "$JSON_OUTPUT" = true ]; then
        return
    fi

    print_header "Health Check Summary"

    echo "Total Checks:   $TOTAL_CHECKS"
    echo -e "${GREEN}Passed:${NC}        $PASSED_CHECKS"

    if [ "$WARNING_CHECKS" -gt 0 ]; then
        echo -e "${YELLOW}Warnings:${NC}      $WARNING_CHECKS"
    fi

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        echo -e "${RED}Failed:${NC}        $FAILED_CHECKS"
    fi

    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ] && [ "$WARNING_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✓ All systems operational${NC}"
    elif [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${YELLOW}⚠ Some warnings detected${NC}"
    else
        echo -e "${RED}✗ Critical issues detected${NC}"
    fi
}

# Main function
main() {
    if [ "$JSON_OUTPUT" = false ]; then
        print_header "CodeSpartan Platform Health Check"
        echo "Checking system health at $(date)"
    fi

    # Run all checks
    check_docker
    check_containers
    check_disk_space
    check_cpu_usage
    check_ram_usage
    check_ssl_certificates
    check_http_services
    check_dns

    # Output results
    if [ "$JSON_OUTPUT" = true ]; then
        output_json
    else
        print_summary
    fi

    # Send notification if requested
    if [ "$SEND_NOTIFICATION" = true ]; then
        send_notification
    fi

    # Exit with appropriate code
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        exit 1
    elif [ "$WARNING_CHECKS" -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function
main
