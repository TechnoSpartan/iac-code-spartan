#!/bin/bash
#
# Fail2ban Metrics Exporter for Prometheus
#
# This script collects Fail2ban metrics and exports them in Prometheus format
# for consumption by node-exporter's textfile collector.
#
# Usage:
#   sudo ./fail2ban-metrics.sh
#
# Cron:
#   */1 * * * * /opt/codespartan/scripts/fail2ban-metrics.sh
#
# Metrics exported:
#   - f2b_up{jail="<jail>"} - Jail is enabled (1) or disabled (0)
#   - f2b_banned_current{jail="<jail>"} - Currently banned IPs
#   - f2b_banned_total{jail="<jail>"} - Total banned IPs since start
#   - f2b_failed_current{jail="<jail>"} - Currently failed IPs
#   - f2b_failed_total{jail="<jail>"} - Total failed IPs since start
#

set -e

# Output file for node-exporter textfile collector
OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="$OUTPUT_DIR/fail2ban.prom"
TEMP_FILE="$OUTPUT_FILE.$$"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Check if fail2ban-client is available
if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo "Error: fail2ban-client not found" >&2
    exit 1
fi

# Check if fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
    echo "Error: fail2ban service is not running" >&2
    exit 1
fi

# Start writing metrics
cat > "$TEMP_FILE" << 'EOF'
# HELP f2b_up Jail is enabled (1) or disabled (0)
# TYPE f2b_up gauge
# HELP f2b_banned_current Currently banned IP addresses
# TYPE f2b_banned_current gauge
# HELP f2b_banned_total Total banned IP addresses since start
# TYPE f2b_banned_total counter
# HELP f2b_failed_current Currently failed IP addresses
# TYPE f2b_failed_current gauge
# HELP f2b_failed_total Total failed IP addresses since start
# TYPE f2b_failed_total counter
EOF

# Get list of jails
JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list:" | sed 's/.*Jail list://' | tr ',' '\n' | xargs)

if [ -z "$JAILS" ]; then
    echo "Warning: No jails found" >&2
    # Write zero metrics
    echo 'f2b_up{jail="none"} 0' >> "$TEMP_FILE"
else
    # Iterate through each jail
    for jail in $JAILS; do
        jail=$(echo "$jail" | xargs)  # Trim whitespace

        # Get jail status
        STATUS=$(fail2ban-client status "$jail" 2>/dev/null || echo "ERROR")

        if [ "$STATUS" = "ERROR" ]; then
            echo "Warning: Could not get status for jail: $jail" >&2
            echo "f2b_up{jail=\"$jail\"} 0" >> "$TEMP_FILE"
            continue
        fi

        # Jail is up
        echo "f2b_up{jail=\"$jail\"} 1" >> "$TEMP_FILE"

        # Extract metrics using grep and awk
        CURRENTLY_FAILED=$(echo "$STATUS" | grep "Currently failed:" | awk '{print $NF}')
        TOTAL_FAILED=$(echo "$STATUS" | grep "Total failed:" | awk '{print $NF}')
        CURRENTLY_BANNED=$(echo "$STATUS" | grep "Currently banned:" | awk '{print $NF}')
        TOTAL_BANNED=$(echo "$STATUS" | grep "Total banned:" | awk '{print $NF}')

        # Default to 0 if empty
        CURRENTLY_FAILED=${CURRENTLY_FAILED:-0}
        TOTAL_FAILED=${TOTAL_FAILED:-0}
        CURRENTLY_BANNED=${CURRENTLY_BANNED:-0}
        TOTAL_BANNED=${TOTAL_BANNED:-0}

        # Write metrics
        echo "f2b_failed_current{jail=\"$jail\"} $CURRENTLY_FAILED" >> "$TEMP_FILE"
        echo "f2b_failed_total{jail=\"$jail\"} $TOTAL_FAILED" >> "$TEMP_FILE"
        echo "f2b_banned_current{jail=\"$jail\"} $CURRENTLY_BANNED" >> "$TEMP_FILE"
        echo "f2b_banned_total{jail=\"$jail\"} $TOTAL_BANNED" >> "$TEMP_FILE"
    done
fi

# Add timestamp (optional but recommended)
echo "# Metrics generated at $(date -u +%s)" >> "$TEMP_FILE"

# Atomic move to avoid partial reads
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Set permissions so node-exporter can read
chmod 644 "$OUTPUT_FILE"

# Optional: Log success (comment out if running frequently via cron)
# echo "$(date): Fail2ban metrics exported to $OUTPUT_FILE" >> /var/log/fail2ban-metrics.log

exit 0
