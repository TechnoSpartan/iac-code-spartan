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

# Import DNS Zones
echo "Importing DNS zones..."
for domain in "mambo-cloud.com" "cyberdyne-systems.es" "codespartan.cloud"; do
  ZONE_ID=$(curl -s -H "Auth-API-Token: $TF_VAR_hetzner_dns_token" \
    https://dns.hetzner.com/api/v1/zones | \
    jq -r ".zones[] | select(.name==\"$domain\") | .id")

  if [ -n "$ZONE_ID" ]; then
    echo "Found DNS zone '$domain': $ZONE_ID"
    terraform import "hetznerdns_zone.zones[\"$domain\"]" "$ZONE_ID" 2>/dev/null || echo "Zone $domain already in state"
  else
    echo "WARNING: DNS zone '$domain' not found"
  fi
done

# Import DNS Records (A and AAAA for subdomains)
echo "Importing DNS records..."
subdomains=("traefik" "grafana" "backoffice" "www" "staging" "lab" "lab-staging" "api" "api-staging" "project" "ui" "mambo")

for domain in "mambo-cloud.com" "cyberdyne-systems.es" "codespartan.cloud"; do
  ZONE_ID=$(curl -s -H "Auth-API-Token: $TF_VAR_hetzner_dns_token" \
    https://dns.hetzner.com/api/v1/zones | \
    jq -r ".zones[] | select(.name==\"$domain\") | .id")

  if [ -z "$ZONE_ID" ]; then
    echo "Skipping $domain - zone not found"
    continue
  fi

  # Get all records for this zone
  RECORDS=$(curl -s -H "Auth-API-Token: $TF_VAR_hetzner_dns_token" \
    "https://dns.hetzner.com/api/v1/records?zone_id=$ZONE_ID")

  for subdomain in "${subdomains[@]}"; do
    # Import A record
    RECORD_ID=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$subdomain\" and .type==\"A\") | .id")
    if [ -n "$RECORD_ID" ] && [ "$RECORD_ID" != "null" ]; then
      echo "Importing A record: ${domain}_${subdomain}"
      terraform import "hetznerdns_record.subs[\"${domain}_${subdomain}\"]" "$RECORD_ID" 2>/dev/null || echo "Already in state"
    fi

    # Import AAAA record
    RECORD_ID=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$subdomain\" and .type==\"AAAA\") | .id")
    if [ -n "$RECORD_ID" ] && [ "$RECORD_ID" != "null" ]; then
      echo "Importing AAAA record: ${domain}_${subdomain}"
      terraform import "hetznerdns_record.subs_aaaa[\"${domain}_${subdomain}\"]" "$RECORD_ID" 2>/dev/null || echo "Already in state"
    fi
  done

  # Import apex A record
  APEX_A_ID=$(echo "$RECORDS" | jq -r '.records[] | select(.name=="@" and .type=="A") | .id')
  if [ -n "$APEX_A_ID" ] && [ "$APEX_A_ID" != "null" ]; then
    echo "Importing apex A record for $domain"
    terraform import "hetznerdns_record.apex_a[\"$domain\"]" "$APEX_A_ID" 2>/dev/null || echo "Already in state"
  fi

  # Import apex AAAA record
  APEX_AAAA_ID=$(echo "$RECORDS" | jq -r '.records[] | select(.name=="@" and .type=="AAAA") | .id')
  if [ -n "$APEX_AAAA_ID" ] && [ "$APEX_AAAA_ID" != "null" ]; then
    echo "Importing apex AAAA record for $domain"
    terraform import "hetznerdns_record.apex_aaaa[\"$domain\"]" "$APEX_AAAA_ID" 2>/dev/null || echo "Already in state"
  fi
done

echo ""
echo "===== Import Complete ====="
echo "Run 'terraform plan' to verify state is clean"
