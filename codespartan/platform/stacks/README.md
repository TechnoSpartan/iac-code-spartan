# 📊 Platform Stacks - CodeSpartan

Servicios de plataforma comunes para el stack CodeSpartan Mambo Cloud.

## 📁 Stacks Disponibles

### 1. Monitoring Stack (`monitoring/`)

Stack completo de observabilidad con métricas y logs centralizados.

**Componentes:**
- **VictoriaMetrics** - Time-series database (7x menos RAM que Prometheus)
- **vmagent** - Agente de scraping de métricas
- **Grafana** - Visualización de métricas y logs
- **Loki** - Agregación y almacenamiento de logs
- **Promtail** - Recolector de logs de contenedores Docker
- **cAdvisor** - Métricas de contenedores
- **Node Exporter** - Métricas del sistema operativo

**Recursos estimados:** ~650-750 MB RAM total

**Retención:** 7 días para métricas y logs

**Acceso:** https://grafana.mambo-cloud.com (admin/codespartan123)

### 2. Backoffice Stack (`backoffice/`)

Dashboard de gestión y administración de la plataforma.

**Acceso:** https://backoffice.mambo-cloud.com (admin/codespartan123)

---

## 🚀 Despliegue

### Desplegar Monitoring Stack

```bash
# Manual
cd /opt/codespartan/platform/stacks/monitoring
docker compose pull
docker compose up -d

# Via GitHub Actions
# Actions → Deploy Monitoring Stack → Run workflow
```

### Verificar Estado

```bash
# Ver contenedores
docker ps | grep -E "victoriametrics|vmagent|loki|promtail|grafana|cadvisor|node-exporter"

# Ver logs
docker logs victoriametrics -f
docker logs grafana -f
docker logs loki -f
```

---

## 📊 Monitoring Stack - Configuración Detallada

### VictoriaMetrics

**Imagen:** `victoriametrics/victoria-metrics:v1.93.0`

**Configuración:**
- Puerto: 8428
- Retención: 7 días
- Volumen: `victoria-data:/storage`

**Métricas expuestas:** http://victoriametrics:8428/metrics

### vmagent

**Imagen:** `victoriametrics/vmagent:v1.93.0`

**Targets configurados:**
- `victoriametrics:8428` - Métricas propias de VictoriaMetrics
- `traefik:8080` - Métricas HTTP y request rate de Traefik
- `cadvisor:8080` - Métricas de contenedores Docker
- `node-exporter:9100` - Métricas del sistema (CPU, RAM, Disk, Network)

**Configuración:** `victoriametrics/prometheus.yml`

**Intervalo de scrape:** 15 segundos

### Grafana

**Imagen:** `grafana/grafana:10.4.5`

**Datasources pre-configurados:**
1. **VictoriaMetrics** (default) - http://victoriametrics:8428
2. **Loki** - http://loki:3100

**Configuración:**
- Auto-provisioning de datasources: `grafana/provisioning/datasources/datasource.yml`
- Auto-provisioning de dashboards: `grafana/provisioning/dashboards/`
- Dashboards: `grafana/dashboards/`

**Variables de entorno:**
```bash
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=codespartan123
GRAFANA_HOST=grafana.mambo-cloud.com
```

### Loki

**Imagen:** `grafana/loki:2.9.0`

**Configuración:** `loki/loki.yml`

**Storage:** Filesystem local (boltdb-shipper)
- Chunks: `/loki/chunks`
- Rules: `/loki/rules`
- Index prefix: `index_`

**Retención:**
- Período: 168 horas (7 días)
- Compactación: Cada 10 minutos
- Workers: 150

**Límites:**
- Ingestion rate: 16 MB/s
- Burst size: 32 MB

### Promtail

**Imagen:** `grafana/promtail:2.9.0`

**Configuración:** `promtail/promtail.yml`

**Fuentes de logs:**
- Docker daemon socket: `unix:///var/run/docker.sock`
- Container logs: `/var/lib/docker/containers`

**Labels automáticos:**
- `container` - Nombre del contenedor
- `stream` - stdout/stderr
- `compose_project` - Proyecto docker-compose
- `compose_service` - Servicio docker-compose

**Refresh interval:** 5 segundos

### cAdvisor

**Imagen:** `gcr.io/cadvisor/cadvisor:v0.47.2`

**Métricas:**
- CPU por contenedor
- RAM por contenedor
- Network I/O por contenedor
- Disk I/O por contenedor

**Puerto:** 8080

### Node Exporter

**Imagen:** `prom/node-exporter:v1.8.2`

**Métricas del sistema:**
- CPU usage y load average
- RAM total/usada/disponible
- Disk usage por filesystem
- Network I/O por interfaz
- Uptime del sistema

**Puerto:** 9100

---

## 📈 Uso de Grafana

### Consultar Métricas

1. Ve a https://grafana.mambo-cloud.com
2. Login con admin/codespartan123
3. Menú lateral → Explore
4. Datasource: VictoriaMetrics

**Queries útiles:**
```promql
# Ver servicios scraped
up

# CPU usage de contenedores
rate(container_cpu_usage_seconds_total[5m])

# RAM usage de contenedores
container_memory_usage_bytes / 1024 / 1024

# Request rate de Traefik
rate(traefik_service_requests_total[1m])

# Response time de Traefik
traefik_service_request_duration_seconds_sum
```

### Consultar Logs

1. Explore → Datasource: Loki
2. Label filters:
   - `container` - Filtrar por nombre de contenedor
   - `compose_service` - Filtrar por servicio
   - `stream` - stdout o stderr

**LogQL queries útiles:**
```logql
# Todos los logs
{compose_project="monitoring"}

# Logs de un contenedor específico
{container="traefik"}

# Logs con errores
{compose_project="monitoring"} |= "error"

# Logs en un rango de tiempo
{container="grafana"} [5m]
```

---

## 🔧 Troubleshooting

### VictoriaMetrics no recibe métricas

```bash
# Verificar vmagent está scrapeando
docker logs vmagent | grep "scraped"

# Verificar targets en vmagent
curl http://localhost:8428/api/v1/targets

# Revisar configuración
cat /opt/codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml
```

### Grafana no muestra datasources

```bash
# Verificar provisioning
docker exec grafana ls -la /etc/grafana/provisioning/datasources/

# Verificar logs
docker logs grafana | grep -i datasource

# Reiniciar Grafana
docker restart grafana
```

### Loki no recibe logs

```bash
# Verificar Promtail está enviando
docker logs promtail | grep "sent"

# Verificar conexión Promtail → Loki
docker exec promtail wget -qO- http://loki:3100/ready

# Ver logs de Loki
docker logs loki | grep -i error
```

### Retención no funciona (datos no se borran)

```bash
# Verificar compactor está corriendo
docker logs loki | grep compactor

# Forzar compactación manual (no recomendado)
docker restart loki
```

---

## 🎯 Mejoras Futuras

- [ ] **Alertas** - Configurar AlertManager para notificaciones
- [ ] **Dashboards** - Importar dashboards pre-configurados de Grafana.com
- [ ] **Backups** - Backup automático de volúmenes de datos
- [ ] **S3 Storage** - Migrar de filesystem a S3-compatible storage
- [ ] **Multi-tenancy** - Habilitar auth_enabled en Loki
- [ ] **Distributed Tracing** - Añadir Tempo para trazas distribuidas
- [ ] **Métricas custom** - Instrumentar aplicaciones con Prometheus client

---

## 📞 Soporte

Para problemas con el stack de monitoring:

1. **Verificar contenedores:** `docker ps`
2. **Ver logs:** `docker logs [container-name]`
3. **Consultar documentación:**
   - [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
   - [Grafana Docs](https://grafana.com/docs/)
   - [Loki Docs](https://grafana.com/docs/loki/)
   - [Promtail Docs](https://grafana.com/docs/loki/latest/send-data/promtail/)

---

**Última actualización:** 2025-01-04
**Versiones:**
- VictoriaMetrics: v1.93.0
- Grafana: 10.4.5
- Loki: 2.9.0
- Promtail: 2.9.0
- cAdvisor: v0.47.2
- Node Exporter: v1.8.2
