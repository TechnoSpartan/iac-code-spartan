# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CodeSpartan Mambo Cloud Platform** - Complete Infrastructure as Code (IaC) for automated deployment on Hetzner Cloud ARM64 with Docker, Traefik reverse proxy, and full monitoring stack.

Primary domain: `mambo-cloud.com` (DNS managed in Hetzner)
VPS: `91.98.137.217` (IPv4), `2a01:4f8:1c1a:7d21::1` (IPv6)

## Architecture

The platform consists of three main layers:

1. **Infrastructure Layer** (`codespartan/infra/`)
   - Terraform manages Hetzner Cloud VPS (ARM64 cax11 server type) and DNS
   - Providers: `hetznercloud/hcloud` and `timohirt/hetznerdns`
   - Automatic Docker installation via cloud-init in `main.tf`
   - Firewall configured for ports 22 (SSH), 80 (HTTP), 443 (HTTPS)

2. **Platform Layer** (`codespartan/platform/`)
   - **Traefik** (`platform/traefik/`): Reverse proxy with automatic Let's Encrypt SSL certificates
   - **Monitoring Stack** (`platform/stacks/monitoring/`): VictoriaMetrics, vmagent, Grafana, Loki, Promtail, cAdvisor, Node Exporter (7-day retention)
   - **Backoffice** (`platform/stacks/backoffice/`): Management dashboard

3. **Application Layer** (`codespartan/apps/`)
   - Multiple web applications with automatic subdomain routing
   - Examples: mambo-cloud, cyberdyne, dental-io
   - Each app has its own `docker-compose.yml` with Traefik labels for routing

## Common Commands

### Infrastructure Management

```bash
# Deploy infrastructure (Terraform)
cd codespartan/infra/hetzner
terraform init
terraform plan
terraform apply

# Destroy infrastructure (CAUTION)
terraform destroy
```

### Service Deployment

All services are deployed via docker-compose. The general pattern is:

```bash
# Deploy/Update a service
cd /opt/codespartan/[platform|apps]/[service-name]
docker compose pull
docker compose up -d

# View logs
docker logs [container-name] -f

# Restart service
docker compose restart
```

### Monitoring & Diagnostics

```bash
# SSH into VPS
ssh leonidas@91.98.137.217

# Check all running containers
docker ps

# View Traefik logs (critical for routing issues)
docker logs traefik -f

# System diagnostics script
/opt/codespartan/diagnostics.sh

# Monitor containers interactively
ctop
```

### DNS Verification

```bash
# Check DNS resolution
dig traefik.mambo-cloud.com
dig grafana.mambo-cloud.com

# Verify nameservers
dig NS mambo-cloud.com
# Should return: helium.ns.hetzner.de, hydrogen.ns.hetzner.de, oxygen.ns.hetzner.de
```

## CI/CD with GitHub Actions

### Sequential Deployment Order

Workflows must be executed in this order for initial deployment:

1. `deploy-infrastructure.yml` - Creates VPS + DNS (wait 5-10 min for Docker installation)
2. `deploy-traefik.yml` - Deploys reverse proxy
3. `deploy-monitoring.yml` - Deploys VictoriaMetrics + Grafana + Loki + Promtail stack
4. `deploy-backoffice.yml` - Deploys management dashboard
5. `deploy-mambo-cloud.yml` (or other apps) - Deploys applications

### Required GitHub Secrets

```
HCLOUD_TOKEN - Hetzner Cloud API token
HETZNER_DNS_TOKEN - Hetzner DNS API token
VPS_SSH_HOST - 91.98.137.217
VPS_SSH_USER - leonidas
VPS_SSH_KEY - Complete private SSH key content
```

### Automatic Deployment

Push to specific paths triggers automatic deployment:
- `codespartan/infra/hetzner/**` → Deploy Infrastructure
- `codespartan/platform/traefik/**` → Deploy Traefik
- `codespartan/platform/stacks/monitoring/**` → Deploy Monitoring
- `codespartan/apps/mambo-cloud/**` → Deploy Mambo Cloud App

## Configuration Files

### Terraform Variables (`codespartan/infra/hetzner/terraform.tfvars`)

```hcl
server_name = "codespartan-vps"
server_type = "cax11"  # ARM64 instance
location = "nbg1"      # Nuremberg
domains = ["mambo-cloud.com"]
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab"]
manual_ipv4_address = "91.98.137.217"
manual_ipv6_address = "2a01:4f8:1c1a:7d21::1"
```

### Docker Networks

**Network Isolation Pattern (Security Best Practice):**

Each application should have TWO networks for proper isolation:

1. **`web` network** (external): For Traefik to route traffic
2. **Internal network** (per-app): For communication between app services

```yaml
# Example: Frontend accessible via Traefik + communicates with DB
services:
  app:
    networks:
      - web           # Required for Traefik routing
      - myapp_net     # For internal DB/cache communication

  database:
    networks:
      - myapp_net     # ONLY internal - NOT accessible from internet

networks:
  web:
    external: true
  myapp_net:
    name: myapp_internal
    driver: bridge
    internal: true  # Maximum security: no internet access
    ipam:
      config:
        - subnet: 172.23.0.0/24
```

**Reserved subnets:**
- `172.20.0.0/24` - cyberdyne_internal
- `172.21.0.0/24` - dental_internal
- `172.22.0.0/24` - mambo_internal
- `172.23.0.0/24` - template example

**Why this matters:**
- Without network isolation, `cyberdyne-frontend` can directly communicate with `dental-io-db`
- With isolation, databases are only accessible by their own application services
- See `codespartan/apps/_TEMPLATE/NETWORK_ISOLATION.md` for detailed guide

### Traefik Labels Pattern

Services exposed via Traefik require these labels:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.[service].rule=Host(`subdomain.mambo-cloud.com`)
  - traefik.http.routers.[service].entrypoints=websecure
  - traefik.http.routers.[service].tls=true
  - traefik.http.routers.[service].tls.certresolver=le
  - traefik.docker.network=web
```

## Troubleshooting

### Service Not Accessible

1. Check container is running: `docker ps | grep [service-name]`
2. View container logs: `docker logs [service-name]`
3. Check Traefik routing: `docker logs traefik | grep [subdomain]`
4. Test internal routing: `curl -H "Host: subdomain.mambo-cloud.com" http://localhost`

### SSL Certificate Issues

```bash
# Check certificates
docker exec traefik ls -la /letsencrypt/

# Regenerate certificates (CAUTION)
docker exec traefik rm -f /letsencrypt/acme.json
docker restart traefik
```

### DNS Not Resolving

- Wait 2-5 minutes for DNS propagation
- Verify DNS records in Hetzner Console → DNS → mambo-cloud.com
- Check nameservers point to Hetzner: `dig NS mambo-cloud.com`

## Default Credentials

All management services use:
- Username: `admin`
- Password: `codespartan123`

Services:
- https://traefik.mambo-cloud.com
- https://grafana.mambo-cloud.com
- https://backoffice.mambo-cloud.com

## Important Notes

- The VPS is ARM64 architecture - ensure all Docker images support ARM64/linux/arm64
- Traefik handles automatic SSL certificate generation and renewal via Let's Encrypt
- All services log to stdout/stderr, collected by Promtail and queryable in Grafana → Loki
- The `web` Docker network is created during infrastructure provisioning
- Monitoring includes: CPU, RAM, Disk, Docker container metrics, HTTP request metrics from Traefik
- Alerts configured for: CPU > 80%, RAM > 90%, Disk > 85%, Service down > 2min

## Documentation

- `README.md` - Quick start guide and project overview
- `DEPLOY.md` - Detailed deployment checklist with troubleshooting
- `codespartan/docs/RUNBOOK.md` - Complete operational guide
- `codespartan/docs/BEGINNER.md` - Step-by-step beginner tutorial
- `codespartan/docs/GITHUB.md` - GitHub Actions CI/CD documentation
