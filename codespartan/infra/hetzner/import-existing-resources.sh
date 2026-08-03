#!/bin/bash
set -euo pipefail

# This script imports existing Hetzner Cloud and DNS resources into Terraform state
# Run this locally with proper credentials or in GitHub Actions

echo "===== Importing Existing Hetzner Resources ====="

# Import SSH Key
echo "Importing SSH key..."
SSH_KEY_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/ssh_keys | \
  jq -r '.ssh_keys[] | select(.name=="codespartan") | .id')

if [ -n "$SSH_KEY_ID" ]; then
  echo "Found SSH key: $SSH_KEY_ID"
  terraform import 'hcloud_ssh_key.main' "$SSH_KEY_ID" 2>/dev/null || echo "SSH key already in state"
else
  echo "WARNING: SSH key 'codespartan' not found"
fi

# Import apis-deploy SSH key (won't exist on first run - Terraform will create it)
echo "Importing apis-deploy SSH key..."
APIS_DEPLOY_KEY_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/ssh_keys | \
  jq -r '.ssh_keys[] | select(.name=="codespartan-apis-deploy") | .id')

if [ -n "$APIS_DEPLOY_KEY_ID" ]; then
  echo "Found SSH key: $APIS_DEPLOY_KEY_ID"
  terraform import 'hcloud_ssh_key.apis_deploy' "$APIS_DEPLOY_KEY_ID" 2>/dev/null || echo "SSH key already in state"
else
  echo "INFO: SSH key 'codespartan-apis-deploy' not found yet - Terraform will create it"
fi

# Import Firewall
echo "Importing firewall..."
FIREWALL_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/firewalls | \
  jq -r '.firewalls[] | select(.name=="codespartan-basic") | .id')

if [ -n "$FIREWALL_ID" ]; then
  echo "Found firewall: $FIREWALL_ID"
  terraform import 'hcloud_firewall.basic' "$FIREWALL_ID" 2>/dev/null || echo "Firewall already in state"
else
  echo "WARNING: Firewall 'codespartan-basic' not found"
fi

# Import Server
echo "Importing server..."
SERVER_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/servers | \
  jq -r '.servers[] | select(.name=="CodeSpartan-alma") | .id')

if [ -n "$SERVER_ID" ]; then
  echo "Found server: $SERVER_ID (CodeSpartan-alma)"
  terraform import 'hcloud_server.vps' "$SERVER_ID" 2>/dev/null || echo "Server already in state"
else
  echo "ERROR: Server 'CodeSpartan-alma' not found!"
  exit 1
fi

# Import second server (tier APIs/BBDD, x86) - won't exist on the very first run,
# that's expected: Terraform will just create it, nothing to import yet.
echo "Importing second server (APIs/BBDD tier)..."
APIS_SERVER_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/servers | \
  jq -r '.servers[] | select(.name=="CodeSpartan-apis") | .id')

if [ -n "$APIS_SERVER_ID" ]; then
  echo "Found server: $APIS_SERVER_ID (CodeSpartan-apis)"
  terraform import 'hcloud_server.vps_apis' "$APIS_SERVER_ID" 2>/dev/null || echo "Server already in state"
else
  echo "INFO: Server 'CodeSpartan-apis' not found yet - Terraform will create it"
fi

# Import private network (codespartan-internal) + subnet + server attachments.
# Won't exist on the first run - Terraform will create them, nothing to import yet.
echo "Importing private network..."
NETWORK_ID=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/networks | \
  jq -r '.networks[] | select(.name=="codespartan-internal") | .id')

if [ -n "$NETWORK_ID" ]; then
  echo "Found network: $NETWORK_ID"
  terraform import 'hcloud_network.internal' "$NETWORK_ID" 2>/dev/null || echo "Network already in state"
  terraform import 'hcloud_network_subnet.internal' "${NETWORK_ID}-10.0.0.0/24" 2>/dev/null || echo "Subnet already in state"
  terraform import 'hcloud_server_network.vps' "${SERVER_ID}-${NETWORK_ID}" 2>/dev/null || echo "vps network attachment already in state"
  if [ -n "$APIS_SERVER_ID" ]; then
    terraform import 'hcloud_server_network.vps_apis' "${APIS_SERVER_ID}-${NETWORK_ID}" 2>/dev/null || echo "vps_apis network attachment already in state"
  fi
else
  echo "INFO: Network 'codespartan-internal' not found yet - Terraform will create it"
fi

# Import DNS Zones + RRsets (hcloud_zone / hcloud_zone_rrset, Cloud API).
# dns.hetzner.com and the old timohirt/hetznerdns provider are gone (Hetzner
# closed the standalone DNS API/console in May 2026); DNS now lives under the
# same Cloud API as servers, so no separate lookup token/call is needed - the
# import ID is built directly from known values:
#   zone:  "$ZONE_ID_OR_NAME"
#   rrset: "$ZONE_ID_OR_NAME/$RRSET_NAME/$RRSET_TYPE"
# A failed import just means the resource doesn't exist yet - swallowed like
# every other "already in state" fallback in this script.
echo "Importing DNS zones and records..."
# Keep these two lists in sync with `domains`/`subdomains` in terraform.tfvars.
domains=("mambo-cloud.com" "cyberdyne-systems.es" "codespartan.cloud" "dental-ia.es")
  subdomains=("traefik" "grafana" "backoffice" "www" "staging" "lab" "lab-staging" "api" "api-staging" "project" "ui" "mambo" "portainer" "crm" "auth")

for domain in "${domains[@]}"; do
  terraform import "hcloud_zone.zones[\"$domain\"]" "$domain" 2>/dev/null \
    && echo "Imported zone: $domain" || echo "Zone $domain: not found yet or already in state"

  for subdomain in "${subdomains[@]}"; do
    terraform import "hcloud_zone_rrset.subs[\"${domain}_${subdomain}\"]" "$domain/$subdomain/A" 2>/dev/null \
      && echo "Imported A: $domain/$subdomain" || echo "A $domain/$subdomain: not found yet or already in state"
    terraform import "hcloud_zone_rrset.subs_aaaa[\"${domain}_${subdomain}\"]" "$domain/$subdomain/AAAA" 2>/dev/null \
      && echo "Imported AAAA: $domain/$subdomain" || echo "AAAA $domain/$subdomain: not found yet or already in state"
  done

  terraform import "hcloud_zone_rrset.apex_a[\"$domain\"]" "$domain/@/A" 2>/dev/null \
    && echo "Imported apex A: $domain" || echo "Apex A $domain: not found yet or already in state"
  terraform import "hcloud_zone_rrset.apex_aaaa[\"$domain\"]" "$domain/@/AAAA" 2>/dev/null \
    && echo "Imported apex AAAA: $domain" || echo "Apex AAAA $domain: not found yet or already in state"
done

# Additional records (dns_additional_records / hcloud_zone_rrset.additional).
# Same "no persistent backend" problem as above: each group (domain, name,
# type) must be listed here manually, matching terraform.tfvars, or a
# successful create in one CI run becomes a 409 "already exists" in the next.
# Keep in sync with dns_additional_records in terraform.tfvars
additional_records=(
  "codespartan.cloud|@|MX"
  "codespartan.cloud|@|TXT"
  "codespartan.cloud|brevo1._domainkey|CNAME"
  "codespartan.cloud|brevo2._domainkey|CNAME"
  "codespartan.cloud|_dmarc|TXT"
  "codespartan.cloud|mail|TXT"
)

for entry in "${additional_records[@]}"; do
  IFS='|' read -r domain name type <<< "$entry"
  terraform import "hcloud_zone_rrset.additional[\"${domain}_${name}_${type}\"]" "$domain/$name/$type" 2>/dev/null \
    && echo "Imported additional $type: $domain/$name" || echo "Additional $type $domain/$name: not found yet or already in state"
done

echo ""
echo "===== Import Complete ====="
echo "Run 'terraform plan' to verify state is clean"
