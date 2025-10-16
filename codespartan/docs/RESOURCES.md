# Resource Management - CodeSpartan Mambo Cloud

## Información del VPS

- **Proveedor**: Hetzner Cloud
- **Tipo**: cax11 (ARM64)
- **CPU**: 2 vCPU cores (ARM64)
- **RAM**: 4 GB (3.4 GB utilizables)
- **Disco**: 40 GB SSD
- **Región**: Nuremberg (nbg1)
- **IP**: 91.98.137.217

## Filosofía de Resource Limits

Todos los contenedores en la plataforma tienen límites de recursos configurados para:

1. **Prevenir agotamiento de recursos**: Un contenedor defectuoso no puede consumir toda la RAM del sistema
2. **Garantizar estabilidad**: El sistema operativo siempre tiene recursos disponibles
3. **Facilitar troubleshooting**: Identificar rápidamente contenedores problemáticos
4. **Habilitar auto-recuperación**: Docker puede reiniciar contenedores que exceden límites

## Resource Allocation Breakdown

### Platform Services (Infraestructura)

| Servicio | Contenedor | RAM Limit | CPU Limit | RAM Actual | Propósito |
|----------|-----------|-----------|-----------|------------|-----------|
| Traefik | `traefik` | 512 MB | 0.5 | ~40 MB | Reverse proxy + SSL |
| VictoriaMetrics | `victoriametrics` | 1 GB | 1.0 | ~120 MB | Time-series database |
| Grafana | `grafana` | 512 MB | 0.5 | ~80 MB | Dashboards y visualización |
| Loki | `loki` | 512 MB | 0.5 | ~95 MB | Log aggregation |
| vmagent | `vmagent` | 256 MB | 0.25 | ~130 MB | Metrics collection |
| Promtail | `promtail` | 256 MB | 0.25 | ~60 MB | Log shipping |
| cAdvisor | `cadvisor` | 256 MB | 0.25 | ~195 MB | Container metrics |
| vmalert | `vmalert` | 128 MB | 0.15 | ~12 MB | Alerting engine |
| Node Exporter | `node-exporter` | 128 MB | 0.1 | ~13 MB | System metrics |
| Backoffice | `backoffice` | 128 MB | 0.25 | ~4 MB | Management UI |

**Subtotal Platform**: 3.7 GB límite / ~749 MB uso actual

### Application Services

| Aplicación | Contenedor | RAM Limit | CPU Limit | RAM Actual | Descripción |
|-----------|-----------|-----------|-----------|------------|-------------|
| Cyberdyne Frontend | `cyberdyne-frontend` | 512 MB | 0.5 | ~4 MB | Frontend React |
| Cyberdyne API | `truckworks-api` | 512 MB | 0.5 | ~145 MB | Backend Node.js API |
| Cyberdyne DB | `truckworks-mongodb` | 512 MB | 0.5 | ~180 MB | MongoDB database |
| Mambo Cloud | `mambo-cloud-app` | 128 MB | 0.25 | ~3 MB | Static site Nginx |
| Dental IO | `dental-io-web` | 128 MB | 0.25 | ~3 MB | Whoami test app |

**Subtotal Applications**: 1.8 GB límite / ~335 MB uso actual

### Totales

- **RAM Total Límites**: ~5.5 GB (excede VPS intencionalmente)
- **RAM Uso Actual**: ~1.08 GB (32% del VPS)
- **RAM Disponible**: ~2.3 GB (68% libre)
- **Margen de Seguridad**: Excelente ✅

> **Nota**: La suma de límites puede exceder la RAM física porque los contenedores rara vez usan su límite máximo simultáneamente. Esto se conoce como "overcommitment" y es una práctica estándar.

## Health Checks

Todos los servicios tienen health checks configurados:

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:PORT/"]
  interval: 30s        # Verificar cada 30 segundos
  timeout: 5s          # Timeout de 5 segundos
  retries: 3           # 3 intentos antes de marcar como unhealthy
  start_period: 10s    # Esperar 10s antes de empezar health checks
```

### Estado de Health Checks

```bash
# Verificar salud de todos los contenedores
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Contenedores con health checks activos
docker ps --filter "health=healthy"

# Contenedores con problemas
docker ps --filter "health=unhealthy"
```

## Operaciones de Resource Management

### Verificar Uso de Recursos

```bash
# Vista general de todos los contenedores
ssh leonidas@91.98.137.217 "docker stats --no-stream"

# Ordenar por uso de memoria
ssh leonidas@91.98.137.217 "docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | sort -k2 -h"

# Ordenar por uso de CPU
ssh leonidas@91.98.137.217 "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}' | sort -k2 -h"

# Contenedores sin límites (no debería haber ninguno)
ssh leonidas@91.98.137.217 "docker stats --no-stream | grep 3.402GiB"
```

### Aplicar Nuevos Resource Limits

**IMPORTANTE**: Los límites solo se aplican cuando el contenedor se CREA, no a contenedores existentes.

```bash
# 1. Editar docker-compose.yml
# Agregar sección deploy.resources

# 2. Recrear el contenedor
ssh leonidas@91.98.137.217
cd /opt/codespartan/[ruta-al-servicio]
docker compose down
docker compose up -d

# 3. Verificar límites aplicados
docker stats --no-stream | grep [nombre-contenedor]
```

### Ejemplo de Configuración

```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    restart: unless-stopped

    # Resource Limits
    deploy:
      resources:
        limits:
          cpus: '0.5'       # Máximo 50% de 1 CPU core
          memory: 512M      # Máximo 512 MB RAM
        reservations:
          cpus: '0.1'       # Mínimo garantizado 10%
          memory: 128M      # Mínimo garantizado 128 MB

    # Health Check
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

    networks:
      - web
```

## Guidelines por Tipo de Servicio

### Databases (MongoDB, PostgreSQL, MySQL)
- **RAM**: 512 MB - 1 GB
- **CPU**: 0.5 - 1.0
- **Razón**: Necesitan cachear datos en memoria para buen rendimiento

### APIs/Backend (Node.js, Python, Go)
- **RAM**: 512 MB
- **CPU**: 0.5
- **Razón**: Procesan lógica de negocio, necesitan recursos moderados

### Frontend/SPA (React, Vue, Angular)
- **RAM**: 512 MB
- **CPU**: 0.5
- **Razón**: Build artifacts pueden ser grandes, SSR consume recursos

### Static Sites (Nginx, Apache)
- **RAM**: 128 MB
- **CPU**: 0.25
- **Razón**: Solo sirven archivos estáticos, muy livianos

### Reverse Proxy/Load Balancer (Traefik, Nginx)
- **RAM**: 512 MB
- **CPU**: 0.5
- **Razón**: Manejan todo el tráfico entrante

### Monitoring (Grafana, Loki, Prometheus)
- **RAM**: 512 MB - 1 GB
- **CPU**: 0.5 - 1.0
- **Razón**: Almacenan y consultan grandes volúmenes de métricas/logs

### Collectors (vmagent, Promtail, cAdvisor)
- **RAM**: 256 MB
- **CPU**: 0.25
- **Razón**: Recolectan y envían datos, uso moderado

### Exporters (node-exporter, postgres_exporter)
- **RAM**: 128 MB
- **CPU**: 0.1
- **Razón**: Exponen métricas simple, muy livianos

## Troubleshooting

### Contenedor alcanza límite de memoria

```bash
# Síntomas
docker logs [container] | grep -i "out of memory"
docker events --filter 'event=oom' --since 1h

# Solución 1: Incrementar límite
# Editar docker-compose.yml → aumentar memory limit
docker compose down && docker compose up -d

# Solución 2: Optimizar aplicación
# Revisar memory leaks, optimizar queries, etc.
```

### Contenedor alcanza límite de CPU

```bash
# Síntomas
docker stats --no-stream | grep [container]
# Si CPU% está constantemente cerca de 100% del límite

# Solución 1: Incrementar límite CPU
# Editar docker-compose.yml → aumentar cpus limit

# Solución 2: Scale horizontalmente
# Agregar más réplicas del servicio
```

### Sistema completo sin memoria

```bash
# Verificar uso total
free -h
docker system df

# Limpiar recursos no usados
docker system prune -a --volumes

# Identificar contenedor culpable
docker stats --no-stream | sort -k4 -h
```

## Monitoreo Continuo

### Grafana Dashboards

1. **System Overview**
   - CPU total del VPS
   - RAM total usada/disponible
   - Disk usage
   - Network I/O

2. **Container Resources**
   - CPU por contenedor
   - Memoria por contenedor
   - Top 10 contenedores por uso

3. **Health Status**
   - Contenedores healthy/unhealthy
   - Reintentos de health checks
   - Uptime por servicio

### Alertas Configuradas

- CPU > 80% por 5 minutos
- RAM > 90% por 3 minutos
- Disk > 85%
- Contenedor unhealthy > 2 minutos
- Contenedor reiniciado > 3 veces en 10 minutos

## Best Practices

1. ✅ **Siempre define resource limits** en nuevos servicios
2. ✅ **Usa health checks** para auto-recovery
3. ✅ **Monitorea constantemente** con Grafana
4. ✅ **Documenta cambios** de límites en commits
5. ✅ **Testea límites** en staging antes de producción
6. ✅ **Revisa métricas** semanalmente para ajustes
7. ⚠️ **No sobrecargar VPS** - máximo 80% RAM usage sostenido
8. ⚠️ **Overcommit con cuidado** - conocer patrones de uso

## Referencias

- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)
- [Docker Compose Deploy Spec](https://docs.docker.com/compose/compose-file/deploy/)
- [Best Practices for Resource Limits](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits)

---

**Última actualización**: 2025-10-16
**Responsable**: DevOps Team
**Revisión**: Mensual
