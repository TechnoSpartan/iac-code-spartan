# Terraform Infrastructure Deployment Fix

**Date:** 2025-11-10
**Issue:** GitHub Actions workflow for infrastructure deployment was failing
**Status:** ✅ RESOLVED

## Problem Summary

The `deploy-infrastructure.yml` workflow was failing with two critical issues:

### 1. Server Import Failure
- **Error:** Server "CodeSpartan-alma" not found during import
- **Actual State:** Server exists (ID: 112744417, IPv4: 91.98.137.217)
- **Impact:** Terraform tried to create a new server instead of managing the existing one

### 2. DNS API Rate Limiting
- **Error:** `POST https://dns.hetzner.com/api/v1/records giving up after 11 attempt(s)`
- **Root Cause:** Terraform tried to create 100+ DNS records that already existed
- **Impact:** Massive API rate limiting, failed after 1h48m runtime

## Solution Implemented

### Created Comprehensive Import Script
**File:** `codespartan/infra/hetzner/import-existing-resources.sh`

The script systematically imports all existing Hetzner resources:

1. **Hetzner Cloud Resources:**
   - SSH Key (ID: 102939735)
   - Firewall (ID: 10058534)
   - Server "CodeSpartan-alma" (ID: 112744417)

2. **DNS Zones (3 total):**
   - mambo-cloud.com (52 records)
   - cyberdyne-systems.es (35 records)
   - codespartan.cloud (31 records)

3. **DNS Records (100+ total):**
   - A records for all subdomains: traefik, grafana, backoffice, www, staging, lab, api, project, ui, mambo, lab-staging, api-staging
   - AAAA (IPv6) records for all subdomains
   - Apex A and AAAA records for each domain

### Updated Workflow
**File:** `.github/workflows/deploy-infrastructure.yml`

Replaced inline import logic with call to comprehensive import script:

```yaml
- name: Import existing resources (if not already imported)
  run: |
    chmod +x ./import-existing-resources.sh
    ./import-existing-resources.sh
```

## Results

### Before Fix
- ❌ Workflow failed after 1h48m
- ❌ 81 resources attempted to create
- ❌ DNS API rate limiting errors
- ❌ Server not found

### After Fix
- ✅ Workflow succeeded in 2m10s (48x faster!)
- ✅ All resources imported successfully
- ✅ No API errors
- ✅ Terraform state matches actual infrastructure perfectly

```
No changes. Your infrastructure matches the configuration.
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

## Current Infrastructure State

**Terraform now manages:**
- 1 SSH key
- 1 firewall
- 1 server (CodeSpartan-alma)
- 3 DNS zones
- 118+ DNS records (A and AAAA for all subdomains)

**Outputs:**
```hcl
dns_zone_ids = {
  "codespartan.cloud" = "nqSQUma65SDn3r5xDYv9wn"
  "cyberdyne-systems.es" = "8NV5HzwjroyKBD4rcsBUMR"
  "mambo-cloud.com" = "ApA8dZ7xbTygBAsUHgmvzW"
}
ipv4 = "91.98.137.217"
server_id = "112744417"
```

## Usage

### Deploy Infrastructure Changes

```bash
# Trigger workflow via GitHub Actions
gh workflow run deploy-infrastructure.yml --repo TechnoSpartan/iac-code-spartan -f action=apply

# Or: Push changes to codespartan/infra/hetzner/** (auto-triggers)
```

### Run Import Script Locally

```bash
cd codespartan/infra/hetzner
export HCLOUD_TOKEN="your_hetzner_cloud_token"
export TF_VAR_hetzner_dns_token="your_hetzner_dns_token"
export TF_VAR_ssh_public_key_content="your_ssh_public_key"

./import-existing-resources.sh
terraform plan  # Verify state is clean
```

## Files Modified

1. **Created:**
   - `codespartan/infra/hetzner/import-existing-resources.sh` - Comprehensive import script
   - `.github/workflows/diagnostic-check.yml` - Diagnostic workflow (for troubleshooting)
   - Este documento - `docs/04-deployment/TERRAFORM.md`

2. **Modified:**
   - `.github/workflows/deploy-infrastructure.yml` - Use import script instead of inline logic
   - `codespartan/infra/hetzner/terraform.tfvars` - Corrected server name to "CodeSpartan-alma"

## Commits

- `04e218c` - Initial DNS zone import fix
- `25f4600` - Corrected server name to CodeSpartan-alma
- `54beda1` - Created diagnostic workflow
- `e02a231` - **Comprehensive import script (main fix)**

## Next Steps

The infrastructure is now fully managed by Terraform. You can:

1. **Make changes** to Terraform configuration files
2. **Commit and push** to trigger automatic deployment
3. **View workflow status** in GitHub Actions
4. **Verify DNS** records with `dig` commands

## Notes

- The import script is **idempotent** - safe to run multiple times
- Import errors like "Already in state" are expected and harmless
- All DNS records now support both IPv4 (A) and IPv6 (AAAA)
- The server lifecycle ignores changes to `ssh_keys` and `user_data` to prevent accidental reprovisioning
