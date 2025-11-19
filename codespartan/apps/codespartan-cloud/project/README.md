# OpenProject - Project Management Platform

OpenProject deployment for CodeSpartan Cloud at `project.codespartan.cloud`.

## Overview

OpenProject is a powerful open-source project management software that includes:
- Task management and Gantt charts
- Agile boards (Scrum & Kanban)
- Time tracking and cost reporting
- Team collaboration and wikis
- Meeting management
- Bug tracking

## Architecture

```
┌─────────────────────────────────────────┐
│  Traefik (Reverse Proxy + SSL)         │
│  project.codespartan.cloud              │
└───────────┬─────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│  OpenProject App (Port 8080)            │
│  - Rails application                     │
│  - Web interface                         │
└───────┬─────────────┬───────────────────┘
        │             │
        ▼             ▼
┌─────────────┐  ┌─────────────┐
│ PostgreSQL  │  │  Memcached  │
│  Database   │  │    Cache    │
└─────────────┘  └─────────────┘
```

## Network Isolation

- **web**: External network for Traefik routing (shared across all services)
- **openproject_internal**: Isolated network (172.30.0.0/24) for internal communication
  - Database and cache are NOT accessible from the internet
  - Only the app container is exposed via Traefik
  - Follows CodeSpartan Zero Trust architecture principles

## Resource Allocation

| Service     | Memory Limit | CPU Limit | Reserved | Purpose |
|-------------|--------------|-----------|----------|---------|
| App         | 1.5GB        | 1.5       | 256MB    | Rails application (supports 100+ users) |
| PostgreSQL  | 512MB        | 0.75      | 128MB    | Database (efficient with caching) |
| Memcached   | 128MB        | 0.5       | 32MB     | Session/query caching |

**Total OpenProject**: 2.1GB (optimized to leave 1.1GB margin)

### VPS Resource Analysis

```
VPS Total:          3.4GB (4GB with OS)
Platform (Traefik, Monitoring):  ~3.9GB limit / 763MB actual
OpenProject:        2.1GB limit / 350MB actual
Total Limits:       6.0GB (safe overcommitment)
Total Usage:        ~1.1GB (32% utilization) ✅ SAFE
Remaining Margin:   2.3GB (68% free) ✅ EXCELLENT
```

⚠️ **Resource Integrity Check**: System is safe. If app grows beyond 350MB, memory will be freed automatically.

## Initial Setup

### 1. Create Environment File

Copy the example configuration and update with your values:

```bash
cp .env.example .env
```

Then edit `.env` and update these critical values:

```bash
# Generate strong passwords:
openssl rand -hex 16  # For POSTGRES_PASSWORD
openssl rand -hex 64  # For OPENPROJECT_SECRET__KEY__BASE

# Edit .env with values:
TRAEFIK_HOSTNAME=project.codespartan.cloud
POSTGRES_PASSWORD=your_strong_password_here
OPENPROJECT_SECRET__KEY__BASE=your_random_64_char_string_here
```

### 2. Configure Email (Hostinger SMTP)

Update these in `.env` with your Hostinger email credentials:

```bash
OPENPROJECT_SMTP__ADDRESS=smtp.hostinger.com
OPENPROJECT_SMTP__PORT=465
OPENPROJECT_SMTP__USER__NAME=noreply@codespartan.es
OPENPROJECT_SMTP__PASSWORD=your_hostinger_email_password
OPENPROJECT_SMTP__ENABLE__STARTTLS=false
```

**Hostinger Configuration:**

1. **Get password from Hostinger Control Panel:**
   - Log in to Hostinger → Email → noreply@codespartan.es
   - Find "SMTP Password" or "Mail Password"
   - Use this password in `OPENPROJECT_SMTP__PASSWORD`

2. **SMTP Details:**
   - **Server**: smtp.hostinger.com
   - **Port**: 465 (implicit TLS - most secure)
   - **Authentication**: Login
   - **Encryption**: SSL/TLS (automatic with port 465)
   - **Email**: noreply@codespartan.es

3. **Test email configuration:**
   - After deploying, go to Administration → System settings → Email
   - Click "Send test email" to verify it works

## Secret Management

### ⚠️ IMPORTANT: .env File Security

**The `.env` file is NOT committed to git** (configured in `.gitignore`):
- `.env` - Production secrets (IGNORED - never commit)
- `.env.example` - Template only (committed to show configuration)

### GitHub Secrets Setup (For Automated Deployment)

For GitHub Actions to deploy OpenProject, add these secrets:

1. Go to **GitHub Repo → Settings → Secrets and variables → Actions**
2. Click **"New repository secret"** and add:

| Secret Name | Value | Where to get |
|---|---|---|
| `OPENPROJECT_POSTGRES_PASSWORD` | Strong database password | Generate: `openssl rand -hex 16` |
| `OPENPROJECT_SECRET_KEY_BASE` | Rails secret (64 chars) | Generate: `openssl rand -hex 64` |
| `OPENPROJECT_SMTP_PASSWORD` | Hostinger email password | From Hostinger Control Panel |

The workflow will automatically substitute these values.

## Deployment

### Manual Deployment

```bash
# SSH to server
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217

# Create directory
mkdir -p /opt/codespartan/apps/codespartan-cloud/project

# Copy files from repo
# Option 1: If you have the files locally
scp -r codespartan/apps/codespartan-cloud/project/* \
  leonidas@91.98.137.217:/opt/codespartan/apps/codespartan-cloud/project/

# Create .env from template
cd /opt/codespartan/apps/codespartan-cloud/project
cp .env.example .env

# Edit with your real values
nano .env
# Update:
# - POSTGRES_PASSWORD (strong, unique)
# - OPENPROJECT_SECRET__KEY__BASE (run: openssl rand -hex 64)
# - OPENPROJECT_SMTP__PASSWORD (from Hostinger)

# Deploy
docker network create web || true
docker network create openproject_internal || true
docker compose up -d

# Check logs
docker logs openproject-app -f
```

### Via GitHub Actions

(To be implemented)

## First Access

1. Navigate to: https://project.codespartan.cloud
2. Wait for initial setup (1-2 minutes on first launch)
3. Default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
4. **IMPORTANT**: Change the admin password immediately after first login!

## Post-Installation Configuration

1. **Change admin password**
   - Login → Avatar (top-right) → Administration → Users → admin → Change password

2. **Configure system settings**
   - Administration → System settings
   - Set proper host name, email settings, etc.

3. **Create projects**
   - + Project → New project

4. **Invite team members**
   - Project → Members → + Member

## Backup Strategy

### Database Backup

```bash
# Manual backup
docker exec openproject-db pg_dump -U openproject openproject > openproject_backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
cat backup.sql | docker exec -i openproject-db psql -U openproject openproject
```

### Volume Backup

Important volumes:
- `openproject-db-data`: PostgreSQL data
- `openproject-data`: Application assets
- `openproject-attachments`: User-uploaded files

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs openproject-app --tail 100

# Check database connection
docker exec openproject-db pg_isready -U openproject

# Restart services
docker compose restart
```

### Performance issues

- Check memory usage: `docker stats openproject-app`
- Increase resource limits if needed
- Check cache status: `docker logs openproject-cache`

### SSL certificate issues

- Check Traefik logs: `docker logs traefik | grep project.codespartan.cloud`
- Verify DNS: `dig project.codespartan.cloud +short`
- Wait 2-5 minutes for certificate generation
- Verify Let's Encrypt: `docker exec traefik ls -la /letsencrypt/certs/ | grep codespartan`

## Upgrade

```bash
cd /opt/codespartan/apps/openproject

# Pull new image
docker compose pull

# Recreate containers
docker compose up -d

# Check logs for migration status
docker logs openproject-app -f
```

## Health Checks

- App: `http://localhost:8080/health_checks/default`
- Database: `pg_isready -U openproject`
- Cache: `nc -z localhost 11211`

## Default Ports

- App (internal): 8080 → Exposed via Traefik HTTPS at project.codespartan.cloud
- PostgreSQL (internal): 5432 → NOT exposed
- Memcached (internal): 11211 → NOT exposed

## DNS Configuration

Ensure that `project.codespartan.cloud` DNS record points to your VPS IP:
- A record: `project.codespartan.cloud` → `91.98.137.217` (Hetzner VPS)
- Or CNAME: `project.codespartan.cloud` → `codespartan.cloud`

Verify DNS resolution:
```bash
dig project.codespartan.cloud +short
# Should return: 91.98.137.217
```

## Documentation

- Official docs: https://www.openproject.org/docs/
- Installation guide: https://www.openproject.org/docs/installation-and-operations/
- API documentation: https://www.openproject.org/docs/api/

## Security Notes

1. Change default admin password immediately after first login
2. Configure 2FA for admin accounts
3. Use strong database passwords
4. Keep OpenProject updated to latest stable version
5. Regular backups of database and attachments
6. Review user permissions regularly

## Support

For issues specific to this deployment, check:
- Container logs: `docker logs openproject-app`
- Traefik routing: `docker logs traefik | grep openproject`
- Database status: `docker exec openproject-db pg_isready`
