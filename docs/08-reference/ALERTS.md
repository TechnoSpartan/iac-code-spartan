# Sistema de Alertas - Referencia

Referencia rápida del sistema de alertas. Para documentación completa, ver [Monitoreo y Alertas](../03-operations/MONITORING.md).

## Arquitectura

```
vmalert → Alertmanager → ntfy-forwarder → ntfy.sh + Discord
```

## Componentes

- **vmalert**: Evalúa reglas de alertas contra métricas de VictoriaMetrics
- **Alertmanager**: Agrupa, deduplica y enruta alertas
- **ntfy-forwarder**: Convierte webhooks de Alertmanager a múltiples formatos
- **ntfy.sh**: Servicio público de notificaciones push móviles
- **Discord**: Notificaciones con rich embeds en servidor Discord

## Alertas Configuradas

### Infraestructura

- HighCPUUsage: CPU > 80% por 5 min (warning)
- CriticalCPUUsage: CPU > 95% por 2 min (critical)
- HighMemoryUsage: RAM > 90% por 3 min (warning)
- CriticalMemoryUsage: RAM > 95% por 1 min (critical)
- HighDiskUsage: Disk > 85% por 5 min (warning)
- CriticalDiskUsage: Disk > 95% por 2 min (critical)

### Servicios

- ServiceDown: Servicio caído > 2 minutos
- ContainerDown: Contenedor detenido > 2 minutos

### VictoriaMetrics

- HighMemoryUsage: Memoria > 1.5GB
- StorageIssues: Disco libre < 5GB

### Traefik

- HTTP5xxErrors: > 10 errores/s (warning), > 50 errores/s (critical)

## Recibir Alertas

### Móvil (Recomendado)

1. Instala app "ntfy" desde Play Store o App Store
2. Suscríbete a topic: `codespartan-mambo-alerts`

### Web

- https://ntfy.sh/codespartan-mambo-alerts

### Línea de Comandos

```bash
curl -s ntfy.sh/codespartan-mambo-alerts/json
```

## Ver Alertas Activas

```bash
# Ver reglas de alertas
curl http://localhost:8880/api/v1/rules

# Ver alertas en Alertmanager
curl http://localhost:9093/api/v2/alerts
```

## Silenciar Alertas Temporalmente

```bash
curl -X POST http://localhost:9093/api/v2/silences -H "Content-Type: application/json" -d '{
  "matchers": [{"name": "alertname", "value": "HighCPUUsage", "isRegex": false}],
  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
  "createdBy": "admin",
  "comment": "Maintenance window"
}'
```

## Documentación Completa

Para configuración detallada y troubleshooting, ver [Monitoreo y Alertas](../03-operations/MONITORING.md).

