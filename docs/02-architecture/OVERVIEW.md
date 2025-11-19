# CodeSpartan Mambo Cloud Platform - System Overview

Complete architectural overview and component guide for understanding the entire platform.

**Last Updated:** 2025-10-08
**Version:** 1.0.0
**Status:** Production Ready

---

## 📋 Table of Contents

1. [Platform Summary](#platform-summary)
2. [Architecture Overview](#architecture-overview)
3. [Infrastructure Layer](#infrastructure-layer)
4. [Platform Layer](#platform-layer)
5. [Application Layer](#application-layer)
6. [Security Layer](#security-layer)
7. [Monitoring & Observability](#monitoring--observability)
8. [Networking](#networking)
9. [Data Flow](#data-flow)
10. [Backup & Recovery](#backup--recovery)
11. [Deployment Pipeline](#deployment-pipeline)

---

## Platform Summary

### What is This?

CodeSpartan Mambo Cloud Platform is a **production-ready, self-hosted cloud infrastructure** running on Hetzner Cloud. It provides:

- **Automated infrastructure** provisioning with Terraform
- **Reverse proxy** with automatic SSL certificates (Traefik)
- **Complete monitoring** stack (VictoriaMetrics, Grafana, Loki)
- **Automated backups** with disaster recovery
- **CI/CD pipelines** with GitHub Actions
- **Security hardening** (Fail2ban, rate limiting, network isolation)

### Key Metrics

| Metric | Value |
|--------|-------|
| **VPS Provider** | Hetzner Cloud |
| **Server Type** | ARM64 (cax11) |
| **CPU Cores** | 2 vCPUs |
| **RAM** | 4 GB |
| **Disk** | 40 GB SSD |
| **Bandwidth** | 20 TB/month |
| **Location** | Nuremberg (nbg1) |
| **IPv4** | 91.98.137.217 |
| **IPv6** | 2a01:4f8:1c1a:7d21::1 |
| **Primary Domain** | mambo-cloud.com |
| **Operating System** | AlmaLinux 9 (ARM64) |
| **Container Runtime** | Docker 26.x + Compose |
| **Monthly Cost** | ~€4.49 (VPS only) |

### Current Resource Usage

```
CPU:    ~5-10% (idle)
RAM:    ~37% (1.5GB / 4GB)
Disk:   ~12% (4GB / 38GB)
```

### Running Services

**Total Containers:** 10

1. **traefik** - Reverse proxy & SSL termination
2. **victoriametrics** - Metrics database (7-day retention)
3. **vmagent** - Metrics collector
4. **vmalert** - Alerting engine (14 rules)
5. **loki** - Log aggregation (7-day retention)
6. **promtail** - Log collector
7. **grafana** - Visualization & dashboards
8. **cadvisor** - Container metrics exporter
9. **node-exporter** - System metrics exporter
10. **backoffice** - Management dashboard

---

## Architecture Overview

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET                                  │
│                           ↓↓↓                                    │
│                    DNS (Hetzner DNS)                             │
│              *.mambo-cloud.com → 91.98.137.217                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: INFRASTRUCTURE (Hetzner Cloud)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  VPS: codespartan-vps (ARM64 cax11)                        │ │
│  │  - Firewall: SSH(22), HTTP(80), HTTPS(443)                 │ │
│  │  - Fail2ban: SSH protection (5 attempts = 10min ban)       │ │
│  │  - Docker Engine + Compose                                 │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 2: PLATFORM (Docker Containers)                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  TRAEFIK (Port 80/443)                                     │ │
│  │  - Automatic SSL (Let's Encrypt)                           │ │
│  │  - Rate Limiting (3 levels)                                │ │
│  │  - Security Headers                                        │ │
│  │  - Compression (gzip)                                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              ↓                                   │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │  PUBLIC NETWORK  │  │ MONITORING NET   │                    │
│  │  (web)           │  │ (monitoring)     │                    │
│  │                  │  │                  │                    │
│  │  - Grafana       │  │ - VictoriaMetrics│                    │
│  │  - Backoffice    │  │ - Loki           │                    │
│  │  - Apps          │  │ - vmalert        │                    │
│  │                  │  │ - Promtail       │                    │
│  │                  │  │ - cAdvisor       │                    │
│  │                  │  │ - Node Exporter  │                    │
│  └──────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 3: APPLICATIONS                                           │
│  - mambo-cloud (www, staging, lab subdomains)                   │
│  - cyberdyne                                                     │
│  - dental-io                                                     │
│  - [Your apps using _TEMPLATE]                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
iac-code-spartan/
├── codespartan/
│   ├── infra/               # Infrastructure as Code
│   │   └── hetzner/         # Terraform for Hetzner Cloud
│   │       ├── main.tf      # VPS, firewall, DNS configuration
│   │       ├── variables.tf # Input variables
│   │       ├── outputs.tf   # Output values (IP, domain)
│   │       └── terraform.tfvars # Configuration values
│   │
│   ├── platform/            # Platform services
│   │   ├── traefik/         # Reverse proxy
│   │   │   ├── docker-compose.yml
│   │   │   ├── dynamic-config.yml  # Rate limiting, security
│   │   │   ├── letsencrypt/        # SSL certificates
│   │   │   └── users.htpasswd      # Basic auth
│   │   │
│   │   └── stacks/
│   │       ├── monitoring/  # VictoriaMetrics + Grafana + Loki
│   │       │   ├── docker-compose.yml
│   │       │   ├── victoriametrics/  # Metrics scrape config
│   │       │   ├── alerts/           # Alert rules (14 rules)
│   │       │   ├── loki/             # Log aggregation config
│   │       │   ├── promtail/         # Log collection config
│   │       │   └── grafana/          # Dashboards + datasources
│   │       │
│   │       └── backoffice/  # Management dashboard
│   │           ├── docker-compose.yml
│   │           └── html/             # Static dashboard
│   │
│   ├── apps/                # Application containers
│   │   ├── _TEMPLATE/       # Template for new apps
│   │   │   ├── docker-compose.yml
│   │   │   ├── README.md
│   │   │   ├── .env.example
│   │   │   └── healthcheck.sh
│   │   ├── mambo-cloud/     # Example app
│   │   ├── cyberdyne/
│   │   └── dental-io/
│   │
│   ├── scripts/             # Maintenance & operations
│   │   ├── backup.sh                 # Daily backups (cron)
│   │   ├── restore.sh                # Disaster recovery
│   │   ├── cleanup.sh                # System cleanup
│   │   ├── health-check.sh           # Health monitoring
│   │   ├── update-containers.sh      # Update services
│   │   ├── install-fail2ban.sh       # Security setup
│   │   ├── test-rate-limit.sh        # Rate limit testing
│   │   ├── check-ssl-renewal.sh      # SSL verification
│   │   └── diagnostics.sh            # System diagnostics
│   │
│   └── docs/                # Documentation
│       ├── OVERVIEW.md      # This file
│       ├── RUNBOOK.md       # Operations guide
│       ├── [ADDING_APPS.md](../04-deployment/ADDING_APPS.md)   # App deployment guide
│       ├── ALERTS.md        # Alert documentation
│       ├── DASHBOARDS.md    # Grafana dashboards
│       ├── [DISASTER_RECOVERY.md](../03-operations/DISASTER_RECOVERY.md)  # DR procedures
│       ├── APPLICATIONS.md  # App management runbook
│       ├── TROUBLESHOOTING.md    # Problem solving
│       ├── SECURITY.md      # Security guide
│       └── ADRs/            # Architecture decisions
│
├── .github/workflows/       # CI/CD pipelines
│   ├── deploy-infrastructure.yml
│   ├── deploy-traefik.yml
│   ├── deploy-monitoring.yml
│   ├── deploy-backoffice.yml
│   ├── deploy-backup-system.yml
│   ├── _template-deploy.yml
│   └── deploy-*.yml         # Per-app workflows
│
├── README.md                # Quick start
├── DEPLOY.md                # Deployment guide
├── ROADMAP.md               # Development roadmap (ver docs/06-implementation/ROADMAP.md)
└── [CLAUDE.md](../../CLAUDE.md)                # AI assistant context
```

---

## Infrastructure Layer

### Terraform Configuration

**Purpose:** Provision and manage Hetzner Cloud infrastructure

**Location:** `codespartan/infra/hetzner/`

**Components:**

#### 1. VPS Server (`main.tf`)

```hcl
Server Type:     cax11 (ARM64)
Location:        nbg1 (Nuremberg, Germany)
Image:           alma-9 (AlmaLinux 9 ARM64)
IPv4:            91.98.137.217 (static, pre-allocated)
IPv6:            2a01:4f8:1c1a:7d21::1 (static, pre-allocated)
SSH Key:         Injected via Terraform
Firewall:        Attached (see below)
Cloud-init:      Docker + Fail2ban installation
```

**Cloud-init Tasks:**
- Install Docker Engine + Compose plugin
- Create `web` network for Traefik
- Install Fail2ban (EPEL repository)
- Configure SSH jail (5 attempts, 10min ban)

#### 2. Firewall (`main.tf`)

```
Inbound Rules:
  - Port 22 (SSH)         from 0.0.0.0/0, ::/0
  - Port 80 (HTTP)        from 0.0.0.0/0, ::/0
  - Port 443 (HTTPS)      from 0.0.0.0/0, ::/0

Outbound Rules:
  - All traffic allowed (for updates, DNS, etc.)
```

**Why these ports?**
- **22 (SSH):** Server management, protected by Fail2ban
- **80 (HTTP):** Let's Encrypt HTTP-01 challenge, redirects to HTTPS
- **443 (HTTPS):** All application traffic (SSL terminated by Traefik)

#### 3. DNS Management (`main.tf`)

**Provider:** Hetzner DNS
**Zone:** mambo-cloud.com

**Records Created:**

| Type | Name | Value | TTL | Purpose |
|------|------|-------|-----|---------|
| A | traefik | 91.98.137.217 | 120s | Traefik dashboard |
| A | grafana | 91.98.137.217 | 120s | Grafana UI |
| A | backoffice | 91.98.137.217 | 120s | Management panel |
| A | www | 91.98.137.217 | 120s | Main website |
| A | staging | 91.98.137.217 | 120s | Staging environment |
| A | lab | 91.98.137.217 | 120s | Lab environment |
| AAAA | [same] | 2a01:4f8:1c1a:7d21::1 | 300s | IPv6 support |

**Why short TTL (120s)?**
- Faster DNS propagation during changes
- Easier failover/migration if needed
- Minimal impact on DNS query volume

### State Management

```
Backend:        Local filesystem
State File:     terraform.tfstate
Lock:           Not configured (single operator)
Backup:         Included in daily backups
```

**For production with team:**
```hcl
terraform {
  backend "s3" {
    bucket = "codespartan-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

---

## Platform Layer

### Traefik (Reverse Proxy)

**Purpose:** Route incoming traffic, SSL termination, security

**Location:** `codespartan/platform/traefik/`

**Container:** `traefik:v2.11`

#### Configuration

**Static Configuration** (docker-compose.yml command flags):

```yaml
API & Dashboard:
  - Dashboard enabled (protected by basic auth)
  - Accessible at: https://traefik.mambo-cloud.com

Entry Points:
  - web (port 80):      HTTP → redirect to HTTPS
  - websecure (port 443): HTTPS traffic

Providers:
  - Docker:  Auto-discover containers with labels
  - File:    Load dynamic-config.yml for middlewares

SSL/TLS:
  - Resolver: Let's Encrypt (le)
  - Challenge: HTTP-01 (via port 80)
  - Email: iam@codespartan.es
  - Storage: /letsencrypt/acme.json (42KB, 600 permissions)
  - Auto-renewal: When cert < 30 days from expiry

Metrics:
  - Prometheus format on :8080/metrics
  - Scraped by vmagent every 15s
  - Labels: entrypoints, services
```

**Dynamic Configuration** (dynamic-config.yml):

```yaml
Middlewares:
  rate-limit-global:  100 req/s, burst 50
  rate-limit-strict:  10 req/s, burst 20
  rate-limit-api:     50 req/s, burst 30

  security-headers:
    - X-XSS-Protection: 1; mode=block
    - X-Content-Type-Options: nosniff
    - X-Frame-Options: SAMEORIGIN
    - Strict-Transport-Security: max-age=31536000

  compression:
    - Gzip compression for responses

  cors-api:
    - Access-Control-Allow-Methods: GET,POST,PUT,DELETE
    - Access-Control-Allow-Origin: *

TLS Options:
  - Minimum version: TLS 1.2
  - Cipher suites: Modern, secure only
```

#### Routing Example

```yaml
# Application requests route via labels
labels:
  - traefik.enable=true
  - traefik.http.routers.app.rule=Host(`app.mambo-cloud.com`)
  - traefik.http.routers.app.entrypoints=websecure
  - traefik.http.routers.app.tls.certresolver=le
  - traefik.http.routers.app.middlewares=rate-limit-global@file
```

**Flow:**
1. User requests `https://app.mambo-cloud.com`
2. DNS resolves to 91.98.137.217
3. Request hits Traefik on port 443
4. Traefik matches `Host()` rule
5. Applies middleware (rate limit)
6. SSL terminates (cert from acme.json)
7. Forwards to container on internal network
8. Response compressed, headers added
9. Returned to user

#### SSL Certificates

**Current Status:**
- traefik.mambo-cloud.com: Valid 85 days (Let's Encrypt R12)
- grafana.mambo-cloud.com: Valid 86 days (Let's Encrypt R13)
- backoffice.mambo-cloud.com: Valid 86 days (Let's Encrypt R13)

**Renewal Process:**
1. Traefik checks cert expiry every 24h
2. If < 30 days remaining, starts renewal
3. HTTP-01 challenge: Let's Encrypt hits http://domain/.well-known/acme-challenge/
4. Traefik responds, proves domain ownership
5. New cert issued, stored in acme.json
6. Old cert replaced atomically
7. No downtime

**Storage:**
```
/opt/codespartan/platform/traefik/letsencrypt/
└── acme.json (600 permissions, 42KB)
    ├── Private keys
    ├── Certificates
    └── Metadata
```

---

### Monitoring Stack

**Purpose:** Metrics collection, visualization, alerting, logging

**Location:** `codespartan/platform/stacks/monitoring/`

**Containers:** 8 (VictoriaMetrics, vmagent, vmalert, Loki, Promtail, Grafana, cAdvisor, Node Exporter)

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  DATA SOURCES                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Traefik  │  │ cAdvisor │  │  Node    │              │
│  │ :8080    │  │ :8080    │  │ Exporter │              │
│  │          │  │          │  │ :9100    │              │
│  │ HTTP     │  │ Container│  │ System   │              │
│  │ metrics  │  │ metrics  │  │ metrics  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│       ↓              ↓              ↓                    │
│  ┌────────────────────────────────────────┐             │
│  │         vmagent (Scraper)              │             │
│  │  - Scrapes every 15s                   │             │
│  │  - Relabels, filters                   │             │
│  │  - Pushes to VictoriaMetrics           │             │
│  └────────────────────────────────────────┘             │
│                      ↓                                   │
│  ┌────────────────────────────────────────┐             │
│  │    VictoriaMetrics (TSDB)              │             │
│  │  - 7-day retention                     │             │
│  │  - 35MB storage                        │             │
│  │  - PromQL queries                      │             │
│  └────────────────────────────────────────┘             │
│           ↓                        ↓                     │
│  ┌──────────────┐       ┌──────────────┐               │
│  │   vmalert    │       │   Grafana    │               │
│  │  Evaluates   │       │  Visualizes  │               │
│  │  14 rules    │       │  5 dashboards│               │
│  │  every 30s   │       │              │               │
│  └──────────────┘       └──────────────┘               │
│         ↓                                                │
│  ┌──────────────┐                                       │
│  │   ntfy.sh    │                                       │
│  │  Push alerts │                                       │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  LOGS PIPELINE                                           │
│  ┌──────────────────────────────────────────┐           │
│  │  All Docker Containers                   │           │
│  │  stdout/stderr → /var/lib/docker/...     │           │
│  └──────────────────────────────────────────┘           │
│                      ↓                                   │
│  ┌──────────────────────────────────────────┐           │
│  │         Promtail (Log Collector)         │           │
│  │  - Reads Docker logs                     │           │
│  │  - Adds labels (container, compose)      │           │
│  │  - Pushes to Loki                        │           │
│  └──────────────────────────────────────────┘           │
│                      ↓                                   │
│  ┌──────────────────────────────────────────┐           │
│  │         Loki (Log Aggregator)            │           │
│  │  - 7-day retention                       │           │
│  │  - LogQL queries                         │           │
│  │  - ~5MB storage                          │           │
│  └──────────────────────────────────────────┘           │
│                      ↓                                   │
│  ┌──────────────────────────────────────────┐           │
│  │         Grafana (Log Explorer)           │           │
│  │  - Query: {container_name="traefik"}     │           │
│  │  - Filter, search, tail                  │           │
│  └──────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

#### Component Details

**1. VictoriaMetrics** (TSDB)
- **Purpose:** Time-series metrics database
- **Port:** 8428 (internal only)
- **Storage:** `/storage` volume (35MB)
- **Retention:** 7 days
- **API:** Prometheus-compatible
- **Performance:** ~10MB RAM, handles 1M+ samples/sec

**2. vmagent** (Metrics Collector)
- **Purpose:** Scrape metrics from exporters
- **Config:** `victoriametrics/prometheus.yml`
- **Scrape Interval:** 15s
- **Targets:**
  - traefik:8080 - HTTP request metrics
  - cadvisor:8080 - Container metrics
  - node-exporter:9100 - System metrics
  - victoriametrics:8428 - Internal metrics

**3. vmalert** (Alerting Engine)
- **Purpose:** Evaluate alert rules, send notifications
- **Config:** `alerts/*.yml` (14 rules)
- **Evaluation:** Every 30s
- **Destination:** ntfy.sh/codespartan-mambo-alerts
- **Rules:** 6 CRITICAL, 8 WARNING

**Alert Examples:**
```yaml
# CRITICAL: Service Down
- alert: ServiceDown
  expr: up == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "{{ $labels.job }} is down"

# WARNING: High CPU
- alert: HighCPU
  expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
  for: 5m
  labels:
    severity: warning
```

**4. Loki** (Log Aggregator)
- **Purpose:** Collect and store container logs
- **Port:** 3100 (internal only)
- **Storage:** `/loki` volume (5MB)
- **Retention:** 7 days
- **Query:** LogQL (similar to PromQL)

**5. Promtail** (Log Collector)
- **Purpose:** Ship container logs to Loki
- **Config:** `promtail/promtail.yml`
- **Source:** `/var/lib/docker/containers` (read-only)
- **Labels:** Adds container_name, compose_project

**6. Grafana** (Visualization)
- **Purpose:** Dashboards, exploration, alerting UI
- **Port:** 3000 → exposed via Traefik
- **URL:** https://grafana.mambo-cloud.com
- **Auth:** admin / codespartan123
- **Datasources:**
  - VictoriaMetrics (default, metrics)
  - Loki (logs)
- **Dashboards:** 5 imported
  1. Node Exporter Full (ID: 1860)
  2. Traefik Official (ID: 17346)
  3. Docker Monitoring (ID: 193)
  4. VictoriaMetrics Cluster (ID: 11176)
  5. Loki Logs (ID: 13639)

**7. cAdvisor** (Container Metrics)
- **Purpose:** Export Docker container metrics
- **Port:** 8080 (internal)
- **Metrics:** CPU, RAM, network, disk per container
- **Privileges:** Access to Docker socket, /sys, /proc

**8. Node Exporter** (System Metrics)
- **Purpose:** Export system-level metrics
- **Port:** 9100 (internal)
- **Metrics:** CPU, RAM, disk, network, load, processes
- **Collectors:** ~50 enabled

#### Network Isolation

```yaml
networks:
  web:          # Public-facing (Grafana only)
    external: true

  monitoring:   # Internal-only (all other services)
    driver: bridge
    name: monitoring
```

**Rationale:**
- VictoriaMetrics, Loki, cAdvisor, Node Exporter **NOT exposed** to internet
- Only Grafana accessible via Traefik (with auth)
- Reduced attack surface
- vmagent bridges both networks to scrape Traefik

---

### Backoffice Dashboard

**Purpose:** Quick access panel for all management services

**Location:** `codespartan/platform/stacks/backoffice/`

**Container:** `nginx:alpine`

**URL:** https://backoffice.mambo-cloud.com

**Authentication:** Basic auth (admin / codespartan123)

**Security Middlewares:**
- `backoffice-auth` - Basic authentication
- `rate-limit-strict@file` - 10 req/s
- `security-headers@file` - XSS, HSTS, frame deny
- `compression@file` - Gzip

**Content:** Static HTML dashboard with links to:
- Traefik Dashboard
- Grafana
- VictoriaMetrics
- Direct links to GitHub Actions
- Documentation links

---

## Application Layer

### Application Template

**Purpose:** Standardized structure for deploying new apps

**Location:** `codespartan/apps/_TEMPLATE/`

**Files:**
- `docker-compose.yml` - Traefik-integrated configuration
- `../README.md` - Deployment instructions
- `.env.example` - Environment variables template
- `healthcheck.sh` - Container health check script

### Deployed Applications

#### 1. mambo-cloud

**Subdomains:** www, staging, lab
**Type:** Static website (nginx:alpine)
**Purpose:** Main website with multiple environments

```yaml
Routing:
  - www.mambo-cloud.com → Production
  - staging.mambo-cloud.com → Staging env
  - lab.mambo-cloud.com → Experimental

Content: ./html → /usr/share/nginx/html
```

#### 2. cyberdyne

**Type:** Application container
**Subdomain:** cyberdyne.mambo-cloud.com

#### 3. dental-io

**Type:** Application container
**Subdomain:** dental-io.mambo-cloud.com

---

## Security Layer

### Defense in Depth

```
Layer 1: Network Firewall (Hetzner)
  ├─ Only ports 22, 80, 443 exposed
  └─ All other ports blocked

Layer 2: Fail2ban (Host)
  ├─ SSH brute-force protection
  ├─ 5 failed attempts = 10 min ban
  └─ Monitors /var/log/secure

Layer 3: Traefik Rate Limiting
  ├─ Global: 100 req/s per IP
  ├─ Strict: 10 req/s per IP (admin panels)
  └─ API: 50 req/s per IP

Layer 4: Docker Network Isolation
  ├─ web: Public services only
  └─ monitoring: Internal services isolated

Layer 5: Application Auth
  ├─ Traefik: Basic auth (htpasswd)
  ├─ Grafana: User/pass + sessions
  └─ Backoffice: Basic auth

Layer 6: Security Headers (Traefik)
  ├─ HSTS: Force HTTPS for 1 year
  ├─ X-Frame-Options: SAMEORIGIN
  ├─ X-Content-Type-Options: nosniff
  └─ X-XSS-Protection: enabled
```

### SSL/TLS

**Certificate Authority:** Let's Encrypt
**Validation:** HTTP-01 Challenge
**Renewal:** Automatic (< 30 days expiry)
**Supported Protocols:** TLS 1.2, TLS 1.3
**Cipher Suites:** Modern, secure only

**Certificates Issued:**
```
CN: traefik.mambo-cloud.com
  Issuer: Let's Encrypt R12
  Valid: 85 days
  SAN: traefik.mambo-cloud.com

CN: grafana.mambo-cloud.com
  Issuer: Let's Encrypt R13
  Valid: 86 days
  SAN: grafana.mambo-cloud.com, backoffice.mambo-cloud.com
```

### Fail2ban Configuration

**Location:** `/etc/fail2ban/jail.local`

```ini
[DEFAULT]
bantime  = 10m      # Ban duration
findtime = 10m      # Time window
maxretry = 5        # Failed attempts

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/secure
maxretry = 5

[sshd-ddos]
enabled  = true
port     = ssh
maxretry = 10       # More lenient for DDOS patterns
```

**Commands:**
```bash
# Check status
fail2ban-client status

# Check SSH jail
fail2ban-client status sshd

# Unban IP
fail2ban-client set sshd unbanip 1.2.3.4

# View banned IPs
fail2ban-client get sshd banned
```

---

## Monitoring & Observability

### Metrics

**Collection:** vmagent scrapes every 15s
**Storage:** VictoriaMetrics (7-day retention)
**Visualization:** Grafana dashboards
**Query Language:** PromQL

**Key Metrics:**

```promql
# Request rate
rate(traefik_service_requests_total[5m])

# Error rate
rate(traefik_service_requests_total{code=~"5.."}[5m])

# Container CPU
rate(container_cpu_usage_seconds_total[5m])

# Container memory
container_memory_usage_bytes

# System load
node_load1, node_load5, node_load15

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

### Logs

**Collection:** Promtail
**Storage:** Loki (7-day retention)
**Query Language:** LogQL

**Query Examples:**

```logql
# All logs from Traefik
{container_name="traefik"}

# Error logs
{container_name="traefik"} |= "error"

# HTTP 500 errors
{container_name="traefik"} |~ "HTTP/[0-9.]+ 5[0-9]{2}"

# Logs from all monitoring services
{compose_project="monitoring"}

# Rate of log lines
rate({container_name="traefik"}[5m])
```

### Alerts

**Engine:** vmalert
**Evaluation:** Every 30s
**Notification:** ntfy.sh (push notifications)
**Rules:** 14 total (6 CRITICAL, 8 WARNING)

**Alert Channels:**
- ntfy.sh topic: `codespartan-mambo-alerts`
- Can subscribe via: https://ntfy.sh/codespartan-mambo-alerts
- Supports mobile apps (iOS, Android)

**Alert Categories:**

```
Service Health:
  - ServiceDown (CRITICAL)
  - HighRestartRate (WARNING)

Resources:
  - HighCPU (WARNING)
  - HighMemory (CRITICAL)
  - HighDiskUsage (CRITICAL)
  - LowDiskSpace (WARNING)

Network:
  - HighErrorRate (CRITICAL)
  - SlowResponseTime (WARNING)

SSL:
  - CertificateExpiringSoon (WARNING)
```

---

## Networking

### Networks Overview

```
┌────────────────────────────────────────────────────────────────┐
│  EXTERNAL NETWORK (Internet)                                    │
│  - All public traffic                                           │
└────────────────────────────────────────────────────────────────┘
                            ↓↓↓
┌────────────────────────────────────────────────────────────────┐
│  HOST NETWORK INTERFACES                                        │
│  ┌──────────────────┐  ┌──────────────────┐                   │
│  │  eth0 (public)   │  │  docker0 (bridge)│                   │
│  │  91.98.137.217   │  │  172.17.0.1      │                   │
│  └──────────────────┘  └──────────────────┘                   │
└────────────────────────────────────────────────────────────────┘
                            ↓↓↓
┌────────────────────────────────────────────────────────────────┐
│  DOCKER NETWORKS                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  web (bridge, external)                                  │ │
│  │  172.18.0.0/16                                           │ │
│  │  ┌────────────┐ ┌──────────┐ ┌───────────┐             │ │
│  │  │  traefik   │ │ grafana  │ │ backoffice│             │ │
│  │  │ .0.2       │ │ .0.3     │ │ .0.4      │             │ │
│  │  └────────────┘ └──────────┘ └───────────┘             │ │
│  └──────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  monitoring (bridge, internal)                           │ │
│  │  172.19.0.0/16                                           │ │
│  │  ┌──────────┐ ┌──────┐ ┌────────┐ ┌────────────┐       │ │
│  │  │victoria  │ │ loki │ │vmalert │ │ cadvisor   │       │ │
│  │  │metrics   │ │      │ │        │ │            │       │ │
│  │  └──────────┘ └──────┘ └────────┘ └────────────┘       │ │
│  │  ┌──────────┐ ┌──────────┐                             │ │
│  │  │promtail  │ │  node-   │                             │ │
│  │  │          │ │ exporter │                             │ │
│  │  └──────────┘ └──────────┘                             │ │
│  │                                                          │ │
│  │  ┌──────────┐ (bridges both networks)                  │ │
│  │  │ vmagent  │                                           │ │
│  │  │          │                                           │ │
│  │  └──────────┘                                           │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### Port Mapping

**Host → Containers:**

| Host Port | Container | Container Port | Purpose |
|-----------|-----------|----------------|---------|
| 80 | traefik | 80 | HTTP (redirects to HTTPS) |
| 443 | traefik | 443 | HTTPS (all app traffic) |

**Internal Only (no host ports):**

| Container | Port | Service |
|-----------|------|---------|
| victoriametrics | 8428 | Metrics API |
| vmagent | 8429 | Internal metrics |
| vmalert | 8880 | Alerting API |
| loki | 3100 | Log ingestion/query |
| promtail | 9080 | Internal metrics |
| grafana | 3000 | Web UI (via Traefik) |
| cadvisor | 8080 | Metrics endpoint |
| node-exporter | 9100 | Metrics endpoint |
| traefik | 8080 | Metrics endpoint |

---

## Data Flow

### HTTP Request Flow

```
1. User → https://grafana.mambo-cloud.com
   ↓
2. DNS Resolution
   grafana.mambo-cloud.com → 91.98.137.217 (A record, TTL 120s)
   ↓
3. TCP Handshake
   User:random → Server:443
   ↓
4. TLS Handshake
   Server presents cert for grafana.mambo-cloud.com
   User validates against Let's Encrypt CA
   ↓
5. HTTPS Request
   GET / HTTP/2.0
   Host: grafana.mambo-cloud.com
   ↓
6. Firewall (Hetzner)
   Port 443 allowed → ACCEPT
   ↓
7. Traefik (port 443)
   a. Router matching: Host(`grafana.mambo-cloud.com`)
   b. Middleware chain:
      - rate-limit-global: Check req/s < 100
      - security-headers: Add HSTS, XSS, etc.
      - compression: Accept gzip
   c. Service lookup: grafana@docker
   d. Load balancer: Round-robin (1 backend)
   ↓
8. Docker Network (web)
   Traefik → grafana:3000
   ↓
9. Grafana Container
   Nginx handles request
   Serves dashboard HTML
   ↓
10. Response Path (reverse)
   Grafana → Traefik (compression applied)
   → TLS encrypted → User
```

### Metrics Collection Flow

```
1. Application generates metrics
   Example: Traefik increments traefik_service_requests_total
   ↓
2. Metrics exposed on HTTP endpoint
   Traefik :8080/metrics (Prometheus format)
   ↓
3. vmagent scrapes endpoint
   Every 15 seconds
   GET http://traefik:8080/metrics
   ↓
4. vmagent processes metrics
   a. Relabeling (add instance labels)
   b. Filtering (drop unwanted metrics)
   c. Aggregation (if configured)
   ↓
5. vmagent pushes to VictoriaMetrics
   POST http://victoriametrics:8428/api/v1/write
   Remote write protocol
   ↓
6. VictoriaMetrics stores metrics
   Write to /storage volume
   7-day retention window
   Compression applied
   ↓
7. Query path
   a. Grafana → VictoriaMetrics
      GET http://victoriametrics:8428/api/v1/query
      PromQL: rate(traefik_service_requests_total[5m])
   b. VictoriaMetrics executes query
      Reads from storage
      Aggregates data points
   c. Returns JSON response
      Time series data
   d. Grafana renders graph
   ↓
8. Alert evaluation (parallel)
   vmalert queries VictoriaMetrics every 30s
   Evaluates rules: up == 0 for 2m
   If triggered → POST to ntfy.sh
```

### Log Collection Flow

```
1. Container logs to stdout/stderr
   Example: docker logs traefik
   ↓
2. Docker captures output
   Stores in /var/lib/docker/containers/[id]/[id]-json.log
   JSON format: {"log":"...", "stream":"stdout", "time":"..."}
   ↓
3. Promtail monitors log files
   Watches /var/lib/docker/containers/*/*.log
   Detects changes (inotify)
   ↓
4. Promtail processes logs
   a. Parses JSON
   b. Adds labels:
      - container_name (from Docker API)
      - compose_project
      - compose_service
   c. Optionally extracts fields
   ↓
5. Promtail pushes to Loki
   POST http://loki:3100/loki/api/v1/push
   Batches log lines
   ↓
6. Loki ingests logs
   Indexes labels only (not content)
   Stores chunks in /loki volume
   7-day retention
   ↓
7. Query path
   a. Grafana → Loki
      GET http://loki:3100/loki/api/v1/query_range
      LogQL: {container_name="traefik"} |= "error"
   b. Loki executes query
      Filters by labels (fast index lookup)
      Greps log content (if |= or |~ used)
   c. Returns log lines with timestamps
   d. Grafana displays in Explore tab
```

---

## Backup & Recovery

### Backup Strategy

**Schedule:** Daily at 3:00 AM UTC (cron)
**Script:** `/opt/codespartan/scripts/backup.sh`
**Storage:** `/opt/codespartan/backups/`
**Format:** `backup-YYYY-MM-DD_HH-MM-SS.tar.gz`
**Retention:** 7 days local, 30 days remote (configurable)

### What's Backed Up

```
1. Docker Volumes:
   - monitoring_victoria-data (35 MB)
   - monitoring_loki-data (5 MB)
   - monitoring_grafana-data (12 MB)
   Total: ~52 MB → Compressed to ~6.6 MB

2. Configuration Files:
   - /opt/codespartan/platform/ (all docker-compose.yml, configs)
   - Size: ~500 KB

3. SSL Certificates:
   - /opt/codespartan/platform/traefik/letsencrypt/
   - acme.json (42 KB)

4. Scripts:
   - /opt/codespartan/scripts/
   - Size: ~100 KB

Total Backup Size: ~7-8 MB compressed
```

### Backup Verification

**Automated checks:**
- Volume mount exists
- Tar creation successful
- Compressed size > 1 MB
- Notification sent to ntfy.sh

### Restore Procedures

**Script:** `/opt/codespartan/scripts/restore.sh`

**Restore Modes:**

```bash
# Full restore (volumes + configs + SSL)
./restore.sh backup-2025-10-08_03-00-00.tar.gz

# Volumes only
./restore.sh backup-2025-10-08_03-00-00.tar.gz --volumes-only

# Configs only
./restore.sh backup-2025-10-08_03-00-00.tar.gz --configs-only
```

**Disaster Recovery Scenarios:**

1. **Single volume corruption**
   - RTO: 15 minutes
   - RPO: < 24 hours
   - Process: Stop service, restore volume, restart

2. **Complete data loss**
   - RTO: 30 minutes
   - RPO: < 24 hours
   - Process: Restore all volumes + configs

3. **VPS destroyed**
   - RTO: 2-4 hours
   - RPO: < 24 hours
   - Process: terraform apply → restore backup

4. **SSL certificates lost**
   - RTO: 5 minutes (restore) or 5 minutes (regenerate)
   - RPO: 0 (Let's Encrypt)

5. **Accidental service deletion**
   - RTO: 10 minutes
   - RPO: 0 (git restore)

6. **Configuration corruption**
   - RTO: 15 minutes
   - RPO: < 24 hours

7. **GitHub repository deleted**
   - RTO: 1 hour
   - RPO: Last local clone

**For full DR guide:** See [Disaster Recovery Plan](../03-operations/DISASTER_RECOVERY.md)

---

## Deployment Pipeline

### Infrastructure Deployment

**Trigger:** Push to `codespartan/infra/hetzner/**`
**Workflow:** `.github/workflows/deploy-infrastructure.yml`

**Steps:**
1. Checkout code
2. Setup Terraform
3. `terraform init` (download providers)
4. `terraform plan` (preview changes)
5. `terraform apply` (apply changes)
6. Output VPS IP and domain

**Secrets Required:**
- `HCLOUD_TOKEN` - Hetzner Cloud API
- `HETZNER_DNS_TOKEN` - Hetzner DNS API

**Duration:** ~3-5 minutes (first run), ~30 seconds (updates)

### Platform Deployment

**Components:** Traefik, Monitoring, Backoffice

**Traefik:**
- Trigger: Push to `codespartan/platform/traefik/**`
- Workflow: `deploy-traefik.yml`
- Steps:
  1. Copy files to VPS
  2. `docker compose pull`
  3. `docker compose up -d`
- Duration: ~1 minute

**Monitoring:**
- Trigger: Push to `codespartan/platform/stacks/monitoring/**`
- Workflow: `deploy-monitoring.yml`
- Steps:
  1. Copy files to VPS
  2. `docker compose pull`
  3. `docker compose up -d`
- Duration: ~2 minutes (8 containers)

**Backoffice:**
- Trigger: Push to `codespartan/platform/stacks/backoffice/**`
- Workflow: `deploy-backoffice.yml`
- Duration: ~30 seconds

### Application Deployment

**Template:** `.github/workflows/_template-deploy.yml`

**Generic Steps:**
1. Checkout code
2. Prepare artifacts
3. Create remote directory
4. SCP files to VPS
5. SSH: `docker compose pull && docker compose up -d`
6. Verify deployment

**Example (mambo-cloud):**
- Trigger: Push to `codespartan/apps/mambo-cloud/**`
- Workflow: `deploy-mambo-cloud.yml`
- Duration: ~1 minute

### Manual Deployment

```bash
# SSH to VPS
ssh leonidas@91.98.137.217

# Navigate to service
cd /opt/codespartan/platform/traefik

# Update
docker compose pull
docker compose up -d

# Verify
docker ps
docker logs traefik --tail 50
```

---

## Quick Reference

### Important URLs

| Service | URL | Auth |
|---------|-----|------|
| Traefik Dashboard | https://traefik.mambo-cloud.com | admin:codespartan123 |
| Grafana | https://grafana.mambo-cloud.com | admin:codespartan123 |
| Backoffice | https://backoffice.mambo-cloud.com | admin:codespartan123 |
| Mambo Cloud | https://www.mambo-cloud.com | Public |
| Staging | https://staging.mambo-cloud.com | Public |
| Lab | https://lab.mambo-cloud.com | Public |

### Key File Locations (VPS)

```
/opt/codespartan/
├── platform/
│   ├── traefik/
│   │   ├── docker-compose.yml
│   │   ├── dynamic-config.yml
│   │   ├── letsencrypt/acme.json
│   │   └── users.htpasswd
│   └── stacks/
│       ├── monitoring/docker-compose.yml
│       └── backoffice/docker-compose.yml
├── apps/
│   ├── mambo-cloud/
│   ├── cyberdyne/
│   └── dental-io/
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   ├── health-check.sh
│   ├── cleanup.sh
│   └── update-containers.sh
└── backups/
    └── backup-YYYY-MM-DD_HH-MM-SS.tar.gz
```

### Common Commands

```bash
# View all containers
docker ps

# Check logs
docker logs traefik -f
docker logs grafana --tail 100

# Restart service
docker restart traefik

# Update service
cd /opt/codespartan/platform/traefik
docker compose pull
docker compose up -d

# Run health check
/opt/codespartan/scripts/health-check.sh

# Create backup
/opt/codespartan/scripts/backup.sh

# Check SSL
/opt/codespartan/scripts/check-ssl-renewal.sh

# System cleanup
/opt/codespartan/scripts/cleanup.sh --dry-run

# Check Fail2ban
sudo fail2ban-client status sshd

# View Traefik config
docker exec traefik cat /etc/traefik/dynamic-config.yml
```

### Resource Monitoring

```bash
# System overview
top
htop

# Docker stats
docker stats

# Disk usage
df -h
du -sh /opt/codespartan/*

# Network connections
ss -tulpn
netstat -tulpn

# Check firewall
iptables -L -n
```

---

## Next Steps

After understanding this overview:

1. **Read operational guides:**
   - [Runbook Operativo](../03-operations/RUNBOOK.md) - Day-to-day operations
   - `../04-deployment/ADDING_APPS.md` - Deploy your first app
   - `../03-operations/DISASTER_RECOVERY.md` - Recovery procedures

2. **Explore monitoring:**
   - Open Grafana
   - Review dashboards
   - Create custom queries
   - Test alerting

3. **Deploy an application:**
   - Copy `_TEMPLATE`
   - Customize for your app
   - Deploy via GitHub Actions
   - Monitor in Grafana

4. **Test disaster recovery:**
   - Create test backup
   - Restore to verify
   - Document RTO/RPO

5. **Customize & extend:**
   - Add more subdomains
   - Create custom dashboards
   - Add more alert rules
   - Implement multi-environment

---

## Support & Resources

**Documentation:**
- `docs/` - All platform documentation
- `../../CLAUDE.md` - AI assistant context
- `../README.md` - Quick start guide

**External Links:**
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
- [Grafana Docs](https://grafana.com/docs/)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Terraform Hetzner Provider](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)

**Monitoring:**
- Grafana dashboards: https://grafana.mambo-cloud.com
- ntfy.sh alerts: https://ntfy.sh/codespartan-mambo-alerts

**Source Code:**
- GitHub: https://github.com/your-org/iac-code-spartan

---

**End of Overview**
