# 🚨 Disaster Recovery Plan - CodeSpartan Mambo Cloud

Complete guide for recovering from catastrophic failures.

---

## 📊 Recovery Objectives

### RTO (Recovery Time Objective)
- **Critical Services** (Traefik, Monitoring): 15-30 minutes
- **Full Platform**: 1-2 hours
- **Complete Infrastructure Rebuild**: 2-4 hours

### RPO (Recovery Point Objective)
- **Daily Backups**: Maximum 24 hours data loss
- **VPS Snapshots** (weekly): Maximum 7 days data loss
- **Git Repository**: Near-zero (continuous sync)

---

## 🔄 Backup Strategy

### Automated Daily Backups

**Schedule:** 3:00 AM daily (via cron)

**What's Backed Up:**
- Docker volumes: `victoria-data`, `loki-data`, `grafana-data`
- Platform configs: `/opt/codespartan/platform/`
- SSL certificates: `/opt/codespartan/platform/traefik/letsencrypt/`

**Retention:**
- Local: 7 days (`/opt/codespartan/backups/`)
- Remote: 30 days (if configured)

**Backup Location:**
```bash
/opt/codespartan/backups/backup-YYYY-MM-DD_HH-MM-SS.tar.gz
```

### Manual Backup

```bash
# SSH to server
ssh root@91.98.137.217

# Run backup script manually
/opt/codespartan/scripts/backup.sh

# Verify backup created
ls -lh /opt/codespartan/backups/
```

### Download Backup Locally

```bash
# Download latest backup
scp root@91.98.137.217:/opt/codespartan/backups/backup-*.tar.gz ./
```

### Hetzner Cloud Automated Backups

Hetzner Cloud offers automated server-level backups (full VM snapshots).

**Features:**
- Full VPS snapshots (entire disk image)
- Up to 7 backups retained automatically
- Stored in Hetzner infrastructure (separate from VPS)
- Cost: 20% of server price (~€0.98/month for cax11)
- Can restore or create new servers from backups

**Enable Automated Backups:**

```bash
# Option 1: Using script (recommended)
cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan
HCLOUD_TOKEN=your-token ./codespartan/platform/scripts/enable-hetzner-backups.sh

# Option 2: Via Hetzner Console
# 1. Visit: https://console.hetzner.cloud
# 2. Go to: Servers → codespartan-vps
# 3. Click: "Enable Backups" button
# 4. Confirm cost (~20% of server price)
```

**View Backups:**

```bash
# Via Hetzner Console
# https://console.hetzner.cloud → Servers → codespartan-vps → Backups tab

# Via API
curl -H "Authorization: Bearer $HCLOUD_TOKEN" \
  "https://api.hetzner.cloud/v1/servers/<server-id>/actions" | jq '.actions[] | select(.command == "create_image")'
```

**Restore from Hetzner Backup:**

1. Visit Hetzner Console: https://console.hetzner.cloud
2. Go to: Servers → codespartan-vps → Backups
3. Select the backup to restore
4. Click "Restore" → Confirm
5. Wait 5-10 minutes for restoration
6. Verify services: `ssh root@91.98.137.217 "docker ps"`

**Create Manual Snapshot:**

```bash
# Via Hetzner Console
# 1. Servers → codespartan-vps
# 2. Click "Create Snapshot"
# 3. Enter description (e.g., "Before major update")
# 4. Wait ~5-10 minutes for snapshot creation

# Via API
curl -X POST \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description": "Manual snapshot before update"}' \
  "https://api.hetzner.cloud/v1/servers/<server-id>/actions/create_image"
```

---

## 🆘 Disaster Scenarios & Recovery

### Scenario 1: VPS Completely Lost/Corrupted

**Impact:** Total platform outage
**Recovery Time:** 2-4 hours
**Data Loss:** Up to 24 hours (last daily backup)

#### Recovery Steps:

**Step 1: Provision New Infrastructure (30 min)**

```bash
# Clone repository locally
git clone https://github.com/TechnoSpartan/iac-code-spartan.git
cd iac-code-spartan

# Deploy infrastructure via Terraform
cd codespartan/infra/hetzner
terraform init
terraform apply -auto-approve

# Wait 5-10 minutes for cloud-init to install Docker
```

**Step 2: Deploy Platform Services (15 min)**

```bash
# Trigger GitHub Actions workflows in order:
gh workflow run deploy-traefik.yml
# Wait 2 minutes for Traefik SSL certificates

gh workflow run deploy-monitoring.yml
# Wait 3 minutes for monitoring stack

gh workflow run deploy-backup-system.yml
# Deploys backup/restore scripts
```

**Step 3: Restore Data from Backup (30 min)**

```bash
# SSH to new VPS
ssh root@<new-vps-ip>

# Upload backup file (if you have local copy)
scp backup-YYYY-MM-DD.tar.gz root@<new-vps-ip>:/tmp/

# Restore full platform
/opt/codespartan/scripts/restore.sh /tmp/backup-YYYY-MM-DD.tar.gz --full

# Verify services
docker ps
docker compose -f /opt/codespartan/platform/stacks/monitoring/docker-compose.yml logs -f
```

**Step 4: Update DNS (if IP changed)**

```bash
# Update Terraform variables with new IP
cd codespartan/infra/hetzner
terraform apply  # Updates DNS records automatically
```

**Step 5: Verify All Services**

```bash
# Check all services running
docker ps

# Test URLs
curl -I https://traefik.mambo-cloud.com
curl -I https://grafana.mambo-cloud.com
curl -I https://backoffice.mambo-cloud.com

# Check SSL certificates
echo | openssl s_client -servername grafana.mambo-cloud.com -connect grafana.mambo-cloud.com:443 2>/dev/null | openssl x509 -noout -dates
```

---

### Scenario 2: Data Corruption (Single Service)

**Impact:** Partial outage (e.g., Grafana dashboards lost)
**Recovery Time:** 15-30 minutes
**Data Loss:** Up to 24 hours

#### Recovery Steps:

**Step 1: Stop Affected Service**

```bash
# Example: Grafana corrupted
cd /opt/codespartan/platform/stacks/monitoring
docker compose stop grafana
```

**Step 2: Restore Only Affected Volume**

```bash
# Extract backup
mkdir /tmp/restore
cd /tmp/restore
tar xzf /opt/codespartan/backups/backup-YYYY-MM-DD.tar.gz

# Stop containers using volume
docker compose stop grafana

# Remove corrupted volume
docker volume rm grafana-data

# Restore volume
docker volume create grafana-data
docker run --rm \
  -v grafana-data:/data \
  -v /tmp/restore/volumes/grafana-data:/backup:ro \
  alpine:latest \
  tar xzf /backup/data.tar.gz -C /data

# Restart service
docker compose up -d grafana
```

**Step 3: Verify**

```bash
docker logs grafana -f
curl -I https://grafana.mambo-cloud.com
```

---

### Scenario 3: SSL Certificates Lost/Corrupted

**Impact:** HTTPS not working
**Recovery Time:** 10-15 minutes
**Data Loss:** None

#### Recovery Steps:

**Option A: Restore from Backup**

```bash
# Extract SSL certs from backup
mkdir /tmp/ssl-restore
tar xzf /opt/codespartan/backups/backup-YYYY-MM-DD.tar.gz -C /tmp/ssl-restore ssl/

# Stop Traefik
cd /opt/codespartan/platform/traefik
docker compose down

# Restore certificates
rm -rf letsencrypt/
cp -r /tmp/ssl-restore/ssl/letsencrypt/ ./letsencrypt/
chmod 600 letsencrypt/acme.json

# Start Traefik
docker compose up -d
```

**Option B: Regenerate Certificates**

```bash
# Stop Traefik
cd /opt/codespartan/platform/traefik
docker compose down

# Remove old certificates
rm -rf letsencrypt/acme.json

# Restart Traefik (will request new certs from Let's Encrypt)
docker compose up -d

# Watch logs (certificates take 1-2 minutes)
docker logs traefik -f
```

---

### Scenario 4: Accidental Service Deletion

**Impact:** Service down
**Recovery Time:** 5-10 minutes
**Data Loss:** None (if volumes intact)

#### Recovery Steps:

```bash
# Redeploy via GitHub Actions
gh workflow run deploy-monitoring.yml
# or
gh workflow run deploy-backoffice.yml

# OR manually from platform directory
cd /opt/codespartan/platform/stacks/monitoring
docker compose up -d
```

---

### Scenario 5: Disk Full / Out of Space

**Impact:** Services failing, backups failing
**Recovery Time:** 10-20 minutes
**Data Loss:** Potential (if services can't write)

#### Recovery Steps:

**Step 1: Identify Space Usage**

```bash
# Check disk usage
df -h

# Find largest directories
du -sh /var/lib/docker/* | sort -hr | head -10
du -sh /opt/codespartan/* | sort -hr | head -10
```

**Step 2: Clean Up**

```bash
# Remove old Docker images/containers
docker system prune -af --volumes

# Remove old backups (keep last 2)
cd /opt/codespartan/backups
ls -t backup-*.tar.gz | tail -n +3 | xargs rm -f

# Clean Docker logs
truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

**Step 3: Verify Space Freed**

```bash
df -h
```

**Step 4: Restart Services**

```bash
cd /opt/codespartan/platform/stacks/monitoring
docker compose restart
```

---

### Scenario 6: Configuration File Corrupted

**Impact:** Service not starting correctly
**Recovery Time:** 5-10 minutes
**Data Loss:** None

#### Recovery Steps:

**Option A: Restore from Backup**

```bash
# Extract configs from backup
mkdir /tmp/config-restore
tar xzf /opt/codespartan/backups/backup-YYYY-MM-DD.tar.gz -C /tmp/config-restore platform/

# Copy affected config
cp /tmp/config-restore/platform/stacks/monitoring/docker-compose.yml \
   /opt/codespartan/platform/stacks/monitoring/docker-compose.yml

# Restart service
cd /opt/codespartan/platform/stacks/monitoring
docker compose up -d
```

**Option B: Redeploy from Git**

```bash
# Pull latest from GitHub
cd /opt/codespartan
git pull origin main

# Restart affected service
cd platform/stacks/monitoring
docker compose up -d
```

---

### Scenario 7: GitHub Repository Lost

**Impact:** Cannot redeploy infrastructure
**Recovery Time:** 1-2 hours
**Data Loss:** None (if VPS still running)

#### Recovery Steps:

**Step 1: Backup VPS State**

```bash
# Create manual backup immediately
ssh root@91.98.137.217 "/opt/codespartan/scripts/backup.sh"

# Download backup locally
scp root@91.98.137.217:/opt/codespartan/backups/backup-*.tar.gz ./
```

**Step 2: Recreate Repository**

```bash
# SSH to VPS and tar entire platform directory
ssh root@91.98.137.217 "tar czf /tmp/platform-export.tar.gz /opt/codespartan/platform"
scp root@91.98.137.217:/tmp/platform-export.tar.gz ./

# Create new repo
git init iac-code-spartan-recovered
cd iac-code-spartan-recovered

# Extract and commit
tar xzf ../platform-export.tar.gz
git add .
git commit -m "chore: recover infrastructure from VPS backup"
```

**Step 3: Restore Terraform State**

```bash
# SSH to VPS - check if Terraform state exists
ssh root@91.98.137.217 "ls -la /opt/codespartan/infra/hetzner/"

# If terraform.tfstate exists, download it
scp root@91.98.137.217:/opt/codespartan/infra/hetzner/terraform.tfstate ./

# Import existing infrastructure
cd codespartan/infra/hetzner
terraform init
# Copy downloaded terraform.tfstate to current directory
terraform plan  # Should show no changes
```

---

## 📋 Recovery Checklists

### Pre-Disaster Checklist

- [ ] Daily backups running successfully (check logs: `/var/log/codespartan-backup.log`)
- [ ] At least 3 recent backups available locally
- [ ] Latest backup downloaded to local machine (monthly)
- [ ] GitHub repository accessible and up-to-date
- [ ] All credentials documented and accessible (password manager)
- [ ] Hetzner Cloud API tokens saved securely
- [ ] SSH keys backed up offline

### Post-Recovery Checklist

- [ ] All containers running: `docker ps` (expect 10 containers)
- [ ] Traefik accessible: https://traefik.mambo-cloud.com
- [ ] Grafana accessible: https://grafana.mambo-cloud.com
- [ ] Grafana shows metrics (query: `up`)
- [ ] Grafana shows logs (Loki datasource working)
- [ ] Backoffice accessible: https://backoffice.mambo-cloud.com
- [ ] SSL certificates valid (check browser)
- [ ] Alerts working (send test: `curl -d "Test" https://ntfy.sh/codespartan-mambo-alerts`)
- [ ] Backup cron job configured: `crontab -l | grep backup`
- [ ] DNS resolving correctly: `dig grafana.mambo-cloud.com`

---

## 🔧 Useful Commands

### Check Backup Status

```bash
# View backup logs
ssh root@91.98.137.217 "tail -100 /var/log/codespartan-backup.log"

# List all backups
ssh root@91.98.137.217 "ls -lh /opt/codespartan/backups/"

# Show backup info
ssh root@91.98.137.217 "tar tzf /opt/codespartan/backups/backup-*.tar.gz | head -20"
```

### Restore Commands

```bash
# Full restore
/opt/codespartan/scripts/restore.sh /path/to/backup.tar.gz --full

# Only volumes
/opt/codespartan/scripts/restore.sh /path/to/backup.tar.gz --volumes-only

# Only configs
/opt/codespartan/scripts/restore.sh /path/to/backup.tar.gz --configs-only
```

### Emergency Diagnostics

```bash
# Check all services
docker ps -a

# Check service health
docker compose -f /opt/codespartan/platform/stacks/monitoring/docker-compose.yml ps

# View logs
docker logs traefik --tail 100
docker logs grafana --tail 100
docker logs vmalert --tail 100

# Check disk space
df -h

# Check memory
free -h

# Check CPU
top
```

---

## 📞 Emergency Contacts

**Hetzner Support:**
- Email: support@hetzner.com
- Phone: +49 9831 505-0
- Portal: https://console.hetzner.cloud

**Domain Registrar (Hetzner DNS):**
- Portal: https://dns.hetzner.com

**GitHub Support:**
- https://support.github.com

---

## 📚 Additional Resources

- [Backup Script](/codespartan/platform/scripts/backup.sh)
- [Restore Script](/codespartan/platform/scripts/restore.sh)
- [Infrastructure Terraform](/codespartan/infra/hetzner/)
- [Platform Configurations](/codespartan/platform/)
- [Monitoring Documentation](/codespartan/platform/stacks/monitoring/ALERTS.md)

---

**Last Updated:** 2025-10-05
**Version:** 1.0
**Maintained By:** CodeSpartan DevOps Team
