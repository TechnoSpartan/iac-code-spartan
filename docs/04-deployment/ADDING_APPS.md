# Adding New Applications Guide

Complete step-by-step guide for deploying new applications to the CodeSpartan Mambo Cloud Platform.

## 📋 Prerequisites

Before adding a new application, ensure you have:

- ✅ Access to the GitHub repository
- ✅ SSH access to the VPS: `ssh leonidas@91.98.137.217`
- ✅ Docker image or Dockerfile for your application
- ✅ Understanding of required environment variables
- ✅ Chosen subdomain name (e.g., `myapp.mambo-cloud.com`)

## 🚀 Quick Start (5 Steps)

### 1. Copy the Template

```bash
# From project root
cp -r codespartan/apps/_TEMPLATE codespartan/apps/your-app-name
cd codespartan/apps/your-app-name
```

### 2. Configure Application

Edit `docker-compose.yml`:
```yaml
image: your-docker-image:latest  # Change this
container_name: your-app-name-app  # Change this
environment:
  - APP_NAME=your-app-name  # Change this
  - SUBDOMAIN=myapp  # Change this to your subdomain
  - APP_PORT=3000  # Change to your app's port
```

Create `.env` from `.env.example`:
```bash
cp .env.example .env
nano .env  # Edit with your values
```

### 3. Add Subdomain to Terraform

Edit `codespartan/infra/hetzner/terraform.tfvars`:
```hcl
subdomains = [
  "traefik",
  "grafana",
  "backoffice",
  "www",
  "staging",
  "lab",
  "myapp"  # Add your subdomain here
]
```

Apply Terraform changes:
```bash
cd codespartan/infra/hetzner
terraform init
terraform plan
terraform apply
```

Wait 2-5 minutes for DNS propagation. Verify:
```bash
dig myapp.mambo-cloud.com
```

### 4. Create GitHub Actions Workflow

Copy workflow template:
```bash
cp .github/workflows/_template-deploy.yml .github/workflows/deploy-your-app-name.yml
```

Replace all `YOUR_APP_NAME` with your app name:
```bash
# Use sed or manually edit
sed -i '' 's/YOUR_APP_NAME/your-app-name/g' .github/workflows/deploy-your-app-name.yml
```

### 5. Deploy

Commit and push:
```bash
git add .
git commit -m "feat: add your-app-name application"
git push origin main
```

GitHub Actions will automatically deploy your app!

Check deployment status:
- GitHub Actions: https://github.com/your-org/iac-code-spartan/actions
- Your app: https://myapp.mambo-cloud.com
- Traefik dashboard: https://traefik.mambo-cloud.com

---

## 📚 Detailed Guide

### Application Types

Choose the appropriate configuration based on your application type:

#### Static Website (HTML/CSS/JS)

```yaml
services:
  app:
    image: nginx:alpine
    container_name: myapp-app
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro  # Optional custom config
    labels:
      - traefik.http.services.myapp.loadbalancer.server.port=80
```

#### Node.js Application

```yaml
services:
  app:
    image: node:18-alpine
    container_name: myapp-app
    working_dir: /app
    command: ["npm", "start"]
    environment:
      - NODE_ENV=production
      - PORT=3000
    volumes:
      - ./src:/app/src:ro
      - ./package.json:/app/package.json:ro
      - ./package-lock.json:/app/package-lock.json:ro
    labels:
      - traefik.http.services.myapp.loadbalancer.server.port=3000
```

#### Python/Flask Application

```yaml
services:
  app:
    image: python:3.11-slim
    container_name: myapp-app
    working_dir: /app
    command: ["gunicorn", "-b", "0.0.0.0:5000", "-w", "4", "app:app"]
    environment:
      - FLASK_ENV=production
      - PYTHONUNBUFFERED=1
    volumes:
      - ./app:/app
      - ./requirements.txt:/app/requirements.txt:ro
    labels:
      - traefik.http.services.myapp.loadbalancer.server.port=5000
```

#### Go Application

```yaml
services:
  app:
    image: golang:1.21-alpine
    container_name: myapp-app
    working_dir: /app
    command: ["./main"]
    environment:
      - GIN_MODE=release
    volumes:
      - ./main:/app/main
    labels:
      - traefik.http.services.myapp.loadbalancer.server.port=8080
```

### Adding a Database

Most applications need a database. Add it as an additional service:

#### PostgreSQL

```yaml
services:
  app:
    # ... your app config
    depends_on:
      - database
    environment:
      - DATABASE_URL=postgresql://appuser:password@database:5432/appdb
    networks:
      - web
      - backend

  database:
    image: postgres:15-alpine
    container_name: myapp-db
    environment:
      - POSTGRES_USER=appuser
      - POSTGRES_PASSWORD=${DB_PASSWORD}  # Use .env
      - POSTGRES_DB=appdb
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  web:
    external: true
  backend:
    driver: bridge

volumes:
  db-data:
```

Add to `.env`:
```bash
DB_PASSWORD=generate_strong_password_here
```

#### MySQL

```yaml
database:
  image: mysql:8-oracle
  container_name: myapp-db
  environment:
    - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
    - MYSQL_DATABASE=appdb
    - MYSQL_USER=appuser
    - MYSQL_PASSWORD=${DB_PASSWORD}
  volumes:
    - db-data:/var/lib/mysql
  networks:
    - backend
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval: 10s
    timeout: 5s
    retries: 5
```

#### Redis

```yaml
redis:
  image: redis:7-alpine
  container_name: myapp-redis
  command: redis-server --requirepass ${REDIS_PASSWORD}
  volumes:
    - redis-data:/data
  networks:
    - backend
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Security Configuration

#### Basic Authentication

Protect admin interfaces with basic auth:

1. Generate credentials:
```bash
# Install htpasswd (if not installed)
sudo apt-get install apache2-utils

# Generate hash (escape $ as $$)
echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g
```

2. Add to `.env`:
```bash
BASIC_AUTH_USERS=admin:$$apr1$$xyz123$$...
```

3. Uncomment in `docker-compose.yml`:
```yaml
labels:
  - traefik.http.routers.myapp.middlewares=auth
  - traefik.http.middlewares.auth.basicauth.users=${BASIC_AUTH_USERS}
```

#### Rate Limiting

Prevent abuse with rate limiting:

```yaml
labels:
  - traefik.http.routers.myapp.middlewares=ratelimit
  - traefik.http.middlewares.ratelimit.ratelimit.average=100
  - traefik.http.middlewares.ratelimit.ratelimit.burst=50
  - traefik.http.middlewares.ratelimit.ratelimit.period=1s
```

#### CORS Headers

Enable CORS for API endpoints:

```yaml
labels:
  - traefik.http.routers.myapp.middlewares=cors
  - traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE,OPTIONS
  - traefik.http.middlewares.cors.headers.accesscontrolalloworiginlist=https://yourdomain.com
  - traefik.http.middlewares.cors.headers.accesscontrolmaxage=100
  - traefik.http.middlewares.cors.headers.addvaryheader=true
```

### Resource Limits

Prevent any single app from consuming all resources:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.0'      # Max 1 CPU core
          memory: 512M     # Max 512MB RAM
        reservations:
          cpus: '0.25'     # Guaranteed 0.25 CPU
          memory: 128M     # Guaranteed 128MB RAM
```

### Health Checks

Ensure Docker knows when your app is healthy:

```yaml
healthcheck:
  # HTTP endpoint check
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]

  # Or curl
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]

  # Or custom script
  test: ["CMD", "/app/healthcheck.sh"]

  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Environment Variables

Best practices for managing secrets:

#### Option 1: .env file (Simple)

```bash
# Create .env (DO NOT commit to git)
echo "DB_PASSWORD=$(openssl rand -base64 32)" > .env
echo "API_KEY=your_api_key" >> .env
```

```yaml
# Reference in docker-compose.yml
env_file:
  - .env
```

#### Option 2: GitHub Secrets (Recommended)

1. Add secrets in GitHub: Settings → Secrets → Actions
2. Use in workflow:

```yaml
- name: Create .env file on VPS
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.VPS_SSH_HOST }}
    username: ${{ secrets.VPS_SSH_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    script: |
      cat > /opt/codespartan/apps/myapp/.env << 'EOF'
      DB_PASSWORD=${{ secrets.MYAPP_DB_PASSWORD }}
      API_KEY=${{ secrets.MYAPP_API_KEY }}
      EOF
```

### Custom Domains

To use a custom domain instead of subdomain:

1. Add DNS records in your domain registrar:
```
Type: A
Name: @ (or www)
Value: 91.98.137.217
TTL: 3600
```

2. Update Traefik labels:
```yaml
labels:
  - traefik.http.routers.myapp.rule=Host(`yourdomain.com`) || Host(`www.yourdomain.com`)
```

3. Add to Terraform (optional):
```hcl
# codespartan/infra/hetzner/main.tf
# Add custom domain management if needed
```

---

## 🔧 Manual Deployment (Alternative)

If you prefer manual deployment without GitHub Actions:

### 1. SSH to VPS

```bash
ssh leonidas@91.98.137.217
```

### 2. Create App Directory

```bash
sudo mkdir -p /opt/codespartan/apps/myapp
sudo chown leonidas:leonidas /opt/codespartan/apps/myapp
cd /opt/codespartan/apps/myapp
```

### 3. Create Files

```bash
# Create docker-compose.yml
nano docker-compose.yml

# Create .env
nano .env

# Make scripts executable
chmod +x healthcheck.sh
```

### 4. Deploy

```bash
# Ensure web network exists
docker network create web || true

# Pull images
docker compose pull

# Start containers
docker compose up -d

# Check logs
docker logs myapp-app -f
```

---

## ✅ Verification Checklist

After deployment, verify everything works:

- [ ] **DNS Resolution**
  ```bash
  dig myapp.mambo-cloud.com
  # Should return: 91.98.137.217
  ```

- [ ] **Container Running**
  ```bash
  ssh leonidas@91.98.137.217 "docker ps | grep myapp"
  ```

- [ ] **HTTP Access**
  ```bash
  curl -I https://myapp.mambo-cloud.com
  # Should return: HTTP/2 200
  ```

- [ ] **SSL Certificate**
  ```bash
  curl -vI https://myapp.mambo-cloud.com 2>&1 | grep "SSL certificate"
  # Should show Let's Encrypt certificate
  ```

- [ ] **Logs**
  ```bash
  ssh leonidas@91.98.137.217 "docker logs myapp-app --tail 20"
  # Should show no errors
  ```

- [ ] **Traefik Routing**
  - Visit: https://traefik.mambo-cloud.com
  - Check routers section for `myapp`

- [ ] **Grafana Monitoring**
  - Visit: https://grafana.mambo-cloud.com
  - Check containers are visible in dashboards
  - Verify logs in Loki: `{container_name="myapp-app"}`

---

## 🐛 Troubleshooting

### App Not Accessible (502/504 Error)

```bash
# Check container is running
docker ps | grep myapp

# Check container logs
docker logs myapp-app --tail 50

# Check if port is correct
docker inspect myapp-app | grep -A 5 Ports

# Test internal connectivity
curl -H "Host: myapp.mambo-cloud.com" http://localhost:3000
```

### SSL Certificate Issues

```bash
# Check Traefik logs
docker logs traefik | grep myapp

# Verify certificate
docker exec traefik ls -la /letsencrypt/

# Force certificate regeneration (CAUTION)
docker exec traefik rm /letsencrypt/acme.json
docker restart traefik
```

### DNS Not Resolving

```bash
# Check DNS propagation
dig myapp.mambo-cloud.com
dig myapp.mambo-cloud.com @8.8.8.8

# Verify Terraform applied
cd codespartan/infra/hetzner
terraform show | grep myapp

# Check Hetzner DNS console
# https://dns.hetzner.com → mambo-cloud.com
```

### Container Crashes/Restarts

```bash
# View crash logs
docker logs myapp-app

# Check resource usage
docker stats myapp-app

# Inspect healthcheck
docker inspect myapp-app | grep -A 20 Health

# Run healthcheck manually
docker exec myapp-app /app/healthcheck.sh
```

### Database Connection Issues

```bash
# Check database container
docker ps | grep myapp-db

# Check database logs
docker logs myapp-db --tail 50

# Test connectivity from app
docker exec myapp-app ping database

# Verify network
docker network inspect myapp_backend
```

---

## 📊 Monitoring Your App

Your application is automatically monitored:

### Metrics (VictoriaMetrics)

Available metrics:
- `container_cpu_usage_seconds_total{container_label_com_docker_compose_service="app"}`
- `container_memory_usage_bytes{container_label_com_docker_compose_service="app"}`
- `traefik_service_requests_total{service="myapp@docker"}`

View in Grafana:
- **Docker Monitoring** dashboard
- **Traefik Official** dashboard

### Logs (Loki)

Query logs in Grafana → Explore → Loki:
```
{container_name="myapp-app"}
```

Filter by level:
```
{container_name="myapp-app"} |= "ERROR"
```

### Alerts

Add custom alerts in `codespartan/platform/stacks/monitoring/alerts/apps.yml`:

```yaml
groups:
  - name: myapp_alerts
    interval: 1m
    rules:
      - alert: MyAppDown
        expr: up{job="myapp"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "MyApp is down"
          description: "MyApp has been down for more than 2 minutes"
```

---

## 🔄 Updating Your App

### Update Image Version

1. Edit `docker-compose.yml`:
```yaml
image: myapp:v2.0.0  # Update version
```

2. Commit and push:
```bash
git add codespartan/apps/myapp/docker-compose.yml
git commit -m "chore: update myapp to v2.0.0"
git push
```

GitHub Actions will automatically deploy!

### Manual Update

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/myapp
docker compose pull
docker compose up -d
```

### Rollback

If deployment fails:

```bash
# Via GitHub Actions: revert commit
git revert HEAD
git push

# Or manually: revert to previous image
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/myapp
docker compose down
# Edit docker-compose.yml to previous version
docker compose up -d
```

---

## 🗑️ Removing an App

To completely remove an application:

### 1. Stop and Remove Containers

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/myapp
docker compose down -v  # -v removes volumes too
```

### 2. Remove Files

```bash
sudo rm -rf /opt/codespartan/apps/myapp
```

### 3. Remove from Terraform

Edit `codespartan/infra/hetzner/terraform.tfvars`:
```hcl
subdomains = [
  # ... remove "myapp"
]
```

Apply:
```bash
cd codespartan/infra/hetzner
terraform apply
```

### 4. Remove Workflow

```bash
rm .github/workflows/deploy-myapp.yml
git add .
git commit -m "chore: remove myapp"
git push
```

---

## 📚 Additional Resources

- [Template Documentation](../../codespartan/apps/_TEMPLATE/README.md)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Runbook Operativo](../03-operations/RUNBOOK.md)
- [Guía de Despliegue](DEPLOYMENT.md)

---

## 💡 Best Practices

1. **Always use .env for secrets** - Never commit passwords to git
2. **Set resource limits** - Prevent resource exhaustion
3. **Implement health checks** - Enable automatic recovery
4. **Use specific image tags** - Avoid `latest` in production
5. **Test locally first** - Use `docker compose up` locally before deploying
6. **Monitor your app** - Check Grafana dashboards regularly
7. **Keep images updated** - Regularly pull new versions for security
8. **Use volumes for persistent data** - Don't store data in containers
9. **Document your app** - Update README with specific configuration
10. **Plan for failures** - Implement retry logic and graceful degradation

---

**Last Updated:** 2025-10-08
**Version:** 1.0.0
