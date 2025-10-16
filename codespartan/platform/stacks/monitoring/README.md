# Monitoring Stack - CodeSpartan Mambo Cloud

Complete observability stack with metrics, logs, dashboards, and alerting.

## Stack Components

### Metrics (VictoriaMetrics)

- **VictoriaMetrics**: Time-series database (Prometheus-compatible)
- **vmagent**: Metrics collector and forwarder
- **vmalert**: Alert evaluation engine
- **Node Exporter**: Host-level metrics (CPU, RAM, Disk, Network)
- **cAdvisor**: Container-level metrics

### Logs (Loki)

- **Loki**: Log aggregation and storage
- **Promtail**: Log collector (scrapes Docker logs)

### Visualization (Grafana)

- **Grafana**: Dashboards and visualization
  - Access: https://grafana.mambo-cloud.com
  - Credentials: admin / codespartan123

### Alerting (Alertmanager + ntfy.sh)

- **vmalert**: Evaluates alert rules from metrics
- **Alertmanager**: Routes, groups, and deduplicates alerts
- **ntfy-forwarder**: Custom webhook bridge (Alertmanager → ntfy.sh)
- **ntfy.sh**: Push notifications to mobile/web

## Directory Structure

```
monitoring/
├── docker-compose.yml           # Main stack definition
├── README.md                     # This file
├── alerts/
│   └── rules.yml                 # Alert rules for vmalert
├── alertmanager/
│   └── alertmanager.yml          # Alert routing configuration
├── ntfy-forwarder/
│   ├── Dockerfile                # Custom forwarder container
│   └── forwarder.py              # Python webhook converter
├── victoriametrics/
│   └── prometheus.yml            # Scrape configurations
├── loki/
│   └── loki.yml                  # Loki configuration
├── promtail/
│   └── promtail.yml              # Promtail configuration
└── grafana/
    ├── provisioning/
    │   ├── datasources/          # Auto-provisioned datasources
    │   └── dashboards/           # Auto-provisioned dashboards
    └── dashboards/               # Dashboard JSON files
```

## Quick Start

### Deploy Stack

```bash
cd /opt/codespartan/platform/stacks/monitoring
docker compose up -d
```

### Verify Services

```bash
# Check all containers are running
docker ps | grep -E "victoriametrics|vmagent|vmalert|loki|promtail|grafana|cadvisor|node-exporter|alertmanager|ntfy-forwarder"

# Check health status
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "victoriametrics|grafana|loki|vmalert|alertmanager"
```

### Access Dashboards

- **Grafana**: https://grafana.mambo-cloud.com
- **VictoriaMetrics**: http://localhost:8428
- **Alertmanager**: http://localhost:9093
- **vmalert**: http://localhost:8880

## Configuration

### Adding Metrics Scrape Targets

Edit `victoriametrics/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:8080']
```

Restart vmagent:
```bash
docker compose restart vmagent
```

### Adding Alert Rules

Edit `alerts/rules.yml`:

```yaml
groups:
  - name: my_alerts
    interval: 30s
    rules:
      - alert: MyAlert
        expr: metric_name > threshold
        for: 5m
        labels:
          severity: warning
          component: myapp
        annotations:
          summary: "Short description"
          description: "Detailed description: {{ $value }}"
```

Reload vmalert:
```bash
docker compose restart vmalert
```

### Modifying Alert Routing

Edit `alertmanager/alertmanager.yml`:

```yaml
route:
  routes:
    - match:
        severity: critical
      receiver: 'my-receiver'
```

Reload alertmanager:
```bash
docker compose restart alertmanager
```

## Data Retention

| Component | Retention | Storage |
|-----------|-----------|---------|
| VictoriaMetrics | 7 days | `/storage` volume |
| Loki | 7 days (configurable) | `/loki` volume |
| Grafana | Permanent | `/var/lib/grafana` volume |
| Alertmanager | 5 days | `/alertmanager` volume |

## Resource Usage

| Service | RAM Limit | CPU Limit | Typical Usage |
|---------|-----------|-----------|---------------|
| VictoriaMetrics | 1 GB | 1.0 | ~120 MB |
| Grafana | 512 MB | 0.5 | ~80 MB |
| Loki | 512 MB | 0.5 | ~95 MB |
| vmagent | 256 MB | 0.25 | ~130 MB |
| Promtail | 256 MB | 0.25 | ~60 MB |
| cAdvisor | 256 MB | 0.25 | ~195 MB |
| vmalert | 128 MB | 0.15 | ~12 MB |
| Alertmanager | 128 MB | 0.15 | ~8 MB |
| ntfy-forwarder | 64 MB | 0.1 | ~6 MB |
| Node Exporter | 128 MB | 0.1 | ~13 MB |

**Total**: ~3.9 GB limits / ~719 MB actual usage

## Common Operations

### View Metrics

```bash
# Query VictoriaMetrics directly
curl 'http://localhost:8428/api/v1/query?query=up'

# Query via Grafana datasource
# Go to Grafana → Explore → VictoriaMetrics
```

### View Logs

```bash
# Query Loki directly
curl 'http://localhost:3100/loki/api/v1/query?query={job="varlogs"}'

# Query via Grafana
# Go to Grafana → Explore → Loki
```

### View Active Alerts

```bash
# vmalert
curl http://localhost:8880/api/v1/rules

# Alertmanager
curl http://localhost:9093/api/v2/alerts
```

### Silence Alert

```bash
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "HighCPUUsage", "isRegex": false}],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
    "createdBy": "admin",
    "comment": "Maintenance window"
  }'
```

## Troubleshooting

### VictoriaMetrics not receiving metrics

```bash
# Check vmagent is running
docker logs vmagent --tail 50

# Verify scrape targets
curl http://localhost:8429/targets

# Check VictoriaMetrics ingestion
curl http://localhost:8428/api/v1/query?query=up
```

### Grafana dashboards not loading

```bash
# Check Grafana logs
docker logs grafana --tail 100

# Verify datasource connection
curl http://localhost:3000/api/datasources

# Test VictoriaMetrics connectivity from Grafana container
docker exec grafana wget -O- http://victoriametrics:8428/api/v1/query?query=up
```

### Alerts not firing

```bash
# Check vmalert is evaluating rules
docker logs vmalert --tail 50

# Verify rules are loaded
curl http://localhost:8880/api/v1/rules

# Check alertmanager is receiving alerts
curl http://localhost:9093/api/v2/alerts
```

### Alerts not reaching ntfy.sh

```bash
# Check alertmanager routing
docker logs alertmanager --tail 50

# Check ntfy-forwarder logs
docker logs ntfy-forwarder --tail 50

# Test ntfy.sh directly
curl -d "Test notification" https://ntfy.sh/codespartan-mambo-alerts
```

### Loki not receiving logs

```bash
# Check promtail is running
docker logs promtail --tail 50

# Verify promtail can access Docker logs
docker exec promtail ls -la /var/lib/docker/containers

# Test Loki ingestion
curl http://localhost:3100/ready
```

## Backup & Recovery

### Backup Critical Data

```bash
# Backup Grafana dashboards
docker exec grafana tar -czf - /var/lib/grafana/dashboards > grafana-dashboards-$(date +%Y%m%d).tar.gz

# Backup VictoriaMetrics data
docker exec victoriametrics tar -czf - /storage > victoria-data-$(date +%Y%m%d).tar.gz

# Backup configurations
tar -czf monitoring-config-$(date +%Y%m%d).tar.gz \
  alerts/ \
  alertmanager/ \
  victoriametrics/ \
  loki/ \
  promtail/ \
  grafana/provisioning/
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore configurations
tar -xzf monitoring-config-YYYYMMDD.tar.gz

# Restore data volumes (if needed)
docker volume create victoria-data
docker volume create grafana-data

# Start services
docker compose up -d
```

## Monitoring the Monitoring

The monitoring stack monitors itself:

- VictoriaMetrics scrapes its own `/metrics`
- vmalert monitors VictoriaMetrics health
- Alertmanager monitors vmalert connectivity
- All components send logs to Loki

## Performance Tuning

### High Cardinality Issues

If metrics grow too large:

```yaml
# In victoriametrics/prometheus.yml
scrape_configs:
  - job_name: 'high-cardinality-service'
    metric_relabel_configs:
      # Drop high-cardinality labels
      - source_labels: [__name__]
        regex: 'unwanted_metric_.*'
        action: drop
```

### Long Retention

To extend retention beyond 7 days:

```yaml
# In docker-compose.yml
victoriametrics:
  command:
    - -retentionPeriod=30d  # Change from 7d to 30d
```

**Note**: Longer retention requires more disk space.

## Security

### Grafana Security

- Change default password immediately
- Enable HTTPS (handled by Traefik)
- Configure SMTP for password reset
- Enable audit logging

### API Access

All internal APIs (VictoriaMetrics, Alertmanager, vmalert) are:
- **NOT exposed to internet** (only Grafana via Traefik)
- Accessible only from `monitoring` Docker network
- No authentication required (internal only)

For production hardening:
- Add basic auth to internal services
- Use service mesh for mTLS
- Implement network policies

## Further Reading

- [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
- [Grafana Docs](https://grafana.com/docs/grafana/latest/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)
- [Alertmanager Docs](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Complete Alerts Guide](../../docs/ALERTS.md)
- [Resource Management](../../docs/RESOURCES.md)

---

**Last Updated**: 2025-10-16
**Maintainer**: DevOps Team
**Support**: See `../../docs/RUNBOOK.md`
