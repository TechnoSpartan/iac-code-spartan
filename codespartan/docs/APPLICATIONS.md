# Application Management Runbook

Complete operational guide for managing applications on the CodeSpartan Mambo Cloud Platform.

**Last Updated:** 2025-10-08
**Audience:** DevOps Engineers, Developers
**Prerequisites:** SSH access, basic Docker knowledge

---

## Table of Contents

1. [Application Lifecycle](#application-lifecycle)
2. [Deploying New Applications](#deploying-new-applications)
3. [Updating Applications](#updating-applications)
4. [Rolling Back Applications](#rolling-back-applications)
5. [Scaling Applications](#scaling-applications)
6. [Monitoring Applications](#monitoring-applications)
7. [Debugging Applications](#debugging-applications)
8. [Common Operations](#common-operations)
9. [Best Practices](#best-practices)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Application Lifecycle

### States

```
┌─────────────┐
│  PLANNED    │ ← Code exists in repo
└──────┬──────┘
       ↓
┌─────────────┐
│  BUILDING   │ ← GitHub Actions building/testing
└──────┬──────┘
       ↓
┌─────────────┐
│  DEPLOYING  │ ← SCP to VPS, docker compose pull
└──────┬──────┘
       ↓
┌─────────────┐
│  RUNNING    │ ← Container up, passing health checks
└──────┬──────┘
       ↓
┌─────────────┐
│  UPDATING   │ ← New version deploying (brief downtime)
└──────┬──────┘
       ↓
┌─────────────┐
│  STOPPED    │ ← Intentionally stopped or failed
└─────────────┘
```

### Typical Flow

```
1. Development
   ├─ Write code locally
   ├─ Test with docker compose up
   └─ Commit to feature branch

2. Review
   ├─ Create pull request
   ├─ Code review
   └─ Merge to main

3. Deployment (Automatic)
   ├─ GitHub Actions triggered
   ├─ Files copied to VPS
   ├─ docker compose pull
   ├─ docker compose up -d
   └─ Health check

4. Verification
   ├─ Check URL responds
   ├─ Check logs (no errors)
   ├─ Check metrics in Grafana
   └─ Verify SSL certificate

5. Monitoring
   ├─ Continuous metrics collection
   ├─ Log aggregation
   ├─ Alert evaluation
   └─ Dashboard visualization
```

---

## Deploying New Applications

### Method 1: Using Template (Recommended)

**1. Copy Template**

```bash
# On local machine
cd /path/to/iac-code-spartan
cp -r codespartan/apps/_TEMPLATE codespartan/apps/my-new-app
cd codespartan/apps/my-new-app
```

**2. Customize Configuration**

Edit `docker-compose.yml`:

```yaml
services:
  app:
    image: your-org/my-new-app:latest  # Your Docker image
    container_name: my-new-app-app

    environment:
      - APP_NAME=my-new-app
      - SUBDOMAIN=myapp                # Choose subdomain
      - APP_PORT=3000                  # Your app's internal port
      - NODE_ENV=production

    labels:
      - traefik.enable=true
      - traefik.http.routers.my-new-app.rule=Host(`myapp.mambo-cloud.com`)
      - traefik.http.routers.my-new-app.entrypoints=websecure
      - traefik.http.routers.my-new-app.tls.certresolver=le
      - traefik.http.services.my-new-app.loadbalancer.server.port=3000

      # Apply security middlewares
      - traefik.http.routers.my-new-app.middlewares=rate-limit-global@file,security-headers@file,compression@file

    # Optional: Add healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    networks:
      - web

    restart: unless-stopped

networks:
  web:
    external: true
```

Create `.env` from `.env.example`:

```bash
cp .env.example .env
nano .env
```

```env
APP_NAME=my-new-app
SUBDOMAIN=myapp
APP_PORT=3000
NODE_ENV=production

# Add any secrets
DATABASE_PASSWORD=change_me_strong_password
API_KEY=your_api_key_here
```

**IMPORTANT:** Never commit `.env` to git!

**3. Add Subdomain to Terraform**

Edit `codespartan/infra/hetzner/terraform.tfvars`:

```hcl
subdomains = [
  "traefik",
  "grafana",
  "backoffice",
  "www",
  "staging",
  "lab",
  "myapp"  # Add your new subdomain
]
```

Apply Terraform changes:

```bash
cd codespartan/infra/hetzner
terraform init
terraform plan  # Review changes
terraform apply # Create DNS record
```

**4. Create GitHub Actions Workflow**

Copy template:

```bash
cp .github/workflows/_template-deploy.yml .github/workflows/deploy-my-new-app.yml
```

Replace all `YOUR_APP_NAME` with `my-new-app`:

```bash
# macOS
sed -i '' 's/YOUR_APP_NAME/my-new-app/g' .github/workflows/deploy-my-new-app.yml

# Linux
sed -i 's/YOUR_APP_NAME/my-new-app/g' .github/workflows/deploy-my-new-app.yml
```

Review and commit:

```bash
git add .github/workflows/deploy-my-new-app.yml
git commit -m "ci: add deployment workflow for my-new-app"
```

**5. Commit and Deploy**

```bash
git add codespartan/apps/my-new-app
git add codespartan/infra/hetzner/terraform.tfvars
git commit -m "feat: add my-new-app application"
git push origin main
```

GitHub Actions will automatically:
- Deploy infrastructure changes (DNS)
- Deploy your application
- Start container
- Configure SSL

**6. Verify Deployment**

```bash
# Check GitHub Actions
# https://github.com/your-org/iac-code-spartan/actions

# Check DNS (wait 2-5 minutes)
dig myapp.mambo-cloud.com
# Should return: 91.98.137.217

# Check HTTPS
curl -I https://myapp.mambo-cloud.com
# Should return: HTTP/2 200

# Check on VPS
ssh leonidas@91.98.137.217
docker ps | grep my-new-app
docker logs my-new-app-app --tail 50
```

**7. Monitor in Grafana**

Open https://grafana.mambo-cloud.com

**Metrics:**
- Explore → VictoriaMetrics
- Query: `container_memory_usage_bytes{container_label_com_docker_compose_service="app", compose_project="my-new-app"}`

**Logs:**
- Explore → Loki
- Query: `{container_name="my-new-app-app"}`

---

### Method 2: Manual Deployment

For quick testing or one-off deployments:

**1. SSH to VPS**

```bash
ssh leonidas@91.98.137.217
```

**2. Create Directory**

```bash
sudo mkdir -p /opt/codespartan/apps/test-app
sudo chown leonidas:leonidas /opt/codespartan/apps/test-app
cd /opt/codespartan/apps/test-app
```

**3. Create docker-compose.yml**

```bash
nano docker-compose.yml
```

```yaml
version: '3.8'

services:
  app:
    image: nginx:alpine
    container_name: test-app
    labels:
      - traefik.enable=true
      - traefik.http.routers.testapp.rule=Host(`test.mambo-cloud.com`)
      - traefik.http.routers.testapp.entrypoints=websecure
      - traefik.http.routers.testapp.tls.certresolver=le
      - traefik.docker.network=web
    networks:
      - web
    restart: unless-stopped

networks:
  web:
    external: true
```

**4. Deploy**

```bash
docker compose pull
docker compose up -d
```

**5. Verify**

```bash
docker ps | grep test-app
docker logs test-app
curl -I https://test.mambo-cloud.com
```

**Note:** This method skips DNS creation and CI/CD. You'll need to manually add the DNS record in Hetzner console or via Terraform.

---

## Updating Applications

### Automatic Updates (CI/CD)

**Trigger:** Push to app directory

```bash
# Make changes to your app
cd codespartan/apps/my-new-app
nano html/index.html  # or whatever files

# Commit and push
git add .
git commit -m "fix: update homepage content"
git push origin main
```

GitHub Actions automatically:
1. Detects changes in `codespartan/apps/my-new-app/**`
2. Triggers `deploy-my-new-app.yml` workflow
3. Copies files to VPS
4. Runs `docker compose pull` (gets latest image)
5. Runs `docker compose up -d` (recreates container)
6. Verifies container is running

**Typical Duration:** 1-2 minutes

**Zero-Downtime:** Not guaranteed (brief downtime during container restart)

---

### Manual Updates

**Update Container Image:**

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/my-new-app

# Pull latest image
docker compose pull

# Recreate container
docker compose up -d

# Verify
docker ps
docker logs my-new-app-app --tail 20
```

**Update Configuration Only:**

```bash
# Edit docker-compose.yml or .env
nano docker-compose.yml

# Recreate container (pulls config changes)
docker compose up -d
```

**Update Specific Service (multi-service apps):**

```bash
# Only restart the 'app' service
docker compose up -d app

# Only restart 'database' service
docker compose up -d database
```

---

### Rolling Updates (Advanced)

For multi-instance deployments:

**1. Blue/Green Deployment**

```yaml
# docker-compose.yml
services:
  app-blue:
    image: my-app:v1.0
    labels:
      - traefik.http.routers.app.service=app-blue

  app-green:
    image: my-app:v1.1
    labels:
      - traefik.http.routers.app.service=app-green
    deploy:
      replicas: 0  # Initially off
```

**Switch traffic:**

```bash
# Start green
docker compose up -d app-green --scale app-green=1

# Verify green is healthy
docker logs app-green
curl -H "Host: myapp.mambo-cloud.com" http://localhost:3000

# Update Traefik to point to green
# (Update labels, restart)

# Stop blue
docker compose stop app-blue
```

**2. Canary Deployment**

Use Traefik's weighted round-robin:

```yaml
labels:
  - traefik.http.services.app.loadbalancer.server.port=3000
  - traefik.http.services.app-v1.loadbalancer.server.weight=90
  - traefik.http.services.app-v2.loadbalancer.server.weight=10
```

10% of traffic goes to v2, 90% to v1.

---

## Rolling Back Applications

### Rollback Container to Previous Image

**1. Find Previous Image**

```bash
# View image history
docker images | grep my-app

REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
my-app        v1.2      abc123def      2 hours ago    150MB
my-app        v1.1      xyz789ghi      1 day ago      148MB
my-app        v1.0      qwe456rty      2 days ago     145MB
```

**2. Update docker-compose.yml**

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/my-new-app
nano docker-compose.yml
```

Change:
```yaml
services:
  app:
    image: my-app:v1.2  # Current broken version
```

To:
```yaml
services:
  app:
    image: my-app:v1.1  # Previous working version
```

**3. Redeploy**

```bash
docker compose pull  # Ensure we have the image
docker compose up -d
```

**4. Verify**

```bash
docker ps
docker logs my-new-app-app --tail 50
curl -I https://myapp.mambo-cloud.com
```

---

### Rollback via Git

**1. Find Last Good Commit**

```bash
git log --oneline codespartan/apps/my-new-app/

a1b2c3d fix: update homepage
x9y8z7w feat: add new feature  ← This one broke
m5n6o7p refactor: clean code     ← Last working
```

**2. Revert or Reset**

**Option A: Revert (creates new commit)**

```bash
git revert x9y8z7w
git push origin main
```

**Option B: Reset (rewrite history - use with caution)**

```bash
git reset --hard m5n6o7p
git push origin main --force
```

**3. Wait for CI/CD**

GitHub Actions will automatically deploy the reverted version.

**4. Monitor**

Check GitHub Actions for deployment success.

---

### Emergency Rollback (Manual)

If CI/CD is broken or too slow:

**1. SSH and Stop Container**

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/my-new-app
docker compose down
```

**2. Restore from Backup**

```bash
# List backups
ls -lh /opt/codespartan/backups/

# Restore configs
cd /opt/codespartan
sudo /opt/codespartan/scripts/restore.sh /opt/codespartan/backups/backup-2025-10-07_03-00-00.tar.gz --configs-only
```

**3. Restart**

```bash
cd /opt/codespartan/apps/my-new-app
docker compose up -d
```

---

## Scaling Applications

### Vertical Scaling (More Resources)

**1. Resource Limits**

Edit `docker-compose.yml`:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'      # Max 2 CPU cores (was 1.0)
          memory: 2G       # Max 2GB RAM (was 512M)
        reservations:
          cpus: '0.5'
          memory: 512M
```

**2. Apply**

```bash
docker compose up -d
```

**Note:** If exceeding VPS limits, upgrade VPS in Hetzner Cloud console.

---

### Horizontal Scaling (More Instances)

**1. Multi-Instance Deployment**

```bash
docker compose up -d --scale app=3
```

**2. Traefik Load Balancing**

Traefik automatically detects all instances and load balances:

```
Request → Traefik → Round Robin
                   ├─ app-1 (33%)
                   ├─ app-2 (33%)
                   └─ app-3 (33%)
```

**3. Sticky Sessions (if needed)**

```yaml
labels:
  - traefik.http.services.app.loadbalancer.sticky.cookie=true
  - traefik.http.services.app.loadbalancer.sticky.cookie.name=app_session
```

**4. Health Checks**

Only healthy instances receive traffic:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

---

### Database Scaling

**Replicas:**

```yaml
services:
  postgres:
    image: postgres:15-alpine
    # ... existing config

  postgres-replica:
    image: postgres:15-alpine
    environment:
      - POSTGRES_ROLE=replica
      - POSTGRES_MASTER_HOST=postgres
    # ... replication config
```

**Read/Write Split:**

Configure app to:
- Write to `postgres:5432`
- Read from `postgres-replica:5432`

---

## Monitoring Applications

### Real-Time Logs

**Via Docker:**

```bash
# Follow logs
docker logs my-new-app-app -f

# Last 100 lines
docker logs my-new-app-app --tail 100

# Logs since timestamp
docker logs my-new-app-app --since 2025-10-08T10:00:00

# Filter for errors
docker logs my-new-app-app 2>&1 | grep ERROR
```

**Via Grafana Loki:**

Open https://grafana.mambo-cloud.com → Explore → Loki

```logql
# All logs from app
{container_name="my-new-app-app"}

# Last 5 minutes
{container_name="my-new-app-app"} [5m]

# Filter for errors
{container_name="my-new-app-app"} |= "error"

# Regex filter
{container_name="my-new-app-app"} |~ "HTTP/[0-9.]+ 5[0-9]{2}"

# Count rate
rate({container_name="my-new-app-app"}[5m])

# JSON parsing
{container_name="my-new-app-app"} | json | level="error"
```

---

### Metrics Monitoring

**Container Metrics (cAdvisor):**

Open Grafana → Explore → VictoriaMetrics

```promql
# CPU usage (% of 1 core)
rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_service="app"}[5m]) * 100

# Memory usage (bytes)
container_memory_usage_bytes{container_label_com_docker_compose_service="app"}

# Network received (bytes/sec)
rate(container_network_receive_bytes_total{container_label_com_docker_compose_service="app"}[5m])

# Network transmitted (bytes/sec)
rate(container_network_transmit_bytes_total{container_label_com_docker_compose_service="app"}[5m])

# Disk I/O read (bytes/sec)
rate(container_fs_reads_bytes_total{container_label_com_docker_compose_service="app"}[5m])
```

**HTTP Metrics (Traefik):**

```promql
# Request rate
rate(traefik_service_requests_total{service="my-new-app@docker"}[5m])

# Request duration (p99)
histogram_quantile(0.99, rate(traefik_service_request_duration_seconds_bucket{service="my-new-app@docker"}[5m]))

# Error rate
rate(traefik_service_requests_total{service="my-new-app@docker",code=~"5.."}[5m])

# 4xx rate
rate(traefik_service_requests_total{service="my-new-app@docker",code=~"4.."}[5m])
```

**Custom Application Metrics:**

If your app exposes Prometheus metrics on `/metrics`:

**1. Add to vmagent scrape config**

Edit `codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-new-app'
    static_configs:
      - targets: ['my-new-app-app:9090']  # Your metrics port
```

**2. Redeploy monitoring**

```bash
cd codespartan/platform/stacks/monitoring
docker compose up -d vmagent
```

**3. Query custom metrics**

```promql
# Your custom metrics now available
my_app_custom_metric_total
```

---

### Dashboards

**Create Custom Dashboard:**

1. Open Grafana → Dashboards → New Dashboard
2. Add Panel
3. Select VictoriaMetrics datasource
4. Enter PromQL query
5. Configure visualization
6. Save dashboard

**Example Panel: Request Rate**

```json
{
  "title": "My App Request Rate",
  "targets": [
    {
      "expr": "rate(traefik_service_requests_total{service=\"my-new-app@docker\"}[5m])",
      "legendFormat": "{{ method }} {{ code }}"
    }
  ],
  "type": "graph"
}
```

**Save Dashboard:**

1. Click Save (top-right)
2. Name: "My New App Dashboard"
3. Folder: "Applications"
4. Save

**Export Dashboard (for version control):**

1. Dashboard Settings → JSON Model
2. Copy JSON
3. Save to `codespartan/platform/stacks/monitoring/grafana/dashboards/my-app.json`
4. Commit to git

---

### Alerts

**Create Alert Rule:**

Edit `codespartan/platform/stacks/monitoring/alerts/apps.yml`:

```yaml
groups:
  - name: my_app_alerts
    interval: 30s
    rules:
      - alert: MyAppDown
        expr: up{job="my-new-app"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "My App is down"
          description: "My App has been down for more than 2 minutes"

      - alert: MyAppHighErrorRate
        expr: rate(traefik_service_requests_total{service="my-new-app@docker",code=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "My App high error rate"
          description: "Error rate is {{ $value }} req/s"

      - alert: MyAppHighLatency
        expr: histogram_quantile(0.99, rate(traefik_service_request_duration_seconds_bucket{service="my-new-app@docker"}[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "My App high latency"
          description: "P99 latency is {{ $value }}s"
```

**Apply Changes:**

```bash
cd codespartan/platform/stacks/monitoring
docker compose restart vmalert
```

**Test Alert:**

Stop your app to trigger `MyAppDown`:

```bash
docker stop my-new-app-app
```

Wait 2 minutes, check ntfy.sh for notification.

Restart:

```bash
docker start my-new-app-app
```

---

## Debugging Applications

### Container Won't Start

**1. Check Container Status**

```bash
docker ps -a | grep my-new-app

# Possible statuses:
# - Exited (0) - Clean exit, likely intentional stop
# - Exited (1) - Error exit, check logs
# - Restarting - In restart loop, health check failing
```

**2. View Logs**

```bash
docker logs my-new-app-app
```

**Common Issues:**

```
Error: Cannot find module 'express'
→ Fix: Ensure dependencies installed in Docker image

Error: EADDRINUSE: address already in use :::3000
→ Fix: Another container using port 3000, change APP_PORT

Error: connect ECONNREFUSED 172.19.0.2:5432
→ Fix: Database not ready, add depends_on + health check

Error: Permission denied
→ Fix: Volume mount permissions, use chown in Dockerfile
```

**3. Inspect Container**

```bash
docker inspect my-new-app-app

# Check:
# - State.Status
# - State.ExitCode
# - State.Error
# - NetworkSettings
# - Mounts
```

**4. Try Running Manually**

```bash
# Run container interactively
docker run -it --rm \
  --entrypoint sh \
  my-app:latest

# Inside container:
ls -la
cat /app/package.json
node index.js  # See what fails
```

---

### Application Returns 502/503

**Meaning:** Traefik can't reach your container

**1. Check Traefik Logs**

```bash
docker logs traefik | grep my-new-app
```

**Look for:**

```
level=error msg="Service not found: my-new-app@docker"
→ Container not labeled correctly

level=error msg="dial tcp 172.18.0.5:3000: connect: connection refused"
→ App not listening on expected port

level=error msg="no active backend"
→ All instances unhealthy
```

**2. Verify Container is Running**

```bash
docker ps | grep my-new-app
```

**3. Check Container Labels**

```bash
docker inspect my-new-app-app | grep -A 20 Labels
```

Ensure:
```json
"traefik.enable": "true",
"traefik.http.routers.app.rule": "Host(`myapp.mambo-cloud.com`)",
"traefik.http.services.app.loadbalancer.server.port": "3000"
```

**4. Test Internal Connectivity**

```bash
# From VPS host
curl -H "Host: myapp.mambo-cloud.com" http://localhost:3000

# Should return app response
# If connection refused → app not listening
# If 404 → app listening but route wrong
```

**5. Check Network**

```bash
docker network inspect web | grep my-new-app

# Container should be listed
# If not → wrong network in docker-compose.yml
```

**6. Check Port**

```bash
docker exec my-new-app-app netstat -tlnp

# Should show:
# tcp        0      0 0.0.0.0:3000    0.0.0.0:*    LISTEN    1/node
```

**Fix:** App listening on 127.0.0.1 instead of 0.0.0.0

```javascript
// Wrong
app.listen(3000, 'localhost')

// Correct
app.listen(3000, '0.0.0.0')
```

---

### SSL Certificate Issues

**1. Certificate Not Issued**

**Check acme.json:**

```bash
docker exec traefik ls -la /letsencrypt/

# If empty or very small:
du -h /opt/codespartan/platform/traefik/letsencrypt/acme.json
```

**Check Traefik logs for ACME activity:**

```bash
docker logs traefik | grep -i acme
docker logs traefik | grep -i "let's encrypt"

# Look for:
level=error msg="Unable to obtain ACME certificate for domains..."
→ Challenge failed

level=info msg="Certificates obtained for [myapp.mambo-cloud.com]"
→ Success
```

**Common Failures:**

```
error="acme: error: 403 :: urn:ietf:params:acme:error:unauthorized"
→ DNS not pointing to server, wait for propagation

error="acme: error: 429 :: urn:ietf:params:acme:error:rateLimited"
→ Too many cert requests, wait 1 hour

error="acme: error: timeout"
→ Port 80 not accessible, check firewall
```

**Force Certificate Regeneration:**

```bash
# Backup first
sudo cp /opt/codespartan/platform/traefik/letsencrypt/acme.json \
       /opt/codespartan/platform/traefik/letsencrypt/acme.json.backup

# Remove certificates
docker exec traefik rm /letsencrypt/acme.json

# Restart Traefik (triggers cert request)
docker restart traefik

# Watch logs
docker logs traefik -f | grep -i acme
```

**2. Certificate Invalid in Browser**

**Symptoms:** Browser shows "Not Secure" or certificate warning

**Check Certificate Details:**

```bash
echo | openssl s_client -servername myapp.mambo-cloud.com \
  -connect myapp.mambo-cloud.com:443 2>/dev/null | \
  openssl x509 -noout -text | grep -A 5 "Subject:"

# Should show:
# Subject: CN = myapp.mambo-cloud.com
# Issuer: C=US, O=Let's Encrypt, CN=R...
```

**Common Issues:**

```
Subject: CN = localhost
→ Self-signed cert, Let's Encrypt failed

Subject Alternative Name: traefik.mambo-cloud.com
→ Wrong cert served, Traefik routing issue

Valid From: Oct  9 00:00:00 2025 GMT
Valid To:   Oct  8 23:59:59 2025 GMT
→ Certificate expired, renewal failed
```

**Fix:** See `check-ssl-renewal.sh` output

```bash
/opt/codespartan/scripts/check-ssl-renewal.sh
```

---

### High Memory Usage

**1. Identify Memory Hog**

```bash
docker stats --no-stream | sort -k 4 -h

CONTAINER         CPU %   MEM USAGE / LIMIT     MEM %
my-new-app-app    5%      1.5GB / 2GB          75%     ← High!
grafana           2%      200MB / 4GB           5%
victoriametrics   1%      150MB / 4GB           3.75%
```

**2. Check Container Limits**

```bash
docker inspect my-new-app-app | grep -A 10 Memory

# Look for:
"Memory": 2147483648,  # 2GB limit
"MemorySwap": -1       # Unlimited swap
```

**3. Investigate Application**

```bash
# If Node.js
docker exec my-new-app-app node -e "console.log(process.memoryUsage())"

# If Python
docker exec my-new-app-app python -c "import resource; print(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)"

# Generic memory info
docker exec my-new-app-app cat /proc/meminfo
```

**4. Common Causes**

```
Memory Leak:
  → Profile app with tools (Node: --inspect, Python: memory_profiler)
  → Fix code, redeploy

Large Dataset in Memory:
  → Use streaming, pagination
  → Move to database

Cache Too Large:
  → Implement cache eviction (LRU)
  → Set max cache size

Too Many Processes:
  → Reduce worker count
  → Use resource limits
```

**5. Temporary Fix (Restart)**

```bash
docker restart my-new-app-app
```

**6. Permanent Fix (Optimize or Scale)**

```yaml
# Increase limit
deploy:
  resources:
    limits:
      memory: 4G

# Or scale horizontally
# docker compose up -d --scale app=2
```

---

## Common Operations

### View All Running Apps

```bash
ssh leonidas@91.98.137.217
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

NAMES                IMAGE                              STATUS           PORTS
my-new-app-app       my-app:latest                     Up 2 hours
mambo-cloud-app      nginx:alpine                      Up 5 days
grafana              grafana/grafana:10.4.5            Up 5 days        0.0.0.0:3000->3000/tcp
traefik              traefik:v2.11                     Up 5 days        0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp
victoriametrics      victoriametrics/victoria-metrics  Up 5 days
```

---

### Restart All Applications

```bash
# Individual apps
cd /opt/codespartan/apps/my-new-app
docker compose restart

# All apps at once (careful!)
for app in /opt/codespartan/apps/*/; do
  if [ -f "$app/docker-compose.yml" ] && [ "$(basename "$app")" != "_TEMPLATE" ]; then
    echo "Restarting $(basename "$app")..."
    cd "$app"
    docker compose restart
  fi
done
```

---

### Clean Up Unused Resources

```bash
# Run cleanup script (dry-run first)
/opt/codespartan/scripts/cleanup.sh --dry-run

# Review output, then run for real
/opt/codespartan/scripts/cleanup.sh
```

**What it cleans:**
- Stopped containers
- Dangling images (not used by any container)
- Unused volumes (not attached to any container)
- Unused networks
- Build cache
- Old backups (>7 days)

---

### Update All Applications

```bash
# Run update script (dry-run first)
/opt/codespartan/scripts/update-containers.sh --dry-run

# Review output, then run for real
/opt/codespartan/scripts/update-containers.sh

# Or with backup before updating
/opt/codespartan/scripts/update-containers.sh --backup
```

**What it does:**
1. Pulls latest images for all services
2. Recreates containers with new images
3. Verifies containers are running
4. Optionally runs health check

---

### Export Application Configuration

```bash
# Export single app
cd /opt/codespartan/apps/my-new-app
docker compose config > my-new-app-config.yml

# Copy to local machine
scp leonidas@91.98.137.217:/opt/codespartan/apps/my-new-app/my-new-app-config.yml .
```

---

### Clone Application to New Environment

```bash
# On local machine
cp -r codespartan/apps/my-new-app codespartan/apps/my-new-app-staging

# Edit configuration
cd codespartan/apps/my-new-app-staging
nano docker-compose.yml

# Change:
# - Container name: my-new-app-staging-app
# - Subdomain: myapp-staging.mambo-cloud.com
# - Any environment variables

# Commit and deploy
git add .
git commit -m "feat: add staging environment for my-new-app"
git push
```

---

## Best Practices

### Security

1. **Never commit secrets to git**
   - Use `.env` files (in `.gitignore`)
   - Use GitHub Secrets for CI/CD
   - Rotate secrets regularly

2. **Use specific image tags**
   ```yaml
   # Bad
   image: my-app:latest

   # Good
   image: my-app:v1.2.3
   ```

3. **Enable healthchecks**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

4. **Apply security middlewares**
   ```yaml
   labels:
     - traefik.http.routers.app.middlewares=rate-limit-global@file,security-headers@file
   ```

5. **Run as non-root user**
   ```dockerfile
   USER node:node
   ```

---

### Performance

1. **Set resource limits**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '1.0'
         memory: 512M
   ```

2. **Use multi-stage Docker builds**
   ```dockerfile
   FROM node:18 AS builder
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci --production

   FROM node:18-alpine
   COPY --from=builder /app/node_modules ./node_modules
   COPY . .
   ```

3. **Enable compression**
   ```yaml
   labels:
     - traefik.http.routers.app.middlewares=compression@file
   ```

4. **Use caching**
   - Redis for session/data cache
   - Browser caching headers
   - CDN for static assets

---

### Reliability

1. **Always use restart policies**
   ```yaml
   restart: unless-stopped
   ```

2. **Implement graceful shutdown**
   ```javascript
   process.on('SIGTERM', async () => {
     await server.close()
     await db.disconnect()
     process.exit(0)
   })
   ```

3. **Add dependencies**
   ```yaml
   depends_on:
     database:
       condition: service_healthy
   ```

4. **Use health checks**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost/health"]
   ```

5. **Monitor everything**
   - Logs in Grafana Loki
   - Metrics in VictoriaMetrics
   - Alerts for critical issues

---

### Maintainability

1. **Document your app**
   - README in app directory
   - Environment variables explained
   - Deployment process documented

2. **Use docker-compose.yml comments**
   ```yaml
   environment:
     - DATABASE_URL=postgresql://...  # Connection to postgres service
     - REDIS_URL=redis://cache:6379   # Session cache
   ```

3. **Version your images**
   ```bash
   docker build -t my-app:v1.2.3 .
   docker push my-app:v1.2.3
   ```

4. **Keep docker-compose.yml clean**
   - One concern per file
   - Use `.env` for values
   - Use templates for repeated config

5. **Test locally first**
   ```bash
   docker compose up
   # Test thoroughly
   docker compose down
   # Then deploy to production
   ```

---

## Troubleshooting Guide

### Quick Diagnosis

```bash
# Run health check script
/opt/codespartan/scripts/health-check.sh

# Check specific app
docker ps -a | grep my-app
docker logs my-app-app --tail 50
docker stats my-app-app --no-stream
docker inspect my-app-app | grep -i health
```

---

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| 502 Bad Gateway | App not listening | Check port in docker-compose.yml |
| 503 Service Unavailable | No healthy backends | Check health check, view logs |
| SSL error | Certificate not issued | Check Traefik logs, verify DNS |
| Container restarts | Crash loop | Check logs, fix application bug |
| High CPU | Inefficient code | Profile app, optimize |
| High memory | Memory leak | Restart (temp), fix code (perm) |
| Can't connect to DB | Network issue | Check `depends_on`, networks |
| 404 Not Found | Wrong route | Check Traefik `Host()` rule |

---

### Get Help

**View logs:**
```bash
docker logs <container> --tail 100 -f
```

**Check Grafana:**
- Logs: https://grafana.mambo-cloud.com → Explore → Loki
- Metrics: https://grafana.mambo-cloud.com → Explore → VictoriaMetrics

**Run diagnostics:**
```bash
/opt/codespartan/scripts/diagnostics.sh
```

**View all documentation:**
```bash
ls -la /path/to/iac-code-spartan/codespartan/docs/
```

---

**End of Application Management Runbook**

For more details, see:
- `OVERVIEW.md` - System architecture
- `TROUBLESHOOTING.md` - Detailed problem solving
- `ADDING_APPS.md` - Step-by-step app deployment
- `SECURITY.md` - Security best practices
