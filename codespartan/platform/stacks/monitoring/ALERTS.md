# 🔔 Sistema de Alertas - CodeSpartan Mambo Cloud

Sistema de notificaciones proactivas para monitoreo de infraestructura.

---

## 📱 Cómo Recibir Alertas

### Opción 1: App Móvil (Recomendado)

1. **Descargar ntfy app:**
   - iOS: https://apps.apple.com/app/ntfy/id1625396347
   - Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy

2. **Suscribirse al topic:**
   - Abrir app ntfy
   - Tap en "+" (añadir suscripción)
   - Topic: `codespartan-mambo-alerts`
   - Server: `https://ntfy.sh` (por defecto)
   - Guardar

3. **Configurar notificaciones:**
   - Habilitar notificaciones push
   - Configurar sonido/vibración según preferencia
   - Recomendado: Habilitar "Priority notifications"

### Opción 2: Navegador Web

Visitar: https://ntfy.sh/codespartan-mambo-alerts

### Opción 3: Email (Opcional)

En la app, configurar "Email notifications" para recibir copia por email.

---

## 🚨 Alertas Configuradas

### **Nivel: CRITICAL** 🔴

Problemas graves que requieren atención inmediata.

| Alerta | Condición | Duración | Descripción |
|--------|-----------|----------|-------------|
| **CriticalCPUUsage** | CPU > 95% | 2 min | CPU al límite |
| **CriticalMemoryUsage** | RAM > 95% | 1 min | Memoria casi llena |
| **CriticalDiskUsage** | Disk > 95% | 2 min | Disco casi lleno |
| **ServiceDown** | Service down | 2 min | Servicio caído |
| **ContainerDown** | Container down | 2 min | Contenedor caído |
| **CriticalHTTP5xxRate** | >50 errors/s | 1 min | Muchos errores 5xx |

### **Nivel: WARNING** ⚠️

Problemas que requieren atención pero no son urgentes.

| Alerta | Condición | Duración | Descripción |
|--------|-----------|----------|-------------|
| **HighCPUUsage** | CPU > 80% | 5 min | CPU elevada |
| **HighMemoryUsage** | RAM > 90% | 3 min | Memoria elevada |
| **HighDiskUsage** | Disk > 85% | 5 min | Disco elevado |
| **VictoriaMetricsHighMemory** | VM > 1.5GB | 5 min | VictoriaMetrics usando mucha RAM |
| **VictoriaMetricsStorageIssue** | Free < 5GB | 5 min | VictoriaMetrics poco espacio |
| **HighHTTP5xxRate** | >10 errors/s | 2 min | Errores 5xx elevados |

---

## 🎯 Arquitectura del Sistema

```
┌─────────────────────┐
│  VictoriaMetrics    │  ← Almacena métricas
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│     vmalert         │  ← Evalúa reglas cada 30s
│                     │
│  - rules.yml        │
│  - evaluationInterval: 30s
└──────────┬──────────┘
           │
           │ (cuando se dispara alerta)
           ▼
┌─────────────────────┐
│    ntfy.sh API      │  ← Servicio de notificaciones
│                     │
│  Topic: codespartan-mambo-alerts
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Tu Dispositivo    │  ← Notificación push
│                     │
│  - App móvil        │
│  - Navegador        │
│  - Email (opcional) │
└─────────────────────┘
```

---

## 📊 Métricas Monitoreadas

### Infraestructura (Node Exporter)
- **CPU**: `node_cpu_seconds_total`
- **RAM**: `node_memory_MemAvailable_bytes`, `node_memory_MemTotal_bytes`
- **Disk**: `node_filesystem_avail_bytes`, `node_filesystem_size_bytes`

### Servicios
- **Uptime**: `up` (0 = down, 1 = up)

### Contenedores (cAdvisor)
- **Last Seen**: `container_last_seen`

### VictoriaMetrics
- **Memory**: `vm_app_rss_bytes`
- **Storage**: `vm_free_disk_space_bytes`

### Traefik
- **Requests**: `traefik_service_requests_total`
- **Errors**: `traefik_service_requests_total{code=~"5.."}`

---

## 🔧 Configuración

### Archivos de Configuración

**`alerts/rules.yml`** - Reglas de alertas
- Grupos: infrastructure_alerts, service_alerts, victoriametrics_alerts, traefik_alerts
- Evaluación: Cada 30 segundos
- Formato: PromQL

**`docker-compose.yml`** - Servicio vmalert
- Imagen: `victoriametrics/vmalert:v1.93.0`
- Puerto: 8880
- Datasource: VictoriaMetrics (http://victoriametrics:8428)
- Notifier: ntfy.sh (https://ntfy.sh/codespartan-mambo-alerts)

### Variables Importantes

```yaml
evaluationInterval: 30s    # Cada cuánto evalúa las reglas
notifier.url: https://ntfy.sh/codespartan-mambo-alerts  # Dónde enviar alertas
```

---

## 🧪 Testing de Alertas

### Test Manual: Generar Alerta de CPU

```bash
# SSH al servidor
ssh leonidas@91.98.137.217

# Estresar CPU por 6 minutos (dispara alerta después de 5 min)
stress --cpu 4 --timeout 360s
```

**Resultado esperado:**
- A los 5 minutos: Alerta **HighCPUUsage** (⚠️ WARNING)
- Si continúa, alerta **CriticalCPUUsage** (🔴 CRITICAL)

### Test Manual: Simular Servicio Caído

```bash
# Parar un servicio no crítico
docker stop backoffice

# Esperar 2 minutos

# Deberías recibir alerta "ServiceDown"

# Volver a levantar
docker start backoffice
```

### Verificar vmalert

```bash
# Ver logs de vmalert
docker logs vmalert

# Ver reglas cargadas
curl http://localhost:8880/api/v1/rules

# Ver alertas activas
curl http://localhost:8880/api/v1/alerts
```

---

## 📲 Formato de Notificaciones

Las notificaciones en ntfy.sh incluyen:

**Título:**
```
[CRITICAL] ServiceDown
[WARNING] HighCPUUsage
```

**Mensaje:**
```
Service victoriametrics on instance:9100 has been down for more than 2 minutes
```

**Prioridad:**
- 🔴 CRITICAL: Prioridad 5 (máxima)
- ⚠️ WARNING: Prioridad 3 (media)

---

## 🔕 Silenciar Alertas

### Temporalmente (desde la app)

1. Abrir ntfy app
2. Long press en topic `codespartan-mambo-alerts`
3. Settings → Mute notifications
4. Seleccionar duración (1h, 8h, etc.)

### Permanentemente (modificar reglas)

Editar `alerts/rules.yml` y comentar la regla:

```yaml
# - alert: HighCPUUsage
#   expr: ...
```

Hacer commit y push → Se despliega automáticamente.

---

## 🚀 Añadir Nuevas Alertas

1. **Editar** `alerts/rules.yml`

```yaml
- alert: NombreDeLaAlerta
  expr: metrica > threshold
  for: 5m
  labels:
    severity: warning  # o critical
    component: nombre_componente
  annotations:
    summary: "Resumen corto"
    description: "Descripción detallada con {{ $value }}"
```

2. **Commit y Push**

```bash
git add codespartan/platform/stacks/monitoring/alerts/rules.yml
git commit -m "feat: add new alert rule"
git push
```

3. **GitHub Actions** despliega automáticamente

4. **Verificar** que la regla se cargó:

```bash
docker logs vmalert | grep "loaded"
```

---

## 🎯 Mejoras Futuras

- [ ] **AlertManager** - Para agrupación avanzada de alertas
- [ ] **Slack integration** - Notificaciones en canal de equipo
- [ ] **PagerDuty** - Escalado de alertas para on-call
- [ ] **Silencing UI** - Interface web para silenciar alertas
- [ ] **Alert history** - Dashboard de histórico de alertas en Grafana
- [ ] **SSL Certificate expiry** - Alertas 7 días antes de expiración

---

## 📞 Troubleshooting

### No recibo notificaciones

1. **Verificar vmalert está corriendo:**
   ```bash
   docker ps | grep vmalert
   ```

2. **Ver logs de vmalert:**
   ```bash
   docker logs vmalert
   ```

3. **Verificar reglas cargadas:**
   ```bash
   curl http://localhost:8880/api/v1/rules | jq
   ```

4. **Verificar conectividad con ntfy.sh:**
   ```bash
   curl -d "Test desde servidor" https://ntfy.sh/codespartan-mambo-alerts
   ```

5. **Revisar app móvil:**
   - Verificar suscripción activa
   - Verificar notificaciones habilitadas
   - Verificar conexión a internet

### Las alertas se disparan demasiado

**Ajustar umbrales** en `alerts/rules.yml`:

```yaml
# Antes
expr: cpu > 80
for: 5m

# Después (más tolerante)
expr: cpu > 90
for: 10m
```

### Recibo alertas duplicadas

vmalert envía notificación cada vez que evalúa y la alerta está activa.
Considera usar **AlertManager** para deduplicación si es molesto.

---

## 📚 Referencias

- **ntfy.sh Docs**: https://docs.ntfy.sh/
- **vmalert Docs**: https://docs.victoriametrics.com/vmalert.html
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Alert Rules Examples**: https://awesome-prometheus-alerts.grep.to/

---

**Última actualización:** 2025-10-05
**Versión vmalert:** v1.93.0
**Topic ntfy.sh:** `codespartan-mambo-alerts`
