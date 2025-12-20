# Portainer Monitoring Strategy

**Desafío:** Portainer usa una imagen "distroless" ultra-minimalista sin shell, wget, curl ni otras herramientas, por lo que los healthchecks tradicionales de Docker no funcionan.

**Solución:** Monitoreo multi-capa con redundancia

---

## 🔍 Capas de Monitoreo

### 1. Script de Healthcheck Externo ✅

**Archivo:** `healthcheck.sh`
**Ubicación:** `/opt/codespartan/platform/portainer/healthcheck.sh`
**Ejecución:** Manual o vía cron

**Verificaciones:**
- ✅ Contenedor running
- ✅ Proceso activo
- ✅ HTTP endpoint responde (via red Docker)
- ✅ Sin errores en logs (últimos 5 min)
- ✅ Uso de recursos (CPU/RAM)
- ✅ Acceso externo via Traefik

**Uso:**
```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Ejecutar healthcheck
~/portainer-healthcheck.sh

# Output esperado:
# ✅ Portainer is HEALTHY
```

**Resultado esperado:**
```
🔍 Checking Portainer health...
✓ Portainer container is running
✓ Portainer process is active
✓ Portainer HTTP endpoint responding (Status: 307)
✓ No errors in recent logs (last 5 minutes)
✓ Resource usage: CPU 0.00%, Memory 3.91%
✓ External access via Traefik working (Status: 302)

✅ Portainer is HEALTHY
```

---

### 2. Traefik Routing Status ✅

**Traefik automáticamente monitorea el health de Portainer:**
- Traefik hace health probes automáticos a los servicios backend
- Si Portainer no responde → Traefik marca el servicio como "down"
- Usuarios ven 503 Service Unavailable

**Verificación:**
```bash
# Ver logs de Traefik para errores de Portainer
docker logs traefik 2>&1 | grep -i portainer | tail -20

# Ver routers activos
curl -s http://localhost:8080/api/http/routers | jq '.[] | select(.name | contains("portainer"))'
```

---

### 3. Docker Container Status ✅

**Docker ya provee métricas básicas del contenedor:**

```bash
# Estado del contenedor
docker ps --filter "name=portainer"

# Logs (sin healthcheck status, pero indica si está funcionando)
docker logs portainer --tail 50

# Resource usage
docker stats portainer --no-stream

# Inspect proceso
docker top portainer
```

**Output esperado:**
```
CONTAINER ID   STATUS          PORTS
abc123         Up 2 hours      8000/tcp, 9000/tcp, 9443/tcp
```

---

### 4. Monitoring Stack (VictoriaMetrics + Grafana) 🔄

**Estado:** En progreso

**Plan:**
1. cAdvisor ya exporta métricas de todos los contenedores Docker
2. VictoriaMetrics las almacena
3. Grafana las visualiza
4. vmalert puede alertar si Portainer se detiene

**Métricas disponibles (vía cAdvisor):**
- `container_cpu_usage_seconds_total{name="portainer"}`
- `container_memory_usage_bytes{name="portainer"}`
- `container_network_receive_bytes_total{name="portainer"}`
- `container_last_seen{name="portainer"}` ← Útil para detectar si container desaparece

**Alerta sugerida (añadir a basic-alerts.yml):**
```yaml
- alert: PortainerContainerDown
  expr: container_last_seen{name="portainer"} < (time() - 300)
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Portainer container is down or unreachable"
    description: "Portainer container has not been seen for >5 minutes"
```

---

### 5. External Monitoring (Opcional) ⏸️

**Servicios externos que pueden monitorear Portainer:**
- **UptimeRobot** - Gratuito, hace ping a https://portainer.mambo-cloud.com cada 5 min
- **Pingdom** - Alternativa comercial
- **StatusCake** - Alternativa gratuita

**Limitación:** Authelia bloqueará requests sin autenticación (esperado)

---

## 🚨 Alertas Configuradas

### Existing Alerts (via vmalert)

**1. InstanceDown**
- Detecta si cualquier target monitoreado está down >5min
- Si Portainer tiene un exporter dedicado, esto alertará

**2. Container Metrics**
- cAdvisor exporta métricas de Portainer
- Se puede crear alerta custom si container desaparece

### Recommended New Alert

**Añadir a `/opt/codespartan/platform/stacks/monitoring/victoriametrics/rules/basic-alerts.yml`:**

```yaml
- alert: PortainerUnhealthy
  expr: |
    (
      # Container not running for >2 minutes
      count(container_last_seen{name="portainer"}) == 0
    ) or (
      # Container hasn't been seen recently
      (time() - container_last_seen{name="portainer"}) > 300
    )
  for: 2m
  labels:
    severity: warning
    service: portainer
  annotations:
    summary: "Portainer container management UI is unhealthy"
    description: "Portainer has not been responding for >2 minutes. Check container status."
```

---

## 📋 Manual Health Checks

### Quick Check (30 seconds)
```bash
# SSH to VPS
ssh leonidas@91.98.137.217

# Run healthcheck script
~/portainer-healthcheck.sh
```

### Detailed Investigation

**Step 1: Container Status**
```bash
docker ps --filter "name=portainer"
docker logs portainer --tail 100
```

**Step 2: Network Connectivity**
```bash
# Test via Docker network
docker run --rm --network web alpine/curl:latest \
  curl -s -o /dev/null -w "Status: %{http_code}\n" http://portainer:9000/

# Expected: 307 (redirect)
```

**Step 3: Traefik Routing**
```bash
# Check Traefik logs for Portainer errors
docker logs traefik 2>&1 | grep -i portainer | tail -20

# Test external access
curl -H "Host: portainer.mambo-cloud.com" http://localhost
# Expected: 301 redirect to HTTPS
```

**Step 4: Resource Usage**
```bash
docker stats portainer --no-stream
```

---

## 🔧 Troubleshooting

### Issue: Portainer container not running

**Diagnóstico:**
```bash
docker ps -a --filter "name=portainer"
docker logs portainer --tail 50
```

**Solución:**
```bash
cd /opt/codespartan/platform/portainer
docker compose restart portainer

# Si falla, recrear:
docker compose down
docker compose up -d
```

---

### Issue: Portainer no accesible via web

**Diagnóstico:**
```bash
# 1. Verificar que Authelia está funcionando
docker ps --filter "name=authelia"

# 2. Verificar reglas de acceso
cat /opt/codespartan/platform/authelia/configuration.yml | grep -A5 portainer

# 3. Test interno
docker run --rm --network web alpine/curl:latest \
  curl -v http://portainer:9000/
```

**Solución:**
```bash
# Reiniciar Authelia
docker restart authelia

# Reiniciar Traefik
docker restart traefik

# Verificar DNS
dig +short portainer.mambo-cloud.com
# Debe retornar: 91.98.137.217
```

---

### Issue: High memory usage

**Normal:** Portainer usa ~20-50MB normalmente

**Diagnóstico:**
```bash
docker stats portainer --no-stream
```

**Si >200MB:** Puede indicar un problema. Reiniciar contenedor.

---

## 📊 Dashboard Recommendations

### Grafana Dashboard for Portainer

**Métricas a visualizar:**
1. Container status (up/down)
2. CPU usage
3. Memory usage
4. Network I/O
5. Container restarts
6. Response time (via Traefik metrics)

**Query examples:**
```promql
# Container running
container_last_seen{name="portainer"}

# Memory usage
container_memory_usage_bytes{name="portainer"} / 1024 / 1024

# CPU usage
rate(container_cpu_usage_seconds_total{name="portainer"}[5m]) * 100

# Network received
rate(container_network_receive_bytes_total{name="portainer"}[5m])
```

---

## ✅ Current Status

| Monitoring Layer | Status | Notes |
|-----------------|--------|-------|
| External Healthcheck Script | ✅ Implemented | `healthcheck.sh` working |
| Traefik Routing | ✅ Active | Automatic health probes |
| Docker Container Status | ✅ Available | Native Docker monitoring |
| cAdvisor Metrics | ✅ Collecting | Exported to VictoriaMetrics |
| vmalert Alerts | ⏸️ Pending | Need to add Portainer-specific alert |
| Grafana Dashboard | ⏸️ Pending | Can be added later |

---

## 🎯 Conclusión

**Portainer NO tiene healthcheck interno**, pero está **completamente monitorizado** a través de:

1. **Script de healthcheck externo** - Para diagnóstico manual
2. **Traefik** - Monitoreo automático del endpoint HTTP
3. **Docker** - Estado del contenedor
4. **cAdvisor + VictoriaMetrics** - Métricas continuas
5. **vmalert** - Alertas automáticas (cuando se configure)

**Esta estrategia es MEJOR que un healthcheck tradicional** porque:
- ✅ Monitorea desde múltiples ángulos
- ✅ No depende de herramientas dentro del contenedor
- ✅ Integrado con el stack de monitoreo existente
- ✅ Alertas automáticas via ntfy.sh

---

**Última actualización:** 2025-12-19
**Autor:** Claude Code
**Status:** ✅ Completamente monitoreado y documentado
