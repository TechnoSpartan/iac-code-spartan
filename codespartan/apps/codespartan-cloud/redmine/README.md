# Redmine Project Management

Redmine is a flexible project management web application with native Gantt charts, issue tracking, time tracking, and extensive plugin support. This deployment is optimized for low resource consumption.

## Why Redmine over OpenProject?

| Feature | Redmine | OpenProject |
|---------|---------|-------------|
| **Memory Usage** | ~512MB | ~1.2GB+ |
| **CPU Usage** | 0.5 cores | 1.5 cores |
| **Gantt Charts** | Native, built-in | Native, built-in |
| **Resource Savings** | Baseline | +140% more resources |
| **Stability** | Mature (2006) | Newer fork of Redmine |
| **Plugins** | 5000+ available | Limited ecosystem |
| **Self-Hosted** | Active development | Active development |
| **Complexity** | Lighter, simpler | More features, heavier |

**Bottom Line:** Redmine provides the same core features (including Gantt) with **55% less resource consumption** (768MB total vs 1.7GB).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Traefik (Reverse Proxy)              │
│         redmine.codespartan.cloud (HTTPS/SSL)           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
         ┌───────────────────────┐
         │   redmine-app         │
         │   (Redmine 6 Alpine)  │
         │   Port: 3000          │
         │   Mem: 512MB          │
         │   CPU: 0.5            │
         └──────────┬────────────┘
                    │
                    ↓ redmine_internal (172.31.0.0/24)
                    │
         ┌──────────┴────────────┐
         │   redmine-db          │
         │   (PostgreSQL 17)     │
         │   Port: 5432          │
         │   Mem: 256MB          │
         │   CPU: 0.5            │
         └───────────────────────┘
```

## Features

- **Gantt Charts**: Native Gantt chart support with dependencies
- **Issue Tracking**: Flexible issue tracking with custom fields
- **Time Tracking**: Built-in time tracking and reporting
- **Multiple Projects**: Support for unlimited projects
- **Wiki**: Per-project wikis with full text search
- **Forums**: Discussion forums per project
- **File Management**: Document and file management
- **Email Integration**: Email notifications and issue creation via email
- **REST API**: Full REST API for integrations
- **Plugins**: Extensive plugin ecosystem (5000+ plugins)
- **Themes**: Customizable themes
- **RBAC**: Role-based access control
- **LDAP/AD**: LDAP and Active Directory integration

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- VPS with at least 1GB RAM available
- Domain/subdomain configured in DNS

### Local Testing

```bash
# 1. Copy environment file
cp .env.example .env

# 2. Edit .env with your values
nano .env

# 3. Generate secrets
openssl rand -hex 16  # For POSTGRES_PASSWORD
openssl rand -hex 64  # For REDMINE_SECRET_KEY_BASE

# 4. Update .env with generated secrets

# 5. Create networks
docker network create web 2>/dev/null || true
docker network create redmine_internal 2>/dev/null || true

# 6. Start services
docker compose up -d

# 7. View logs
docker logs redmine-app -f
```

### Production Deployment via GitHub Actions

1. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):
   ```
   REDMINE_POSTGRES_PASSWORD=<generated-password>
   REDMINE_SECRET_KEY_BASE=<generated-secret>
   REDMINE_SMTP_PASSWORD=<hostinger-email-password>
   REDMINE_HOSTNAME=redmine.codespartan.cloud
   ```

2. **Add DNS Record** in Hetzner DNS:
   ```
   Type: A
   Name: redmine
   Value: 91.98.137.217
   TTL: 300
   ```

3. **Deploy**:
   - Push changes to `codespartan/apps/codespartan-cloud/redmine/**`
   - Or manually trigger workflow: Actions → Deploy Redmine → Run workflow

4. **Wait 5 minutes** for initial database setup and migrations

5. **Access Redmine**:
   - URL: https://redmine.codespartan.cloud
   - Default credentials:
     - Username: `admin`
     - Password: `admin`
   - **IMPORTANT**: Change password immediately after first login!

## Configuration

### Initial Setup

After first login with `admin/admin`:

1. **Change Admin Password**:
   - Click "My account" (top right)
   - Click "Change password"
   - Enter new secure password

2. **Configure Email Settings**:
   - Administration → Settings → Email notifications
   - Emission email address: `noreply@codespartan.es`
   - Test email delivery

3. **Create Projects**:
   - Administration → Projects → New project
   - Enter project details
   - Enable Gantt module

4. **Configure Gantt**:
   - Navigate to project
   - Click "Gantt" tab
   - Add issues with start/end dates
   - Create dependencies between issues

### Installing Plugins

Plugins are installed in the `/usr/src/redmine/plugins` volume.

**Example: Installing a Gantt enhancement plugin**

```bash
# SSH into VPS
ssh leonidas@91.98.137.217

# Download plugin into plugins volume
docker exec redmine-app sh -c 'cd /usr/src/redmine/plugins && \
  wget https://github.com/plugin/archive.zip && \
  unzip archive.zip && rm archive.zip'

# Run migrations
docker exec redmine-app bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Restart Redmine
docker compose -f /opt/codespartan/apps/codespartan-cloud/redmine/docker-compose.yml restart app
```

**Popular Gantt Plugins:**
- **Redmine Better Gantt Chart**: Enhanced Gantt with critical path, baselines
- **Redmine Gantt List**: List view alongside Gantt
- **Redmine Resources**: Resource planning and allocation

### Installing Themes

Themes are installed in `/usr/src/redmine/public/themes` volume.

```bash
# Download theme
docker exec redmine-app sh -c 'cd /usr/src/redmine/public/themes && \
  git clone https://github.com/theme-repo.git theme-name'

# Apply theme
# Administration → Settings → Display → Theme → Select theme
```

**Popular Themes:**
- **PurpleMine2**: Modern, responsive theme
- **Redmine Alex Skin**: Clean, professional look
- **Circle Theme**: Minimalist design

## Resource Limits

| Container | Memory Limit | CPU Limit | Reservation Memory | Reservation CPU |
|-----------|--------------|-----------|-------------------|-----------------|
| redmine-app | 512M | 0.5 | 128M | 0.1 |
| redmine-db | 256M | 0.5 | 64M | 0.1 |
| **Total** | **768M** | **1.0** | **192M** | **0.2** |

**Comparison with OpenProject:**
- OpenProject Total: 1.7GB RAM, 2.75 CPU
- Redmine Total: 768MB RAM, 1.0 CPU
- **Savings: 55% less memory, 64% less CPU**

## Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `redmine-db-data` | `/var/lib/postgresql/data` | Database persistence |
| `redmine-data` | `/usr/src/redmine/files` | Uploaded files and attachments |
| `redmine-plugins` | `/usr/src/redmine/plugins` | Installed plugins |
| `redmine-themes` | `/usr/src/redmine/public/themes` | Installed themes |

## Network Isolation

- **`web` network**: External network for Traefik routing (internet-facing)
- **`redmine_internal` network**: Isolated internal network (172.31.0.0/24)
  - Only redmine-app and redmine-db communicate here
  - Database is NOT accessible from internet or other applications
  - Maximum security: `internal: true` prevents external access

## Backup and Restore

### Database Backup

```bash
# Create backup
docker exec redmine-db pg_dump -U redmine redmine > redmine_backup_$(date +%Y%m%d_%H%M%S).sql

# Or with compression
docker exec redmine-db pg_dump -U redmine redmine | gzip > redmine_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Database Restore

```bash
# Restore from backup
cat backup.sql | docker exec -i redmine-db psql -U redmine redmine

# Or from compressed backup
gunzip -c backup.sql.gz | docker exec -i redmine-db psql -U redmine redmine
```

### Full Backup (Database + Files)

```bash
# Stop Redmine (optional, for consistency)
docker compose stop app

# Backup database
docker exec redmine-db pg_dump -U redmine redmine > db_backup.sql

# Backup volumes (data, plugins, themes)
docker run --rm \
  -v redmine-data:/data \
  -v redmine-plugins:/plugins \
  -v redmine-themes:/themes \
  -v $(pwd):/backup \
  alpine tar czf /backup/redmine_volumes_$(date +%Y%m%d).tar.gz /data /plugins /themes

# Restart Redmine
docker compose start app
```

## Monitoring

### Container Status

```bash
# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}" | grep redmine

# Expected output:
# redmine-app    Up X hours (healthy)
# redmine-db     Up X hours (healthy)
```

### Logs

```bash
# Real-time logs
docker logs redmine-app -f

# Last 100 lines
docker logs redmine-app --tail 100

# Database logs
docker logs redmine-db --tail 50
```

### Resource Usage

```bash
# Monitor resource consumption
docker stats --no-stream | grep redmine

# Expected usage:
# redmine-app:  ~200-400MB mem, <5% CPU (idle)
# redmine-db:   ~50-150MB mem, <1% CPU (idle)
```

### Health Checks

```bash
# Check database
docker exec redmine-db pg_isready -U redmine

# Check application
curl -I http://localhost:3000/

# Check via Traefik
curl -I https://redmine.codespartan.cloud
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs redmine-app
docker logs redmine-db

# Check environment variables
docker exec redmine-app env | grep REDMINE
```

### Database connection errors

```bash
# Verify database is running
docker ps | grep redmine-db

# Test database connectivity
docker exec redmine-app ping redmine-db

# Check database credentials in .env file
```

### Slow performance

```bash
# Check resource usage
docker stats --no-stream | grep redmine

# If exceeding limits, consider increasing in docker-compose.yml:
# - app: 512M → 768M
# - db: 256M → 384M
```

### Can't access via domain

```bash
# Check Traefik routing
docker logs traefik | grep redmine

# Verify DNS
dig redmine.codespartan.cloud

# Test internal routing
curl -H "Host: redmine.codespartan.cloud" http://localhost
```

### Plugin installation failed

```bash
# Check plugin directory
docker exec redmine-app ls -la /usr/src/redmine/plugins

# Run migrations manually
docker exec redmine-app bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Check logs
docker logs redmine-app --tail 100
```

## Maintenance

### Update Redmine

```bash
# Pull latest image
docker compose pull

# Recreate containers
docker compose down
docker compose up -d

# Check logs
docker logs redmine-app -f
```

### Clear cache

```bash
# Clear Redmine cache
docker exec redmine-app bundle exec rake tmp:cache:clear RAILS_ENV=production

# Restart application
docker compose restart app
```

### Optimize database

```bash
# Vacuum and analyze database
docker exec redmine-db psql -U redmine redmine -c "VACUUM ANALYZE;"
```

## Migration from OpenProject

See `MIGRATION_FROM_OPENPROJECT.md` for detailed migration guide.

**Quick Summary:**
1. Export data from OpenProject (projects, issues, users)
2. Deploy Redmine
3. Import data using Redmine API or CSV import
4. Verify data integrity
5. Decommission OpenProject

## Documentation

- **Official Documentation**: https://www.redmine.org/guide
- **Plugin Directory**: https://www.redmine.org/plugins
- **Theme Directory**: https://www.redmine.org/projects/redmine/wiki/Theme_List
- **REST API**: https://www.redmine.org/projects/redmine/wiki/Rest_api
- **Docker Hub**: https://hub.docker.com/_/redmine

## Support

- **Community Forum**: https://www.redmine.org/projects/redmine/boards
- **Stack Overflow**: https://stackoverflow.com/questions/tagged/redmine
- **GitHub**: https://github.com/redmine/redmine

## Security

- Change default admin password immediately
- Use strong passwords for database and secret keys
- Keep Redmine updated with latest security patches
- Enable HTTPS only (enforced by Traefik)
- Use network isolation (configured by default)
- Regularly backup data
- Monitor logs for suspicious activity

## License

Redmine is open source software released under the GNU General Public License v2 (GPL-2.0).
