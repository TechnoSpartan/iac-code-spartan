# Traefik (Reverse Proxy)

Traefik v3.6.1 with automatic Let's Encrypt SSL certificates and dynamic Docker service discovery.

## Features

- **Automatic SSL**: Let's Encrypt certificates via HTTP-01 challenge
- **Dynamic Routing**: Discovers Docker containers automatically via labels
- **Dashboard**: Protected web UI for monitoring and configuration
- **Metrics**: Prometheus metrics for monitoring integration
- **Rate Limiting**: Built-in rate limiting for API protection
- **Security Headers**: HSTS, XSS protection, frame denial

## Configuration

### Environment Variables (.env)

```bash
ACME_EMAIL=your-email@example.com        # Email for Let's Encrypt notifications
DASHBOARD_HOST=traefik.mambo-cloud.com   # Dashboard domain
BASIC_AUTH=username:hashed_password      # Basic auth credentials (htpasswd format)
```

Create `.env` from `.env.example` and customize the values.

### Generate Basic Auth Password

```bash
htpasswd -nb admin your_password
# Copy the output to BASIC_AUTH in .env
```

## Deployment

### Prerequisites

1. Ensure the external Docker network exists:
```bash
docker network create web
```

2. Configure environment variables in `.env`

### Deploy Traefik

```bash
cd /opt/codespartan/platform/traefik
docker compose up -d
```

### Verify Deployment

```bash
# Check container status
docker ps | grep traefik

# View logs
docker logs traefik -f

# Test health endpoint
curl http://localhost:8080/ping

# Check SSL certificate
curl -I https://traefik.mambo-cloud.com
```

## Access

- **Dashboard**: https://traefik.mambo-cloud.com
- **Credentials**: Set in `.env` file (default: admin/codespartan123)
- **API**: https://traefik.mambo-cloud.com/api/overview

## Architecture

### Entrypoints

- **web** (port 80): HTTP traffic, automatically redirected to HTTPS
- **websecure** (port 443): HTTPS traffic with automatic SSL

### Middlewares (dynamic-config.yml)

- `rate-limit-global`: 100 req/s per IP (for general services)
- `rate-limit-api`: 50 req/s per IP (for API endpoints)
- `rate-limit-strict`: 10 req/s per IP (for sensitive endpoints like dashboards)
- `security-headers`: HSTS, XSS protection, content-type sniffing prevention
- `compression`: Gzip compression for responses
- `cors-api`: CORS headers for API services
- `https-redirect`: Automatic HTTP → HTTPS redirect

### SSL Certificate Resolution

Let's Encrypt certificates are automatically requested and renewed:
- **Challenge Type**: HTTP-01 (validates domain ownership via HTTP request)
- **Storage**: `/letsencrypt/acme.json` (persisted volume)
- **Renewal**: Automatic before expiration
- **Email Notifications**: Sent to `ACME_EMAIL` for expiration warnings

## Troubleshooting

### SSL Certificate Issues

**Problem**: Default self-signed certificate (`TRAEFIK DEFAULT CERT`) instead of Let's Encrypt

**Diagnosis**:
```bash
# Check certificate issuer
openssl s_client -connect traefik.mambo-cloud.com:443 -servername traefik.mambo-cloud.com </dev/null 2>/dev/null | openssl x509 -noout -issuer

# Should show: issuer=C=US, O=Let's Encrypt, CN=R13
# If shows: issuer=CN=TRAEFIK DEFAULT CERT, certificate generation failed
```

**Common Causes**:
1. **Port 80 blocked**: ACME HTTP-01 challenge requires port 80 accessible from internet
2. **DNS not resolving**: Domain must resolve to VPS IP before certificate request
3. **Rate limiting**: Let's Encrypt has rate limits (5 certificates per domain per week)
4. **Redirect interference**: HTTP→HTTPS redirect must not block `/.well-known/acme-challenge/`

**Solution**:
```bash
# 1. Verify DNS resolution
dig +short traefik.mambo-cloud.com
# Should return: 91.98.137.217

# 2. Test port 80 accessibility
curl -I http://traefik.mambo-cloud.com/.well-known/acme-challenge/test
# Should NOT immediately redirect (ACME challenge needs HTTP access)

# 3. Check Traefik logs for ACME errors
docker logs traefik | grep -i acme

# 4. Delete and recreate certificate (forces retry)
docker compose down
rm letsencrypt/acme.json
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
docker compose up -d

# 5. Monitor certificate generation
docker logs traefik -f | grep -i "certificate"
```

### Health Check Failures

**Problem**: Continuous health check errors in logs

```
Health check for container ... error: exec: "traefik": executable file not found in $PATH
```

**Cause**: The `traefik healthcheck --ping` command is not available in all Traefik images

**Solution**: Already fixed in current configuration using `wget`:
```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/ping"]
```

### Service Not Accessible

**Problem**: Service configured with Traefik labels but not accessible

**Diagnosis**:
```bash
# 1. Check if Traefik detected the service
docker logs traefik | grep -i "service-name"

# 2. Check Traefik routers
curl -s -u admin:password https://traefik.mambo-cloud.com/api/http/routers | jq

# 3. Verify service is on 'web' network
docker inspect service-container | jq '.[0].NetworkSettings.Networks'

# 4. Test internal routing
curl -H "Host: subdomain.mambo-cloud.com" http://localhost
```

**Common Issues**:
- Service not on `web` network
- Missing `traefik.enable=true` label
- Incorrect router rule (typo in domain)
- Service port not exposed or wrong port in label

### Dashboard Not Accessible

**Problem**: Can't access Traefik dashboard

**Diagnosis**:
```bash
# 1. Test authentication
curl -I -u admin:codespartan123 https://traefik.mambo-cloud.com

# 2. Check if dashboard is enabled
docker exec traefik cat /etc/traefik/traefik.yml | grep dashboard

# 3. Verify basic auth file
docker exec traefik cat /users.htpasswd
```

**Solutions**:
- Verify credentials in `.env` match those in `users.htpasswd`
- Ensure `--api.dashboard=true` in docker-compose.yml
- Check browser console for CORS or security header issues

## Monitoring

### Metrics

Traefik exposes Prometheus metrics at `http://localhost:8080/metrics`:

```bash
# View metrics
curl -s http://localhost:8080/metrics | grep traefik_

# Key metrics:
# - traefik_entrypoint_requests_total
# - traefik_entrypoint_request_duration_seconds
# - traefik_router_requests_total
# - traefik_service_requests_total
```

### Logs

```bash
# Real-time logs
docker logs traefik -f

# Filter by level
docker logs traefik 2>&1 | grep "level=error"

# ACME certificate logs
docker logs traefik 2>&1 | grep -i "acme\|certificate"

# Routing logs
docker logs traefik 2>&1 | grep -i "router\|service"
```

## Maintenance

### Update Traefik Version

```bash
# 1. Backup configuration
cp -r /opt/codespartan/platform/traefik /opt/codespartan/platform/traefik.backup

# 2. Update image in docker-compose.yml
vim docker-compose.yml
# Change: image: traefik:v3.6.1

# 3. Pull new image and recreate
docker compose pull
docker compose up -d

# 4. Verify
docker logs traefik
curl -I https://traefik.mambo-cloud.com
```

### Backup SSL Certificates

```bash
# Backup acme.json (contains all certificates)
cp letsencrypt/acme.json letsencrypt/acme.json.backup.$(date +%Y%m%d)

# Restore if needed
cp letsencrypt/acme.json.backup.YYYYMMDD letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
docker compose restart
```

## Security Considerations

1. **Basic Auth**: Dashboard requires authentication (configured in `users.htpasswd`)
2. **Rate Limiting**: Strict limits on dashboard (10 req/s) prevent brute force
3. **Security Headers**: HSTS, XSS protection, frame denial enabled
4. **TLS Configuration**: TLS 1.2+ only, secure cipher suites
5. **Docker Socket**: Mounted read-only (`:ro`) to prevent container manipulation
6. **Certificate Storage**: `acme.json` has 600 permissions (owner-only access)

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Docker Provider Configuration](https://doc.traefik.io/traefik/providers/docker/)
- [ACME HTTP Challenge](https://doc.traefik.io/traefik/https/acme/#httpchallenge)
