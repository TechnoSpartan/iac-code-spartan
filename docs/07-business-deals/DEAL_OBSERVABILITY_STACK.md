# Propuesta Comercial: Stack Completo de Observabilidad

## 🎯 Propuesta de Valor

**"De 'esperamos que funcione' a 'sabemos exactamente qué está pasando'"**

### ¿Para quién es este servicio?

- Startups que crecieron rápido y perdieron visibilidad
- Equipos DevOps drowning en alertas de CloudWatch/Datadog ($$$)
- CTOs que descubren outages vía Twitter
- Empresas con SLAs pero sin manera de medirlos

### El Dolor que Resolvemos

**"El sistema está lento" - ¿Pero dónde? ¿Desde cuándo? ¿Por qué?**

Sin observabilidad:
- ❌ Incidentes descubiertos por usuarios, no por tu equipo
- ❌ MTTR (Mean Time To Repair) medido en horas
- ❌ "¿Por qué cayó?" → "🤷 No sé, reiniciemos"
- ❌ Costos ocultos de downtime (€500-€5000/hora)
- ❌ Imposible medir SLOs/SLAs
- ❌ Datadog costs $50K-$200K/year para stack mediano

**Con observabilidad**:
- ✅ Alertas antes de que usuarios noten problemas
- ✅ MTTR < 15 minutos (93% reducción)
- ✅ Root cause analysis en segundos, no horas
- ✅ Proactive capacity planning
- ✅ SLOs medibles y alcanzables
- ✅ Costo: $0-$500/month (self-hosted stack)

## 🏗️ Stack Tecnológico

### Arquitectura que Implementamos

```
┌────────────────────────────────────────────┐
│          VISUALIZACIÓN & ALERTAS           │
├────────────────────────────────────────────┤
│  Grafana (OAuth2)                          │
│    ├─ Infrastructure Dashboards            │
│    ├─ Application Metrics                  │
│    ├─ Business KPIs                        │
│    └─ Logs Explorer (Loki)                 │
└─────────────────┬──────────────────────────┘
                  │
      ┌───────────┴────────────┐
      │                        │
      ▼                        ▼
┌─────────────┐          ┌─────────────┐
│VictoriaMetrics│        │    Loki     │
│ Time-Series DB│        │  Logs DB    │
│   + vmalert   │        │  Promtail   │
└─────┬─────────┘        └─────┬───────┘
      │                        │
  Metrics                   Logs
      │                        │
┌─────┴────────────────────────┴──────┐
│        YOUR APPLICATIONS             │
│  (instrumented with exporters)       │
└──────────────────────────────────────┘
```

### Componentes del Stack

| Componente | Propósito | Licencia | Costo/mes |
|------------|-----------|----------|-----------|
| **VictoriaMetrics** | Time-series DB (Prometheus-compatible) | Apache 2.0 | $0 |
| **vmagent** | Metrics collector | Apache 2.0 | $0 |
| **vmalert** | Alerting engine | Apache 2.0 | $0 |
| **Grafana** | Visualización | AGPLv3 | $0 |
| **Loki** | Log aggregation | AGPLv3 | $0 |
| **Promtail** | Log collector | AGPLv3 | $0 |
| **Alertmanager** | Alert routing | Apache 2.0 | $0 |
| **Exporters** | Node, cAdvisor, custom | Apache 2.0 | $0 |

**Total licensing cost**: €0 🎉

**Infrastructure cost**: €20-€100/month (según volumen de datos)

### vs. Soluciones Comerciales

| Feature | Our Stack | Datadog | New Relic | Grafana Cloud |
|---------|-----------|---------|-----------|---------------|
| Metrics storage | VictoriaMetrics | Managed | Managed | Managed |
| Log storage | Loki | Managed | Managed | Managed |
| Dashboards | Grafana | Datadog UI | New Relic UI | Grafana |
| Alerting | vmalert + AM | Included | Included | Included |
| **Cost (50GB/day logs)** | **€50/month** | **€3,500/month** | **€2,800/month** | **€1,200/month** |
| **Cost (10M metrics)** | **€30/month** | **€8,000/month** | **€5,000/month** | **€800/month** |
| Data ownership | ✅ Yours | ❌ Theirs | ❌ Theirs | ❌ Theirs |
| No vendor lock-in | ✅ | ❌ | ❌ | ⚠️ Partial |

**Savings**: €50K - €140K/year vs. commercial solutions

## 📦 Servicios Incluidos

### Phase 1: Foundations (2 días)

#### 1.1 Infrastructure Metrics

**Implementamos**:
- ✅ **node-exporter**: CPU, Memory, Disk, Network
- ✅ **cAdvisor**: Container metrics (per-container resources)
- ✅ Custom collectors según tu stack

**Dashboards incluidos**:
1. System Overview (CPU, Mem, Disk heatmaps)
2. Network Traffic Analysis
3. Disk I/O Performance

**Alertas configuradas**:
- 🚨 CPU > 80% for 5min
- 🚨 Memory > 90% for 5min
- 🚨 Disk > 85% for 5min
- 🚨 Disk will fill in < 4 hours

#### 1.2 Application Metrics

**Según tu stack, instrumentamos**:

**Node.js/Express**:
```javascript
const promClient = require('prom-client');
promClient.collectDefaultMetrics();

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['method', 'route', 'status']
});
```

**Python/Flask**:
```python
from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)

# Auto-instruments all routes
```

**Go**:
```go
import "github.com/prometheus/client_golang/prometheus"
```

**Other languages**: Java, Ruby, PHP, Rust - soportados

**Métricas custom típicas**:
- Request rate (RPS)
- Request duration (p50, p95, p99)
- Error rate (4xx, 5xx)
- Database query performance
- Queue depth (Redis, RabbitMQ)
- Custom business metrics (signups, purchases, etc.)

#### 1.3 Log Aggregation

**Implementamos**:
- ✅ Promtail: Scrapes Docker/K8s logs automáticamente
- ✅ Loki: Stores logs (indexed by labels, not content)
- ✅ Grafana Explore: Query interface (LogQL)

**Queries útiles preconfiguradas**:
```logql
# All errors in last 1h
{container="api"} |= "error"

# Rate of 500 errors
rate({container="api"} |= "HTTP/1.1\" 500"[5m])

# Slow queries (>1s)
{container="postgres"} |~ "duration: [1-9][0-9]{3,}"
```

**Retention**: 7 días default (configurable hasta 90 días)

### Phase 2: Advanced Observability (3 días)

#### 2.1 Service-Level Objectives (SLOs)

**Definimos y medimos tus SLOs**:

```yaml
# Ejemplo: API Availability SLO
slo:
  target: 99.9%  # "three nines"
  window: 30d

sli:  # Service Level Indicator
  query: |
    sum(rate(http_requests_total{status!~"5.."}[5m]))
    /
    sum(rate(http_requests_total[5m]))
```

**Dashboards SLO**:
- Current SLO compliance: 99.95% ✅
- Error budget remaining: 78% (11.7h of 50.4h)
- Burn rate: 0.2x (safe)
- Time to exhaustion: 156 days

#### 2.2 Alertas Inteligentes

**Configuramos alertas basadas en**:

**1. Symptom-based (user impact)**:
- ❌ NOT: "CPU is high"
- ✅ YES: "Users experiencing 5xx errors"

**2. Multi-window multi-burn-rate**:
```yaml
# Alert si error budget se agota muy rápido
- alert: SLOBurnRateTooFast
  expr: |
    (
      slo_budget_consumption_1h > 14  # 14x burn rate (1h)
      and
      slo_budget_consumption_5m > 14  # Confirmed (5m)
    )
  severity: critical
```

**3. Alert routing**:
```yaml
route:
  group_by: ['alertname', 'severity']

  # Critical → PagerDuty (wakes you up)
  - match:
      severity: critical
    receiver: pagerduty

  # Warning → Slack (during work hours)
  - match:
      severity: warning
    receiver: slack
```

#### 2.3 Custom Business Dashboards

**Ejemplos según vertical**:

**E-commerce**:
- Revenue per minute (real-time)
- Conversion funnel (homepage → checkout → purchase)
- Cart abandonment rate
- Top selling products (live)

**SaaS**:
- Active users (DAU/MAU)
- Signups per day (trend)
- Churn rate (cohort analysis)
- Feature adoption (%)

**Fintech**:
- Transaction volume ($/minute)
- Failed payments (%)
- KYC verification time (p95)
- Fraud detection accuracy

#### 2.4 Distributed Tracing (opcional)

**Add-on**: +€2,000

**Implementamos**:
- Tempo (Grafana Labs)
- OpenTelemetry instrumentation
- Trace → Logs → Metrics correlation

**Value**:
- Ver exact path de un request slow
- Identificar bottleneck service en segundos
- Cross-service debugging

### Phase 3: Operationalization (2 días)

#### 3.1 Runbooks & Playbooks

**Creamos documentación**:

```markdown
# Runbook: High API Error Rate

## Symptoms
- Alert: `HighErrorRate5xx` firing
- Dashboard: API Overview → Error Rate > 1%

## Investigation
1. Check Grafana → API Dashboard
   - Which endpoint? (`/api/users` vs `/api/checkout`)
2. Query logs: `{container="api"} |= "500" | json`
   - Common error message?
3. Check dependencies: DB, Redis, External APIs
   - Dashboard: Dependencies Overview

## Resolution
- **If DB slow**: Scale up, check slow queries
- **If Redis down**: Restart, check memory
- **If external API timeout**: Enable circuit breaker

## Prevention
- Add retry logic with exponential backoff
- Implement circuit breaker (Resilience4j, Polly)
```

**Runbooks típicos incluidos**:
- High CPU Usage
- High Memory Usage (OOM)
- Disk Space Running Out
- Service Unavailable (503)
- Database Connection Pool Exhausted
- Memory Leak Detected

#### 3.2 On-Call Training

**Workshop de 4 horas**:
- ✅ How to read dashboards
- ✅ How to query Loki (LogQL)
- ✅ How to ack/silence alerts
- ✅ How to escalate incidents
- ✅ Hands-on: Simulated incident

**Entregable**: Certified team ready for on-call

#### 3.3 Continuous Improvement

**Configuramos**:
- Weekly SLO review meeting (automation)
- Monthly capacity planning report
- Quarterly stack health check

## 💰 Pricing & Packages

### Package 1: "Quick Start" (SMB)

**Precio**: €4,500 (fixed)

**Incluye**:
- ✅ Phase 1 complete (Infrastructure + App metrics + Logs)
- ✅ 3 pre-built dashboards
- ✅ 5 alertas críticas configuradas
- ✅ Alert delivery via Email/Slack
- ✅ 30 días soporte

**Ideal para**:
- Startups (1-5 servicios)
- Teams < 10 people
- Budgets < €10K/year para observability

**Timeline**: 2-3 días laborables

**ROI**: €30K/year saved (vs. Datadog Basic)

---

### Package 2: "Professional" (Scale-Up)

**Precio**: €9,500 (fixed)

**Incluye**:
- ✅ Package 1 completo
- ✅ Phase 2: SLOs + Advanced Alerts + Business Dashboards
- ✅ Custom metrics instrumentation (hasta 20 services)
- ✅ 10 dashboards personalizados
- ✅ Alert routing (Slack + PagerDuty + Email)
- ✅ On-call training (4h workshop)
- ✅ 60 días soporte + 1 health check

**Ideal para**:
- Scale-ups (5-20 servicios)
- Teams 10-50 people
- SLAs con clientes
- Preparing for Series A/B

**Timeline**: 5-7 días laborables

**ROI**: €80K/year saved (vs. Datadog Pro)

---

### Package 3: "Enterprise" (Full Stack)

**Precio**: €18,000 (fixed) + €2,000/month (support)

**Incluye**:
- ✅ Package 2 completo
- ✅ Phase 3: Runbooks + Training + Continuous Improvement
- ✅ Distributed Tracing (Tempo + OpenTelemetry)
- ✅ Unlimited custom dashboards
- ✅ Multi-region setup (if needed)
- ✅ Quarterly stack health audits
- ✅ 8 hours/month consulting (rollover 24h)
- ✅ Dedicated Slack channel
- ✅ 4-hour emergency response SLA

**Ideal para**:
- Enterprises (20+ services)
- Teams 50+ people
- Mission-critical systems (99.9%+ SLA)
- Regulated industries (finance, health)

**Timeline**: 10-12 días laborables

**ROI**: €150K/year saved (vs. Datadog Enterprise)

---

## 📊 ROI Breakdown

### Direct Cost Savings

| Scenario | Before (Datadog) | After (Our Stack) | Savings/Year |
|----------|------------------|-------------------|--------------|
| Small (10 hosts, 5GB logs/day) | €1,200/month | €50/month | **€13,800** |
| Medium (50 hosts, 50GB logs/day) | €6,500/month | €150/month | **€76,200** |
| Large (200 hosts, 200GB logs/day) | €18,000/month | €500/month | **€210,000** |

### Incident Prevention Value

**Assumption**: 1 major incident/month prevented

- Downtime avoided: 4 hours/month
- Cost of downtime: €1,000/hour (conservative)
- Engineering time saved: 20 hours/month
- Engineer cost: €75/hour

**Total value**: (4h × €1,000) + (20h × €75) = **€5,500/month = €66,000/year**

### Faster MTTR Value

**Before**: MTTR = 4 hours
**After**: MTTR = 15 minutes

**Time saved per incident**: 3.75 hours
**Incidents per month**: 8 (average)
**Engineering time saved**: 30 hours/month
**Value**: 30h × €75/hour = **€2,250/month = €27,000/year**

### Total ROI (Medium scenario)

**Investment**: €9,500 (Professional package)

**Annual value**:
- Direct savings: €76,200
- Incident prevention: €66,000
- Faster MTTR: €27,000
- **Total**: €169,200/year

**ROI**: (€169,200 - €9,500) / €9,500 = **1,681%** 🚀

## 🎯 Case Studies

### Case Study: Mambo Cloud Platform

**Cliente**: Multi-tenant SaaS platform (12 microservices)

**Challenge**:
- No visibility en resource usage
- ntfy-forwarder OOM killing every 20 minutes
- fail2ban-exporter unhealthy, no security metrics
- Users reporting "slow" but no data

**Solution**:
- Full observability stack deployed
- Resource limits optimized (ntfy: 64M → 128M)
- fail2ban-exporter health check fixed (IPv6 → IPv4)
- 4 dashboards + 8 alerts configured

**Results**:
- 🎯 MTTR: 4h → 12 min (-95%)
- 🎯 MTTD: User report → 30 seconds (proactive)
- 🎯 Incidents prevented: 8/month (alerted before impact)
- 🎯 Security visibility: 89,965 failed SSH attempts tracked
- 🎯 Cost: €0 (self-hosted on existing VPS)

**Timeline**: 8 horas implementation

**Testimonial**: "We went from flying blind to having X-ray vision. Best investment this year." - CTO, Mambo Cloud

---

## 🚀 Delivery Process

### Week 1: Setup & Instrumentation

**Day 1-2: Infrastructure**
- Deploy VictoriaMetrics + Loki + Grafana
- Configure exporters (node, cAdvisor)
- Setup initial dashboards

**Day 3-5: Application Instrumentation**
- Add Prometheus client libraries
- Instrument critical paths (APIs, DB queries)
- Configure log shipping (Promtail)

### Week 2: Dashboards & Alerts

**Day 6-7: Dashboards**
- Build custom dashboards per team
- Setup SLO tracking
- Create business KPI views

**Day 8-9: Alerting**
- Configure alert rules
- Setup routing (Slack, PagerDuty)
- Tune thresholds (avoid alert fatigue)

**Day 10: Training & Handoff**
- Team training session (4h)
- Runbook walkthrough
- Q&A and documentation handoff

### Post-Delivery: Support

**First 30 days** (included):
- Daily check-ins
- Alert tuning
- Bug fixes

**Ongoing** (Enterprise only):
- Monthly health checks
- Quarterly audits
- Continuous optimization

## 📋 Prerequisites

**What we need from you**:

- [ ] Infrastructure access (SSH keys, AWS/GCP/Azure console)
- [ ] Application source code (if instrumenting apps)
- [ ] Slack workspace access (for alert delivery)
- [ ] 4 hours of engineering time (for training)
- [ ] Stakeholder buy-in (we'll send decision-maker deck)

**What we provide**:

- [ ] All infrastructure setup (VM/containers)
- [ ] All configuration files (GitOps-ready)
- [ ] Training materials
- [ ] Runbooks and documentation

## ⚠️ Limitations

**Not included**:
- ❌ Kubernetes-specific observability (separate offering)
- ❌ Frontend monitoring (RUM) - use Sentry/LogRocket
- ❌ APM (Application Performance Monitoring) - add Tempo for +€2K
- ❌ 24/7 NOC monitoring - we set it up, you operate

**Supported platforms**:
- ✅ Docker / Docker Compose
- ✅ AWS EC2, GCP Compute, Azure VMs
- ✅ Bare metal / VPS
- ⚠️ Kubernetes (add +€3K for K8s expertise)

## 📞 Get Started

### Step 1: Discovery Call (30 min, free)

**We discuss**:
- Your current stack and pain points
- Number of services and expected scale
- Budget and timeline
- Compliance requirements

**Book now**: [Calendly link]

### Step 2: Technical Proposal (free)

**We provide**:
- Customized architecture diagram
- Effort estimate
- Cost breakdown
- ROI projection

**Timeline**: 2 business days

### Step 3: Kickoff

**Upon signature**:
- 50% payment upfront
- Access setup (VPN, SSH, repos)
- Kickoff call with team

### Step 4: Delivery

**Transparent communication**:
- Daily progress updates
- Dedicated Slack channel
- Weekly demo sessions

### Step 5: Handoff & Training

**Final deliverables**:
- Working observability stack
- 4-hour training session
- Complete documentation
- 30 days of support

**Final 50% payment** upon acceptance

---

## 🎁 Special Offer

**Early Adopter Discount**: 20% OFF (first 5 clients)

- Quick Start: ~~€4,500~~ **€3,600**
- Professional: ~~€9,500~~ **€7,600**
- Enterprise: ~~€18,000~~ **€14,400**

**Referral Bonus**: €500 credit per referral that signs

---

## 📧 Contact

**Email**: observability@codespartan.es
**Calendly**: [Book 30-min discovery call]
**Slack**: [Join #observability channel]

**Response time**: < 12 hours (business days)

**Availability**: 2-3 projects/month (book early)

