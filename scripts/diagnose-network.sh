#!/bin/bash
# VPS Network Diagnostics Script
# Run this on the VPS to diagnose AlmaLinux mirror connectivity issues

set -e

echo "========================================="
echo "VPS Network Diagnostics"
echo "========================================="
echo ""

echo "=== 1. Basic Connectivity ==="
echo "Testing connectivity to Google DNS..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Can reach 8.8.8.8 (Google DNS)"
else
    echo "❌ Cannot reach 8.8.8.8 (Google DNS) - Basic internet connectivity FAILED"
    echo "   This indicates a fundamental network problem"
fi
echo ""

echo "Testing DNS resolution..."
if ping -c 3 google.com > /dev/null 2>&1; then
    echo "✅ DNS resolution works (google.com)"
else
    echo "❌ DNS resolution FAILED"
    echo "   This indicates a DNS configuration problem"
fi
echo ""

echo "=== 2. AlmaLinux Mirror DNS Resolution ==="
echo "Checking DNS for repo.almalinux.org..."
nslookup repo.almalinux.org || echo "❌ DNS lookup failed for repo.almalinux.org"
echo ""

echo "=== 3. HTTP/HTTPS Connectivity ==="
echo "Testing HTTPS to AlmaLinux repo (10 second timeout)..."
if curl -I https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/ --max-time 10 > /dev/null 2>&1; then
    echo "✅ Can reach repo.almalinux.org via HTTPS"
else
    echo "❌ Cannot reach repo.almalinux.org via HTTPS"
    echo "   Error details:"
    curl -I https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/ --max-time 10 2>&1 | head -10
fi
echo ""

echo "=== 4. Alternative Mirrors ==="
echo "Testing CloudFlare mirror..."
if curl -I https://cloudflare.almalinux.org --max-time 10 > /dev/null 2>&1; then
    echo "✅ CloudFlare mirror is reachable"
else
    echo "❌ CloudFlare mirror is NOT reachable"
fi
echo ""

echo "Testing European mirror..."
if curl -I https://mirrors.xtom.nl/almalinux/ --max-time 10 > /dev/null 2>&1; then
    echo "✅ European mirror (XTOM) is reachable"
else
    echo "❌ European mirror (XTOM) is NOT reachable"
fi
echo ""

echo "=== 5. Firewall Configuration ==="
echo "Checking iptables rules..."
sudo iptables -L -n | head -20
echo ""

echo "Checking firewalld status..."
if sudo firewall-cmd --list-all 2>/dev/null; then
    echo "(firewalld is active)"
else
    echo "(firewalld is not active)"
fi
echo ""

echo "=== 6. Network Configuration ==="
echo "Routing table:"
ip route show
echo ""

echo "Network interfaces:"
ip addr show | grep -E "^[0-9]+:|inet "
echo ""

echo "=== 7. MTU Configuration ==="
echo "MTU settings:"
ip link show | grep mtu
echo ""

echo "=== 8. DNS Configuration ==="
echo "Current DNS servers (/etc/resolv.conf):"
cat /etc/resolv.conf
echo ""

echo "=== 9. IPv6 Status ==="
if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
    IPV6_STATUS=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
    if [ "$IPV6_STATUS" = "0" ]; then
        echo "IPv6 is ENABLED"
    else
        echo "IPv6 is DISABLED"
    fi
else
    echo "Cannot determine IPv6 status"
fi
echo ""

echo "=== 10. Repository Configuration ==="
echo "Current repository mirrors:"
if [ -f /etc/yum.repos.d/almalinux.repo ]; then
    echo "AlmaLinux repo configuration:"
    grep "^baseurl" /etc/yum.repos.d/almalinux*.repo | head -5
    grep "^mirrorlist" /etc/yum.repos.d/almalinux*.repo | head -5
else
    echo "⚠️ /etc/yum.repos.d/almalinux.repo not found"
fi
echo ""

echo "========================================="
echo "Diagnostics Complete"
echo "========================================="
echo ""
echo "Summary of findings:"
echo "- Save this output and share it for analysis"
echo "- Look for ❌ marks above to identify specific issues"
echo ""
echo "Common issues and solutions:"
echo ""
echo "1. If ping fails → Check VPS network configuration or Hetzner firewall"
echo "2. If DNS fails → Change DNS servers to 8.8.8.8 / 1.1.1.1"
echo "3. If only AlmaLinux mirrors fail → Change to alternative mirror or disable IPv6"
echo "4. If all HTTPS fails → Check firewall outbound rules"
echo "5. If MTU is > 1500 → Try reducing to 1450"
