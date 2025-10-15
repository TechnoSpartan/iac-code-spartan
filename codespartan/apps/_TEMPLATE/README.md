# Application Template

This is a template for deploying containerized applications to the CodeSpartan Mambo Cloud Platform.

## 📋 Quick Start

1. **Copy this template to a new directory:**
   ```bash
   cp -r codespartan/apps/_TEMPLATE codespartan/apps/your-app-name
   cd codespartan/apps/your-app-name
   ```

2. **Configure your application:**
   ```bash
   # Copy and edit environment variables
   cp .env.example .env
   nano .env
   ```

3. **Customize `docker-compose.yml`:**
   - Change `image` to your application image
   - Update `APP_NAME` and `SUBDOMAIN`
   - Adjust `APP_PORT` to match your application
   - Customize healthcheck command
   - Add volumes, databases, or other services as needed

4. **Add subdomain to Terraform:**
   Edit `codespartan/infra/hetzner/terraform.tfvars`:
   ```hcl
   subdomains = [
     "traefik",
     "grafana",
     "backoffice",
     "www",
     "staging",
     "lab",
     "your-subdomain"  # Add your subdomain here
   ]
   ```

5. **Deploy infrastructure changes:**
   ```bash
   cd codespartan/infra/hetzner
   terraform plan
   terraform apply
   ```

6. **Deploy your application:**
   ```bash
   # Via GitHub Actions (recommended):
   git add .
   git commit -m "Add new app: your-app-name"
   git push

   # Or manually via SSH:
   ssh leonidas@91.98.137.217
   cd /opt/codespartan/apps/your-app-name
   docker compose pull
   docker compose up -d
   ```

## 🏗️ Template Structure

```
_TEMPLATE/
├── docker-compose.yml    # Docker Compose configuration with Traefik labels
├── .env.example          # Environment variables template
├── healthcheck.sh        # Health check script for monitoring
└── README.md            # This file
```

## 🔧 Configuration Options

### Environment Variables

The template supports these key variables in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Application name (container prefix) | `myapp` |
| `SUBDOMAIN` | Subdomain for Traefik routing | `app` |
| `APP_PORT` | Internal application port | `80` |
| `NODE_ENV` | Environment mode | `production` |

### Traefik Labels

The template includes these Traefik features:

- ✅ **Automatic SSL** via Let's Encrypt
- ✅ **Custom subdomain** routing (`your-subdomain.mambo-cloud.com`)
- ⚙️ **Optional Basic Auth** (uncomment to enable)
- ⚙️ **Optional Rate Limiting** (uncomment to enable)

### Health Checks

The `healthcheck.sh` script provides:

- HTTP endpoint checking
- TCP port verification
- Process monitoring
- Retry logic with configurable delays

Customize the healthcheck based on your application:

```yaml
healthcheck:
  test: ["CMD", "/app/healthcheck.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## 📦 Common Application Stacks

### Node.js Application

```yaml
image: node:18-alpine
environment:
  - NODE_ENV=production
  - PORT=3000
volumes:
  - ./src:/app/src:ro
  - ./package.json:/app/package.json:ro
working_dir: /app
command: ["npm", "start"]
```

### Python/Flask Application

```yaml
image: python:3.11-slim
environment:
  - FLASK_ENV=production
  - FLASK_APP=app.py
volumes:
  - ./app:/app
working_dir: /app
command: ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
```

### Static Website (Nginx)

```yaml
image: nginx:alpine
volumes:
  - ./html:/usr/share/nginx/html:ro
  - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

## 🗄️ Adding a Database

Uncomment the database service in `docker-compose.yml` and configure:

### PostgreSQL

```yaml
database:
  image: postgres:15-alpine
  environment:
    - POSTGRES_USER=appuser
    - POSTGRES_PASSWORD=strong_password_here
    - POSTGRES_DB=appdb
  volumes:
    - db-data:/var/lib/postgresql/data
  networks:
    - backend
```

### MySQL

```yaml
database:
  image: mysql:8-oracle
  environment:
    - MYSQL_ROOT_PASSWORD=root_password_here
    - MYSQL_DATABASE=appdb
    - MYSQL_USER=appuser
    - MYSQL_PASSWORD=strong_password_here
  volumes:
    - db-data:/var/lib/mysql
  networks:
    - backend
```

### Redis

```yaml
redis:
  image: redis:7-alpine
  command: redis-server --requirepass your_redis_password
  volumes:
    - redis-data:/data
  networks:
    - backend
```

## 🚀 Deployment

### Option 1: GitHub Actions (Recommended)

1. Create workflow file `.github/workflows/deploy-your-app.yml`
2. Copy from `_template-deploy.yml` and customize
3. Push to GitHub - automatic deployment on changes

### Option 2: Manual Deployment

```bash
# SSH into VPS
ssh leonidas@91.98.137.217

# Navigate to app directory
cd /opt/codespartan/apps/your-app-name

# Pull latest images
docker compose pull

# Deploy
docker compose up -d

# Check logs
docker logs your-app-name-app -f
```

## 🔍 Troubleshooting

### App not accessible

```bash
# Check container is running
docker ps | grep your-app-name

# View logs
docker logs your-app-name-app

# Check Traefik routing
docker logs traefik | grep your-subdomain

# Test internal routing
curl -H "Host: your-subdomain.mambo-cloud.com" http://localhost
```

### SSL certificate issues

```bash
# Check Traefik dashboard
https://traefik.mambo-cloud.com

# View certificate files
docker exec traefik ls -la /letsencrypt/

# Force certificate regeneration (careful!)
docker exec traefik rm /letsencrypt/acme.json
docker restart traefik
```

### Container restarts continuously

```bash
# View container logs
docker logs your-app-name-app --tail 100

# Check healthcheck status
docker inspect your-app-name-app | grep -A 10 Health

# Run healthcheck manually
docker exec your-app-name-app /app/healthcheck.sh
```

## 📊 Monitoring

Your application is automatically monitored by:

- **VictoriaMetrics**: Container metrics (CPU, RAM, network)
- **Loki**: Centralized logging
- **Grafana**: Dashboards at https://grafana.mambo-cloud.com
- **cAdvisor**: Container statistics
- **Node Exporter**: System metrics

View your app logs in Grafana → Explore → Loki:
```
{container_name="your-app-name-app"}
```

## 🔒 Security Best Practices

1. **Never commit `.env` files** - Use `.env.example` instead
2. **Use strong passwords** - Generate with `openssl rand -base64 32`
3. **Enable basic auth** for admin interfaces
4. **Set resource limits** to prevent resource exhaustion
5. **Keep images updated** - Use `docker compose pull` regularly
6. **Review logs** for suspicious activity

## 📚 Additional Resources

- [Platform Documentation](../../docs/RUNBOOK.md)
- [Adding Apps Guide](../../docs/ADDING_APPS.md)
- [Troubleshooting Guide](../../DEPLOY.md)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

## 🆘 Support

If you encounter issues:

1. Check container logs: `docker logs your-app-name-app`
2. Check Traefik logs: `docker logs traefik`
3. Run diagnostics: `/opt/codespartan/scripts/diagnostics.sh`
4. Review monitoring dashboards in Grafana

---

**Last Updated:** 2025-10-08
**Version:** 1.0.0
