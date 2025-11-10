# OpenProject - Project Management Platform

OpenProject deployment for Cyberdyne Systems at `project.cyberdyne-systems.es`.

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
│  project.cyberdyne-systems.es           │
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

- **web**: External network for Traefik routing
- **openproject_internal**: Isolated network (172.26.0.0/24) for internal communication
  - Database and cache are NOT accessible from the internet
  - Only the app container is exposed via Traefik

## Resource Allocation

| Service     | Memory Limit | CPU Limit | Reserved Memory |
|-------------|--------------|-----------|-----------------|
| App         | 2GB          | 2.0       | 512MB           |
| PostgreSQL  | 1GB          | 1.0       | 256MB           |
| Memcached   | 256MB        | 0.5       | 64MB            |

Total: ~3.25GB (within VPS capacity)

## Initial Setup

### 1. Configure Secrets

Before deploying, update these environment variables in `docker-compose.yml`:

```yaml
# PostgreSQL password
POSTGRES_PASSWORD: "openproject_secure_password_change_me"

# Rails secret key (generate with: openssl rand -hex 64)
OPENPROJECT_SECRET__KEY__BASE: "change-this-to-a-long-random-string-min-30-chars"
```

### 2. Configure Email (Optional)

For email notifications, uncomment and configure SMTP settings:

```yaml
OPENPROJECT_EMAIL__DELIVERY__METHOD: "smtp"
OPENPROJECT_SMTP__ADDRESS: "smtp.example.com"
OPENPROJECT_SMTP__PORT: "587"
OPENPROJECT_SMTP__DOMAIN: "cyberdyne-systems.es"
OPENPROJECT_SMTP__AUTHENTICATION: "login"
OPENPROJECT_SMTP__USER__NAME: "noreply@cyberdyne-systems.es"
OPENPROJECT_SMTP__PASSWORD: "your-smtp-password"
```

## Deployment

### Manual Deployment

```bash
# SSH to server
ssh leonidas@91.98.137.217

# Create directory
sudo mkdir -p /opt/codespartan/apps/openproject

# Copy docker-compose.yml to server
# (use scp or copy content manually)

# Deploy
cd /opt/codespartan/apps/openproject
docker compose up -d

# Check logs
docker logs openproject-app -f
```

### Via GitHub Actions

(To be implemented)

## First Access

1. Navigate to: https://project.cyberdyne-systems.es
2. Default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
3. **IMPORTANT**: Change the admin password immediately!

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

- Check Traefik logs: `docker logs traefik | grep project.cyberdyne-systems.es`
- Verify DNS: `dig project.cyberdyne-systems.es +short`
- Wait 2-5 minutes for certificate generation

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

- App (internal): 8080 → Exposed via Traefik HTTPS
- PostgreSQL (internal): 5432 → NOT exposed
- Memcached (internal): 11211 → NOT exposed

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
