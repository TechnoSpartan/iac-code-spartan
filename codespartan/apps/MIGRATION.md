# Apps Structure Migration

**Date**: 2025-11-10
**Status**: ✅ Completed

## Overview

Reorganized the `codespartan/apps/` directory structure to better reflect the domain→subdomain hierarchy, making it clearer and more maintainable.

## Changes Summary

### Before (Old Structure)
```
codespartan/apps/
├── cyberdyne/              # Mixed: had frontend/, backend/, staging/
├── cyberdyne-api/          # Duplicate/confusion
├── mambo-cloud/            # Single service
└── openproject/            # Actually project.cyberdyne-systems.es
```

**Problems:**
- ❌ Unclear what `openproject` belonged to
- ❌ `cyberdyne` and `cyberdyne-api` separation was confusing
- ❌ Not scalable for adding new subdominios
- ❌ Domain hierarchy not clear

### After (New Structure)
```
codespartan/apps/
├── cyberdyne-systems-es/
│   ├── www/                     # www.cyberdyne-systems.es (was: cyberdyne/frontend/)
│   ├── staging/                 # staging.cyberdyne-systems.es
│   ├── api/                     # api.cyberdyne-systems.es (was: cyberdyne/backend/)
│   ├── api-staging/             # api-staging.cyberdyne-systems.es
│   ├── project/                 # project.cyberdyne-systems.es (was: openproject/)
│   ├── lab/                     # lab.cyberdyne-systems.es [placeholder]
│   ├── lab-staging/             # lab-staging.cyberdyne-systems.es [placeholder]
│   └── mambo/                   # mambo.cyberdyne-systems.es [placeholder]
├── mambo-cloud-com/
│   ├── www/                     # www.mambo-cloud.com (was: mambo-cloud/)
│   ├── staging/                 # staging.mambo-cloud.com [placeholder]
│   └── backoffice/              # backoffice.mambo-cloud.com [placeholder]
├── dental-ia-es/
│   └── www/                     # www.dental-ia.es
└── codespartan-cloud/           # NEW DOMAIN
    ├── www/                     # www.codespartan.cloud [placeholder]
    ├── staging/                 # staging.codespartan.cloud [placeholder]
    ├── api/                     # api.codespartan.cloud [placeholder]
    ├── api-staging/             # api-staging.codespartan.cloud [placeholder]
    ├── lab/                     # lab.codespartan.cloud [placeholder]
    ├── lab-staging/             # lab-staging.codespartan.cloud [placeholder]
    ├── ui/                      # ui.codespartan.cloud [placeholder]
    └── mambo/                   # mambo.codespartan.cloud [placeholder]
```

**Advantages:**
- ✅ Clear domain→subdomain hierarchy
- ✅ Easy to add new subdomains
- ✅ Self-documenting structure
- ✅ Better isolation and maintainability
- ✅ Consistent naming convention

## Migration Mapping

| Old Path | New Path | Status |
|----------|----------|--------|
| `cyberdyne/frontend/` | `cyberdyne-systems-es/www/` | ✅ Migrated |
| `cyberdyne/staging/` | `cyberdyne-systems-es/staging/` | ✅ Migrated |
| `cyberdyne/backend/` | `cyberdyne-systems-es/api/` | ✅ Migrated |
| `cyberdyne/backend-staging/` | `cyberdyne-systems-es/api-staging/` | ✅ Migrated |
| `openproject/` | ~~`cyberdyne-systems-es/project/`~~ | 🗑️ **Removed** (replaced by Redmine) |
| `mambo-cloud/` | `mambo-cloud-com/www/` | ✅ Migrated |
| `cyberdyne-api/` | ❌ **Deprecated** (duplicate of cyberdyne/backend/) | To remove |
| - | `cyberdyne-systems-es/lab/` | 🆕 Placeholder |
| - | `cyberdyne-systems-es/lab-staging/` | 🆕 Placeholder |
| - | `cyberdyne-systems-es/mambo/` | 🆕 Placeholder |
| - | `codespartan-cloud/*` | 🆕 New domain |

## Old Directories (To Be Removed)

These directories are deprecated and should be removed after verifying the migration:

```bash
codespartan/apps/
├── cyberdyne/          # Replaced by cyberdyne-systems-es/
├── cyberdyne-api/      # Duplicate - can be removed
├── mambo-cloud/        # Replaced by mambo-cloud-com/
└── openproject/        # 🗑️ Removed (replaced by codespartan-cloud/redmine/)
```

⚠️ **Do not delete old directories until**:
1. All docker-compose files updated
2. All GitHub Actions workflows updated
3. All deployments verified
4. Docker volumes migrated on production server

## Next Steps

### 1. Update Terraform DNS Configuration

Add `codespartan.cloud` domain and all subdomains to `codespartan/infra/hetzner/terraform.tfvars`:

```hcl
domains = ["mambo-cloud.com", "cyberdyne-systems.es", "codespartan.cloud"]
subdomains = [
  # existing...
  # Add for codespartan.cloud:
  "www", "staging", "api", "api-staging",
  "lab", "api-lab", "ui", "mambo"
]
```

### 2. Update GitHub Actions Workflows

Update paths in `.github/workflows/` files:
- `deploy-cyberdyne.yml` → Update paths to `cyberdyne-systems-es/`
- Create new workflows for `codespartan.cloud` services
- Update scp/rsync commands with new paths

### 3. Server Migration (Production)

```bash
# SSH to server
ssh leonidas@91.98.137.217

# Create new directory structure
sudo mkdir -p /opt/codespartan/apps/cyberdyne-systems-es/{www,api,api-staging,staging,project}
sudo mkdir -p /opt/codespartan/apps/codespartan-cloud/{www,api,lab,ui}

# Copy docker-compose files
# Update volumes paths if needed

# Recreate services one by one
cd /opt/codespartan/apps/cyberdyne-systems-es/www
docker compose up -d
```

### 4. Update Documentation

- [ ] Update main README.md
- [ ] Update CLAUDE.md with new structure
- [ ] Update deployment guides

## Rollback Plan

If issues occur:
1. Old directories are preserved (not deleted)
2. Revert paths in workflows
3. Redeploy from old structure
4. Docker volumes remain intact

## Notes

- **Placeholders created**: Empty subdominios have README.md files for future use
- **No data loss**: Old directories preserved until migration verified
- **Backward compatible**: Can run both structures temporarily during migration
- **Docker volumes**: Will need to be moved/recreated on server

## Testing Checklist

- [ ] Verify all docker-compose.yml files in new locations
- [ ] Test local builds of migrated services
- [ ] Update and test GitHub Actions workflows
- [ ] Deploy to staging first
- [ ] Verify DNS resolution for codespartan.cloud
- [ ] Migrate production services one-by-one
- [ ] Update monitoring/alerting configs
- [ ] Remove old directories after 2 weeks of stable operation
