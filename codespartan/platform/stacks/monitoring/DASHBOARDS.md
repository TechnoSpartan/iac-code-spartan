# 📊 Grafana Dashboards - Guía de Importación

Dashboards recomendados para el stack de monitoreo CodeSpartan.

---

## 🚀 Cómo Importar Dashboards

### Método 1: Desde Grafana UI (Recomendado)

1. Ir a https://grafana.mambo-cloud.com
2. Login: admin / codespartan123
3. Menú lateral → **Dashboards** → **New** → **Import**
4. Introducir el **Dashboard ID** de la lista abajo
5. Click **Load**
6. Seleccionar datasources:
   - Para métricas: **VictoriaMetrics**
   - Para logs: **Loki**
7. Click **Import**

### Método 2: Desde CLI (Avanzado)

```bash
# Ejemplo para importar dashboard 1860
curl -s https://grafana.com/api/dashboards/1860/revisions/latest/download \
  | jq '.dashboard' > dashboard.json

curl -u admin:codespartan123 -X POST \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  https://grafana.mambo-cloud.com/api/dashboards/db
```

---

## 📈 Dashboards Recomendados

### 1. Node Exporter Full (ID: 1860)
**Propósito:** Métricas completas del servidor (CPU, RAM, Disk, Network)

**Dashboard ID:** `1860`
**Fuente:** https://grafana.com/grafana/dashboards/1860
**Datasource:** VictoriaMetrics

**Métricas incluidas:**
- CPU Usage, Load Average, Context Switches
- Memory Usage, Swap, Cache
- Disk I/O, Read/Write rates
- Network Traffic por interfaz
- Filesystem Usage
- System Uptime

**Compatibilidad:** ✅ Compatible con VictoriaMetrics

---

### 2. Traefik Dashboard (ID: 17346)
**Propósito:** Métricas de Traefik reverse proxy

**Dashboard ID:** `17346` (recomendado) o `12250` (alternativo)
**Fuente:** https://grafana.com/grafana/dashboards/17346
**Datasource:** VictoriaMetrics

**Métricas incluidas:**
- Request rate por servicio
- Response time (p50, p95, p99)
- HTTP status codes (2xx, 3xx, 4xx, 5xx)
- Active connections
- Certificados SSL status

**Nota:** Si no funciona, usar ID 12250 o 11462 como alternativa.

---

### 3. Docker Container Metrics (ID: 193)
**Propósito:** Métricas de contenedores Docker via cAdvisor

**Dashboard ID:** `193` (recomendado) o `15798` (alternativo)
**Fuente:** https://grafana.com/grafana/dashboards/193
**Datasource:** VictoriaMetrics

**Métricas incluidas:**
- CPU usage por contenedor
- Memory usage por contenedor
- Network I/O por contenedor
- Disk I/O por contenedor
- Container restart count

**Compatibilidad:** ✅ Compatible con cAdvisor + VictoriaMetrics

---

### 4. VictoriaMetrics Cluster (ID: 11176)
**Propósito:** Métricas internas de VictoriaMetrics

**Dashboard ID:** `11176`
**Fuente:** https://grafana.com/grafana/dashboards/11176
**Datasource:** VictoriaMetrics

**Métricas incluidas:**
- Ingestion rate
- Active series
- Memory usage de VictoriaMetrics
- Query performance
- Storage size

**Útil para:** Monitorear la salud del propio sistema de métricas.

---

### 5. Loki Logs Dashboard (ID: 13639)
**Propósito:** Visualización de logs centralizados

**Dashboard ID:** `13639`
**Fuente:** https://grafana.com/grafana/dashboards/13639
**Datasource:** Loki

**Features:**
- Log stream por contenedor
- Log volume over time
- Filtros por label (container, compose_service)
- Search logs con LogQL

---

## 🎨 Dashboard Custom: Platform Overview

Dashboard personalizado con vista general de la plataforma.

### Crear manualmente:

1. **Dashboards** → **New Dashboard** → **Add visualization**
2. Datasource: **VictoriaMetrics**
3. Añadir estos paneles:

#### Panel 1: Service Status
```promql
up
```
**Visualization:** Stat
**Thresholds:** 0 = Red, 1 = Green

#### Panel 2: CPU Usage
```promql
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```
**Visualization:** Time series
**Unit:** percent (0-100)

#### Panel 3: Memory Usage
```promql
100 * (1 - ((node_memory_MemAvailable_bytes) / (node_memory_MemTotal_bytes)))
```
**Visualization:** Gauge
**Unit:** percent (0-100)
**Thresholds:** 80% = Yellow, 90% = Red

#### Panel 4: Disk Usage
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})
```
**Visualization:** Gauge
**Unit:** percent (0-100)
**Thresholds:** 85% = Yellow, 95% = Red

#### Panel 5: Container Count
```promql
count(container_last_seen{name=~".+"})
```
**Visualization:** Stat

#### Panel 6: Traefik Request Rate
```promql
sum(rate(traefik_service_requests_total[5m])) by (service)
```
**Visualization:** Time series
**Unit:** requests/sec

#### Panel 7: Traefik Error Rate
```promql
sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) by (service)
```
**Visualization:** Time series
**Color:** Red

#### Panel 8: Network Traffic
```promql
# Received
rate(node_network_receive_bytes_total[5m])

# Transmitted
rate(node_network_transmit_bytes_total[5m])
```
**Visualization:** Time series
**Unit:** bytes/sec

---

## 🔍 Queries Útiles

### Ver todos los servicios monitoreados
```promql
up
```

### CPU usage de contenedores
```promql
rate(container_cpu_usage_seconds_total{name=~".+"}[5m]) * 100
```

### RAM usage de contenedores
```promql
container_memory_usage_bytes{name=~".+"} / 1024 / 1024
```

### Logs de un contenedor específico (Loki)
```logql
{container="traefik"}
```

### Logs con errores
```logql
{compose_project="monitoring"} |= "error"
```

---

## ✅ Dashboards Instalados

- [ ] Node Exporter Full (1860)
- [ ] Traefik Dashboard (17346)
- [ ] Docker Container Metrics (193)
- [ ] VictoriaMetrics Cluster (11176)
- [ ] Loki Logs Dashboard (13639)
- [ ] Platform Overview (custom)

---

## 📞 Soporte

Si un dashboard no funciona:
1. Verificar que el datasource seleccionado es **VictoriaMetrics** (no Prometheus)
2. Revisar que las métricas están disponibles en Explore
3. Buscar dashboard alternativo en https://grafana.com/grafana/dashboards/

**Última actualización:** 2025-10-04
