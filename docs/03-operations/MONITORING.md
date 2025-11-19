# Sistema de Alertas - CodeSpartan Mambo Cloud

## Arquitectura

El sistema de alertas usa un pipeline multi-canal:

```
vmalert → Alertmanager → ntfy-forwarder → ntfy.sh + Discord
```

### Componentes

1. **vmalert** - Evalúa reglas de alertas contra métricas de VictoriaMetrics
2. **Alertmanager** - Agrupa, deduplica y enruta alertas
3. **ntfy-forwarder** - Convierte webhooks de Alertmanager a múltiples formatos (ntfy.sh + Discord)
4. **ntfy.sh** - Servicio público de notificaciones push móviles
5. **Discord** - Notificaciones con rich embeds en servidor Discord

## Reglas de Alertas Configuradas

### Infraestructura (`infrastructure_alerts`)

| Alerta | Condición | Duración | Severidad | Descripción |
|--------|-----------|----------|-----------|-------------|
| HighCPUUsage | CPU > 80% | 5 min | warning | Alto uso de CPU sostenido |
| CriticalCPUUsage | CPU > 95% | 2 min | critical | CPU casi saturada |
| HighMemoryUsage | RAM > 90% | 3 min | warning | Memoria alta |
| CriticalMemoryUsage | RAM > 95% | 1 min | critical | Memoria crítica |
| HighDiskUsage | Disk > 85% | 5 min | warning | Disco llenándose |
| CriticalDiskUsage | Disk > 95% | 2 min | critical | Disco casi lleno |

### Servicios (`service_alerts`)

| Alerta | Condición | Duración | Severidad | Descripción |
|--------|-----------|----------|-----------|-------------|
| ServiceDown | up == 0 | 2 min | critical | Servicio caído |
| ContainerDown | container not seen > 2min | 0 min | critical | Contenedor no responde |

### VictoriaMetrics (`victoriametrics_alerts`)

| Alerta | Condición | Duración | Severidad | Descripción |
|--------|-----------|----------|-----------|-------------|
| VictoriaMetricsHighMemory | RAM > 1.5GB | 5 min | warning | VictoriaMetrics usando mucha memoria |
| VictoriaMetricsStorageIssue | Free disk < 5GB | 5 min | warning | Poco espacio para métricas |

### Traefik (`traefik_alerts`)

| Alerta | Condición | Duración | Severidad | Descripción |
|--------|-----------|----------|-----------|-------------|
| HighHTTP5xxRate | 5xx errors > 10/s | 2 min | warning | Muchos errores 5xx |
| CriticalHTTP5xxRate | 5xx errors > 50/s | 1 min | critical | Tasa crítica de errores |

## Configuración de Notificaciones

### Enrutamiento por Severidad

**Alertas Críticas:**
- Grupo: `severity=critical`
- Espera: 0 segundos (inmediato)
- Repetición: Cada 1 hora si persiste
- Prioridad ntfy.sh: 5 (máxima)

**Alertas Warning:**
- Grupo: `severity=warning`
- Espera: 30 segundos (para agrupar)
- Repetición: Cada 12 horas
- Prioridad ntfy.sh: 4

### Formato de Notificación

```
🔥 ALERTA: ServiceDown
Service is down

Service vmagent on victoriametrics:8429 has been down for more than 2 minutes

Componente: service
Instancia: victoriametrics:8429
```

**Cuando se resuelve:**

```
✅ RESUELTO: ServiceDown
Service is down

Service vmagent on victoriametrics:8429 has been down for more than 2 minutes

Componente: service
Instancia: victoriametrics:8429
```

## Suscribirse a Alertas

### Opción 1: App Móvil ntfy (Recomendado)

1. Descarga la app **ntfy** desde:
   - [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [Apple App Store](https://apps.apple.com/app/ntfy/id1625396347)

2. Agrega el topic: `codespartan-mambo-alerts`

3. Activa notificaciones push

### Opción 2: Web Browser

Visita: https://ntfy.sh/codespartan-mambo-alerts

### Opción 3: Script/Curl

```bash
# Suscribirse vía curl (mantiene conexión abierta)
curl -s ntfy.sh/codespartan-mambo-alerts/json

# Ejemplo con procesamiento
curl -s ntfy.sh/codespartan-mambo-alerts/json | while read msg; do
  echo "$(date): $msg"
done
```

### Opción 4: Discord (Recomendado para Equipos)

Las alertas también se envían automáticamente a Discord con formato **rich embed**:

**Características:**
- ✅ **Colores por severidad**: Rojo (critical), Naranja (warning), Azul (info), Verde (resolved)
- ✅ **Emojis visuales**: 🔥 critical, ⚠️ warning, ℹ️ info, ✅ resolved
- ✅ **Información estructurada**: Description, Componente, Instancia, Severidad
- ✅ **Timestamps** automáticos

**Configuración:**
El webhook de Discord está configurado en `docker-compose.yml`:
```yaml
environment:
  - DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID
```

**Ejemplo de alerta en Discord:**
- **Título**: 🔥 ALERTA: ServiceDown
- **Color**: Rojo (#FF0000)
- **Fields**: Componente, Instancia, Severidad
- **Footer**: Estado: ACTIVA
- **Bot Name**: CodeSpartan Alerts

## Gestión de Alertas

### Ver Alertas Activas

```bash
# Vía vmalert
ssh leonidas@91.98.137.217
curl http://localhost:8880/api/v1/rules | jq '.data.groups[].rules[] | select(.state=="firing")'

# Vía Alertmanager
curl http://localhost:9093/api/v2/alerts | jq '.'
```

### Silenciar Alertas

Alertmanager permite silenciar alertas temporalmente:

```bash
# Silenciar alerta específica por 1 hora
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "HighCPUUsage",
        "isRegex": false
      }
    ],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
    "createdBy": "admin",
    "comment": "Maintenance window"
  }'
```

### Agregar Nueva Regla de Alerta

1. Editar archivo de reglas:
```bash
ssh leonidas@91.98.137.217
vi /opt/codespartan/platform/stacks/monitoring/alerts/rules.yml
```

2. Agregar nueva regla:
```yaml
- name: my_alerts
  interval: 30s
  rules:
    - alert: MyCustomAlert
      expr: metric_name > threshold
      for: 5m
      labels:
        severity: warning
        component: myapp
      annotations:
        summary: "Descripción corta"
        description: "Descripción detallada: {{ $value }}"
```

3. Recargar configuración:
```bash
docker restart vmalert
```

## Pruebas

### Simular Alta CPU

```bash
ssh leonidas@91.98.137.217
# Iniciar proceso que consume CPU
nohup yes > /dev/null 2>&1 &
PID=$!

# Esperar 5-7 minutos para que dispare la alerta

# Matar proceso
kill $PID
```

### Simular Servicio Caído

```bash
# Detener un contenedor
docker stop dental-io-web

# Esperar 2 minutos para alerta

# Restaurar
docker start dental-io-web
```

### Enviar Alerta de Prueba

```bash
# Desde el forwarder (bypass vmalert/alertmanager)
curl -X POST http://localhost:8080/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "severity": "info",
        "component": "test"
      },
      "annotations": {
        "summary": "Esta es una prueba",
        "description": "Probando el sistema de alertas"
      }
    }]
  }'
```

## Troubleshooting

### Alertas no llegan a ntfy.sh

1. **Verificar vmalert está evaluando reglas:**
```bash
docker logs vmalert | grep "group.*started"
```

2. **Verificar alertmanager recibe alertas:**
```bash
curl http://localhost:9093/api/v2/alerts
```

3. **Verificar ntfy-forwarder:**
```bash
docker logs ntfy-forwarder
# Debería mostrar "200" en los POST requests
```

4. **Probar ntfy.sh directamente:**
```bash
curl -d "Test message" https://ntfy.sh/codespartan-mambo-alerts
```

### Demasiadas Alertas (Alert Fatigue)

**Ajustar tiempos de espera:**
```yaml
# En alertmanager.yml
route:
  group_wait: 30s      # Esperar más para agrupar
  group_interval: 5m   # Intervalo entre grupos
  repeat_interval: 24h # Repetir menos frecuentemente
```

**Inhibir alertas duplicadas:**
```yaml
# En alertmanager.yml
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

### Alertas no se resuelven automáticamente

```bash
# Verificar que send_resolved esté habilitado
grep -A 5 "webhook_configs:" alertmanager/alertmanager.yml
# Debería mostrar: send_resolved: true
```

### Alerta ServiceDown para cadvisor (Métricas demasiado grandes)

**Síntoma**: Alerta `ServiceDown` para cadvisor se repite cada hora.

**Causa**: cadvisor genera métricas que exceden el límite de scrape de vmagent (16 MB por defecto).

**Diagnóstico**:
```bash
# Ver tamaño de métricas de cadvisor
docker exec cadvisor wget -O- http://localhost:8080/metrics 2>/dev/null | wc -c

# Ver errores de vmagent
docker logs vmagent | grep cadvisor
# Buscar: "exceeds -promscrape.maxScrapeSize=16777216"
```

**Solución Aplicada**:
Filtrar métricas de cadvisor en `docker-compose.yml`:
```yaml
cadvisor:
  command:
    - --docker_only=true
    - --housekeeping_interval=30s
    - --disable_metrics=disk,diskIO,tcp,udp,process,hugetlb,referenced_memory,cpu_topology,resctrl,cpuset,advtcp,memory_numa,sched
    - --store_container_labels=false
```

**Resultado**: Métricas reducidas de ~28 MB a ~180 KB (99.4% reducción).

## Integración con Otros Servicios

### Agregar Canal de Slack

1. Editar `alertmanager/alertmanager.yml`:
```yaml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

2. Actualizar ruta:
```yaml
routes:
  - match:
      severity: critical
    receiver: 'slack'
```

### Agregar Email

```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'ops@codespartan.com'
        from: 'alerts@mambo-cloud.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@mambo-cloud.com'
        auth_password: 'app-password'
```

## Métricas del Sistema de Alertas

El sistema expone sus propias métricas:

```bash
# Alertmanager
curl http://localhost:9093/metrics | grep alertmanager

# vmalert
curl http://localhost:8880/metrics | grep vmalert
```

## Archivos de Configuración

| Archivo | Propósito |
|---------|-----------|
| `alerts/rules.yml` | Definición de reglas de alertas |
| `alertmanager/alertmanager.yml` | Configuración de enrutamiento y receptores |
| `ntfy-forwarder/forwarder.py` | Lógica de conversión webhook → ntfy |
| `docker-compose.yml` | Despliegue de servicios de alertas |

## Monitoreo del Sistema de Alertas

Dashboards sugeridos en Grafana:

1. **Alertmanager Overview**
   - Alertas activas por severidad
   - Tasa de alertas firing/resolved
   - Latencia de notificaciones

2. **Alert Rules**
   - Estado de cada regla (pending/firing)
   - Historial de activaciones
   - Duración de alertas

3. **Notification Channels**
   - Éxito/fallos de envíos
   - Latencia por canal
   - Rate de notificaciones

## Best Practices

1. ✅ **Severidad apropiada**: No todo es critical
2. ✅ **Descripciones claras**: Incluir contexto y próximos pasos
3. ✅ **Umbrales realistas**: Evitar falsos positivos
4. ✅ **Agrupación inteligente**: Reducir ruido
5. ✅ **Runbooks**: Documentar respuesta a cada alerta
6. ✅ **Testing regular**: Probar alertas mensualmente
7. ✅ **Review periódico**: Ajustar reglas basado en experiencia

## Recursos

- [vmalert Documentation](https://docs.victoriametrics.com/vmalert.html)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [ntfy.sh Documentation](https://docs.ntfy.sh/)
- [Alert Fatigue Prevention](https://landing.google.com/sre/sre-book/chapters/monitoring-distributed-systems/)

---

**Última actualización**: 2025-10-16
**Canal de alertas**: https://ntfy.sh/codespartan-mambo-alerts
**Mantenedor**: DevOps Team
