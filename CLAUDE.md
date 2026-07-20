# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CodeSpartan Mambo Cloud Platform** - Complete Infrastructure as Code (IaC) for automated deployment on Hetzner Cloud ARM64 with Docker, Traefik reverse proxy, and full monitoring stack.

Primary domain: `mambo-cloud.com` (DNS managed in Hetzner). Also manages `cyberdyne-systems.es`, `codespartan.cloud`, `dental-io.com` (`codespartan.es` is managed separately in Hostinger/WordPress).

**Two VPS:**
- `CodeSpartan-alma` (cax11, ARM64, `91.98.137.217` / `2a01:4f8:1c1a:7d21::1`) — main VPS: Traefik, apps, monitoring, Authelia, Redmine, job-hunter.
- `CodeSpartan-apis` (cx33, x86, 7.3GB RAM) — secondary VPS for the APIs/DB tier, running self-hosted Supabase and Twenty CRM (`twenty-server`). Connected to the main VPS via a private Hetzner network (`10.0.0.0/24`); both services only listen on the private IP, proxied through the main VPS's Traefik.

## Architecture

**📖 For complete architecture documentation with diagrams:** See `docs/ARCHITECTURE.md`

### Current State (Functional)

The platform consists of three main layers:

1. **Infrastructure Layer** (`codespartan/infra/`)
   - Terraform manages both Hetzner Cloud VPS (main ARM64 `cax11` + secondary x86 `cx33`) and DNS
   - Provider: `hetznercloud/hcloud` only — DNS uses the native `hcloud_zone`/`hcloud_zone_rrset` resources (Cloud API). The old `timohirt/hetznerdns` provider is retired (Hetzner shut down `dns.hetzner.com`)
   - Automatic Docker installation via cloud-init in `main.tf`
   - Firewall configured for ports 22 (SSH), 80 (HTTP), 443 (HTTPS); private network between both VPS for internal traffic

2. **Platform Layer** (`codespartan/platform/`)
   - **Traefik** (`platform/traefik/`): Reverse proxy with automatic Let's Encrypt SSL certificates
   - **Authelia** (`platform/authelia/`): SSO with MFA protecting admin dashboards
   - **docker-socket-proxy** (`platform/docker-socket-proxy/`): Read-only proxy to the Docker API
   - **Portainer** (`platform/portainer/`): Docker management UI, behind Authelia
   - **Watchtower** (`platform/watchtower/`): Automatic image updates for labeled containers
   - **Kong API Gateway** (`platform/kong/`): only a `_TEMPLATE/` for new domains today — the Cyberdyne Kong instance was retired (redundant with Supabase's own Kong, see below)
   - **Monitoring Stack** (`platform/stacks/monitoring/`): VictoriaMetrics, vmagent, vmalert, Alertmanager, ntfy-forwarder, Grafana, Loki, Promtail, cAdvisor, Node Exporter
   - **Backoffice** (`platform/stacks/backoffice/`): Management dashboard
   - **Supabase** (`platform/supabase/`): self-hosted stack (Studio, Kong, Auth, PostgREST, Realtime, Storage, Postgres...) deployed on the secondary VPS (`CodeSpartan-apis`)

3. **Application Layer** (`codespartan/apps/`)
   - Multiple web applications with automatic subdomain routing
   - Real apps today: `codespartan-cloud/www` (corporate site), `codespartan-cloud/ui` (Storybook), `codespartan-cloud/redmine` (project management, replaced OpenProject), `codespartan-cloud/job-hunter` (bot + dashboard), `codespartan-cloud/crm` (Twenty CRM — server/worker/db/redis, deployed on the secondary VPS `CodeSpartan-apis`, not the main VPS), `cyberdyne-systems-es/www` (social posts app, backed by Supabase), `dental-io-com/www`, `mambo-cloud-com/www`
   - Each app has its own `docker-compose.yml` with Traefik labels for routing, **except `crm`**: it runs on the secondary VPS where Traefik doesn't run, so it publishes its port directly on the private IP (`10.0.0.3:3000`) instead of using Docker labels — routed via Traefik's file provider (`platform/traefik/dynamic-config.yml`, router `crm`), same pattern as `cyberdyne-api`
   - Many other subfolders under `apps/` are empty placeholders (`README.md` only) for future use

### Target State (Zero Trust Security - In Progress)

**Security Roadmap:**
- ✅ **docker-socket-proxy**: Filter for Docker API (eliminates Traefik direct access to socket)
- ⚠️ **Kong API Gateway** (Cyberdyne): retirado — Cyberdyne ahora se sirve desde Supabase self-hosted (2º VPS), que trae su propio Kong interno
- 🔄 **Kong API Gateway** (Otros dominios): Pendiente para dental-io, mambo-cloud (plantilla en `platform/kong/_TEMPLATE/`)
- ✅ **Authelia**: SSO con MFA implementado
- ✅ **Portainer**: Read-only dashboard behind Authelia
- ✅ **Network Isolation**: bases de datos aisladas por producto (Redmine, Supabase, Twenty CRM); ver `docs/02-architecture/NETWORK_ISOLATION_CURRENT.md`

**Key Concepts:**
- **docker-socket-proxy**: Security proxy that only allows GET operations to Docker API
- **Zero Trust**: Never trust, always verify - minimum privilege for all components
- **Network Isolation**: Each application domain has its own isolated network
- **Dual-Homed Containers**: Kong gateways bridge public (web) and private (internal) networks

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
HCLOUD_TOKEN - Hetzner Cloud API token (covers both VPS + DNS, hcloud_zone)
VPS_SSH_PUBLIC_KEY - SSH public key provisioned on the main VPS (TF_VAR_ssh_public_key_content)
APIS_DEPLOY_SSH_PUBLIC_KEY - SSH public key for the non-root 'deploy' user on the secondary VPS
VPS_SSH_HOST - 91.98.137.217
VPS_SSH_USER - leonidas
VPS_SSH_KEY - Complete private SSH key content
```
(Note: `HETZNER_DNS_TOKEN` is obsolete — DNS now goes through the same `HCLOUD_TOKEN`/`hcloud` provider.)

### Automatic Deployment

Push to specific paths triggers automatic deployment (21 `deploy-*` workflows in total; see `.github/workflows/`):
- `codespartan/infra/hetzner/**` → Deploy Infrastructure (both VPS + DNS)
- `codespartan/platform/traefik/**` → Deploy Traefik
- `codespartan/platform/stacks/monitoring/**` → Deploy Monitoring
- `codespartan/platform/supabase/**` → Deploy Supabase (secondary VPS)
- `codespartan/apps/codespartan-cloud/redmine/**` → Deploy Redmine
- `codespartan/apps/codespartan-cloud/crm/**` → Deploy Twenty CRM (secondary VPS)
- `codespartan/apps/mambo-cloud-com/**` → Deploy Mambo Cloud App
- Each app/platform folder under `codespartan/` follows the same pattern — one `deploy-*.yml` per path prefix

## Configuration Files

### Terraform Variables (`codespartan/infra/hetzner/terraform.tfvars`)

```hcl
server_name = "CodeSpartan-alma"
server_type = "cax11"  # ARM64 instance (main VPS)
location = "nbg1"      # Nuremberg

server2_name = "CodeSpartan-apis"
server2_type = "cx33"  # x86 instance (secondary VPS: APIs/DB tier, Supabase)
server2_location = "nbg1"

domains = ["mambo-cloud.com", "cyberdyne-systems.es", "codespartan.cloud", "dental-io.com"]
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "lab-staging", "api", "api-staging", "project", "ui", "mambo", "portainer", "crm"]
manual_ipv4_address = "91.98.137.217"
manual_ipv6_address = "2a01:4f8:1c1a:7d21::1"
```

(`codespartan.es` — the corporate identity site — is hosted on Hostinger/WordPress and is **not** managed by this Terraform.)

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
- `172.20.0.0/16` - web (Traefik routing)
- `172.21.0.0/24` - authelia_internal
- `172.22.0.0/24` - api_trackworks (RETIRED — Cyberdyne now runs on Supabase self-hosted, secondary VPS)
- `172.24.0.0/24` - monitoring stack
- `172.25.0.0/24` - docker_api (socket proxy, internal)
- `172.26.0.0/24` - kong_cyberdyne (RETIRED — redundant with Supabase's own Kong)
- `172.27.0.0/24` - reserved for kong_dental (future)
- `172.28.0.0/24` - reserved for kong_mambo (future)
- `172.29.0.0/24` - mambo_internal
- `172.30.0.0/24` - dental_internal
- `172.31.0.0/24` - redmine_internal (permanent — each product keeps its own dedicated PostgreSQL, no shared instance)

Note: the secondary VPS (`CodeSpartan-apis`) has its own separate subnet ranges, managed independently — Supabase uses `172.20.0.0/24` (`supabase_internal`, within `platform/supabase/`) and Twenty CRM uses `172.34.0.0/24` (`crm_internal`, within `apps/codespartan-cloud/crm/`). Neither is part of this `172.x` range used on the main VPS. Unlike Supabase/Kong and the main VPS's isolated networks, `crm_internal` is a plain bridge network (no `internal: true`) — that flag silently breaks Docker's published-port NAT rules when a container's only network is internal, which is exactly what happened when `crm` was moved here (see git history).

**Why this matters:**
- Without network isolation, `cyberdyne-frontend` can directly communicate with `dental-io-db`
- With isolation, databases are only accessible by their own application services
- See `codespartan/apps/_TEMPLATE/NETWORK_ISOLATION.md` for detailed guide

### Resource Limits

**All containers MUST have resource limits** to prevent resource exhaustion and ensure system stability. Resource limits are applied using Docker Compose `deploy.resources` configuration.

**Resource Allocation Guidelines:**

| Service Type | Memory Limit | CPU Limit | Example |
|-------------|--------------|-----------|---------|
| Databases | 512M - 1G | 0.5 - 1.0 | MongoDB, VictoriaMetrics |
| API/Backend | 512M | 0.5 | Node.js, Python APIs |
| API Gateway | 512M | 0.5 | Kong (uso real ~150-200MB) |
| Frontend/Web | 512M | 0.5 | React, Vue apps |
| Reverse Proxy | 512M | 0.5 | Traefik, Grafana, Loki |
| Metrics Collectors | 256M | 0.25 | vmagent, Promtail, cAdvisor |
| Static Sites | 128M | 0.25 | Nginx serving static content |
| Exporters | 128M | 0.1 - 0.15 | Node Exporter, vmalert |

**Standard Pattern:**

```yaml
services:
  myapp:
    # ... other configuration ...
    deploy:
      resources:
        limits:
          cpus: '0.5'      # Maximum CPU cores
          memory: 512M     # Maximum RAM
        reservations:
          cpus: '0.1'      # Minimum guaranteed CPU
          memory: 128M     # Minimum guaranteed RAM
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

**Important Notes:**
- Resource limits only apply when containers are CREATED/RECREATED (not to running containers)
- To apply new limits: `docker compose down && docker compose up -d`
- Verify limits: `docker stats --no-stream`
- VPS has 3.4GB total RAM - sum of limits should not exceed ~4GB (containers won't all max out simultaneously)
- Health checks enable automatic container restart on failure

**Current Resource Allocation:**
- See `docs/02-architecture/RESOURCES.md` for complete breakdown (covers both VPS)
- Overcommitted by design (safe because of diverse workloads that rarely peak simultaneously)

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

## Alerting System

The platform includes a complete alerting pipeline for proactive monitoring:

### Architecture

```
vmalert → Alertmanager → ntfy-forwarder → ntfy.sh → Mobile/Web
```

**Components:**
- **vmalert**: Evaluates alert rules against VictoriaMetrics metrics
- **Alertmanager**: Groups, deduplicates, and routes alerts by severity
- **ntfy-forwarder**: Custom webhook forwarder (Alertmanager → ntfy.sh format)
- **ntfy.sh**: Public push notification service

### Configured Alerts

| Category | Alerts | Conditions |
|----------|--------|------------|
| Infrastructure | CPU, RAM, Disk | Warning: 80%/90%/85%, Critical: 95%/95%/95% |
| Services | ServiceDown, ContainerDown | Down for > 2 minutes |
| VictoriaMetrics | High Memory, Storage Issues | > 1.5GB RAM, < 5GB free disk |
| Traefik | HTTP 5xx Errors | Warning: >10/s, Critical: >50/s |

### Receiving Alerts

**Mobile App (Recommended):**
1. Install "ntfy" from [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy) or [App Store](https://apps.apple.com/app/ntfy/id1625396347)
2. Subscribe to topic: `codespartan-mambo-alerts`

**Web Browser:**
- https://ntfy.sh/codespartan-mambo-alerts

**Command Line:**
```bash
curl -s ntfy.sh/codespartan-mambo-alerts/json
```

### Alert Severities

- **Critical**: Immediate notification, repeat every 1h, priority 5 (max)
- **Warning**: 30s grouping, repeat every 12h, priority 4

### Common Operations

```bash
# View active alerts
ssh leonidas@91.98.137.217
curl http://localhost:8880/api/v1/rules

# Check alertmanager status
curl http://localhost:9093/api/v2/alerts

# Silence alert temporarily (1 hour)
curl -X POST http://localhost:9093/api/v2/silences -H "Content-Type: application/json" -d '{
  "matchers": [{"name": "alertname", "value": "HighCPUUsage", "isRegex": false}],
  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
  "createdBy": "admin",
  "comment": "Maintenance window"
}'
```

**For complete documentation**, see `codespartan/docs/ALERTS.md`

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

### Platform Characteristics
- The VPS is ARM64 architecture - ensure all Docker images support ARM64/linux/arm64
- Traefik handles automatic SSL certificate generation and renewal via Let's Encrypt
- All services log to stdout/stderr, collected by Promtail and queryable in Grafana → Loki
- The `web` Docker network is created during infrastructure provisioning
- Monitoring includes: CPU, RAM, Disk, Docker container metrics, HTTP request metrics from Traefik
- Alerts configured for: CPU > 80%, RAM > 90%, Disk > 85%, Service down > 2min

### Security Considerations (Current State)

✅ **Implemented Security Features:**
1. **docker-socket-proxy**: Traefik and Portainer access Docker only through a read-only proxy, not the raw socket
2. **Authelia SSO**: MFA habilitado para dashboards administrativos
   - Protege: Traefik dashboard, Grafana, Backoffice, Portainer
3. **Network Isolation**: bases de datos aisladas por producto — Redmine (`redmine_internal`, VPS principal), Supabase y Twenty CRM (`crm_internal`, ambos en el 2º VPS con red propia)
4. **Kong API Gateway** (Supabase): el propio stack de Supabase self-hosted trae su Kong, escuchando solo en la IP privada del 2º VPS — el antiguo Kong dedicado a Cyberdyne fue retirado por redundante
5. **Twenty CRM** (2º VPS): igual que Kong, `twenty-server` publica su puerto solo en la IP privada (`10.0.0.3:3000`) — Traefik, en el VPS principal, termina TLS y reenvía vía el file provider (`platform/traefik/dynamic/dynamic-config.yml`, router `crm`)

⚠️ **Known Security Gaps (Being Addressed):**
1. **Kong pending for other domains**
   - Risk: dental-io, mambo-cloud sin rate limiting
   - Solution: Replicar patrón Kong para otros dominios (plantilla en `platform/kong/_TEMPLATE/`)

**When making changes to the architecture, consult `docs/ARCHITECTURE.md` for the target state and migration plan.**

### Replicability

This project is designed as a **replicable template**:
- Each new project/client = 1 dedicated VPS with full stack
- Customize `terraform.tfvars` and `.env` files for new domain
- Deploy full stack in ~30 minutes via GitHub Actions
- Independent infrastructure per project (no multi-tenancy)

## Documentation

### Architecture and Design
- **`docs/02-architecture/ARCHITECTURE.md`** - Complete architecture with high/low-level diagrams, security roadmap, and glossary of concepts (docker-socket-proxy, Kong, Authelia, Zero Trust)
- **`docs/02-architecture/KONG.md`** - Kong API Gateway configuration, commands, and troubleshooting

### Quick Start and Overview
- `README.md` - Quick start guide and project overview
- `docs/04-deployment/DEPLOYMENT.md` - Detailed deployment checklist with troubleshooting
- `docs/01-getting-started/BEGINNER.md` - Step-by-step beginner tutorial
- `docs/01-getting-started/QUICK_START.md` - Quick deployment guide

### Operations
- `docs/03-operations/RUNBOOK.md` - Complete operational guide
- `docs/02-architecture/RESOURCES.md` - Resource limits and management guide
- `docs/03-operations/MONITORING.md` - Complete alerting system documentation

### CI/CD and Deployment
- `docs/04-deployment/GITHUB.md` - GitHub Actions CI/CD documentation
- `docs/04-deployment/ADDING_APPS.md` - How to add new applications

### Security and Monitoring
- `docs/05-security/AUTHELIA.md` - Authelia SSO documentation
- `docs/05-security/FAIL2BAN.md` - Fail2ban protection
- `docs/apps/_TEMPLATE/NETWORK_ISOLATION.md` - Network isolation patterns
- `codespartan/platform/traefik/README.md` - Traefik configuration and SSL troubleshooting

### Business & Marketing
- `docs/06-implementation/PIPELINE_COMERCIAL.md` - Pipeline comercial completo: PostgreSQL compartido, Twenty CRM, Brevo campañas, Redmine branding

### Complete Documentation Index
- `docs/README.md` - Complete documentation index
