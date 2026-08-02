# Resource Management - CodeSpartan Platform

## Información de los VPS

### VPS principal (`CodeSpartan-alma`)

- **Proveedor**: Hetzner Cloud
- **Tipo**: cax11 (ARM64)
- **CPU**: 2 vCPU cores (ARM64)
- **RAM**: 4 GB (3.4 GB utilizables)
- **Disco**: 40 GB SSD
- **Región**: Nuremberg (nbg1)
- **IP**: 91.98.137.217
- **Rol**: Traefik, apps públicas, monitoring, Authelia, Redmine, job-hunter

### VPS secundario (`CodeSpartan-apis`)

- **Proveedor**: Hetzner Cloud
- **Tipo**: cx33 (x86, confirmado 4 vCPU / 8 GB)
- **Región**: Nuremberg (nbg1)
- **IP privada**: `10.0.0.3` (red privada `codespartan-internal`, `10.0.0.0/24`)
- **Rol**: tier de APIs/BBDD, actualmente Supabase self-hosted. Su Kong solo escucha en la IP privada; Traefik del VPS principal hace de terminador TLS y reenvía tráfico público (`api.cyberdyne-systems.es`) hacia él.

## Filosofía de Resource Limits

Todos los contenedores en la plataforma tienen límites de recursos configurados para:

1. **Prevenir agotamiento de recursos**: Un contenedor defectuoso no puede consumir toda la RAM del sistema
2. **Garantizar estabilidad**: El sistema operativo siempre tiene recursos disponibles
3. **Facilitar troubleshooting**: Identificar rápidamente contenedores problemáticos
4. **Habilitar auto-recuperación**: Docker puede reiniciar contenedores que exceden límites

## Resource Allocation Breakdown — VPS principal (cax11)

> Los límites de esta tabla están tomados directamente de los `docker-compose.yml` de cada servicio (verificable en el repo). El uso real de RAM varía y debe comprobarse con `docker stats` en el VPS — no se incluyen aquí cifras de uso real para evitar datos obsoletos.

### Platform Services (Infraestructura)

| Servicio | Contenedor | RAM Limit | CPU Limit | Propósito |
|----------|-----------|-----------|-----------|-----------|
| Traefik | `traefik` | 512 MB | 0.5 | Reverse proxy + SSL |
| Authelia | `authelia` | 256 MB | 0.5 | SSO + MFA |
| Authelia Redis | `authelia-redis` | 128 MB | 0.25 | Sesiones de Authelia |
| docker-socket-proxy | `docker-socket-proxy` | 128 MB | 0.15 | Proxy de solo lectura al socket Docker |
| Portainer | `portainer` | 512 MB | 0.5 | UI de gestión de contenedores |
| Watchtower | `watchtower` | 128 MB | 0.25 | Auto-actualización de imágenes etiquetadas |
| Backoffice | `backoffice` | 128 MB | 0.25 | Panel de gestión (nginx estático) |
| VictoriaMetrics | `victoriametrics` | 1 GB | 1.0 | Time-series database |
| Grafana | `grafana` | 512 MB | 0.5 | Dashboards y visualización |
| Loki | `loki` | 512 MB | 0.5 | Log aggregation |
| vmagent | `vmagent` | 256 MB | 0.25 | Metrics collection |
| Promtail | `promtail` | 256 MB | 0.25 | Log shipping |
| cAdvisor | `cadvisor` | 256 MB | 0.25 | Container metrics |
| vmalert | `vmalert` | 128 MB | 0.15 | Alerting engine |
| Alertmanager | `alertmanager` | 128 MB | 0.15 | Alert routing & grouping |
| ntfy-forwarder | `ntfy-forwarder` | 64 MB | 0.1 | Webhook → ntfy.sh converter |
| Node Exporter | `node-exporter` | 128 MB | 0.1 | System metrics |

**Subtotal Platform**: ~4.94 GB límite (16 contenedores)

### Application Services

| Aplicación | Contenedor | RAM Limit | CPU Limit | Descripción |
|-----------|-----------|-----------|-----------|-------------|
| job-hunter bot | `job-hunter-bot` | 1 GB | 1.0 | Bot backend |
| job-hunter dashboard | `job-hunter-dashboard` | 512 MB | 0.75 | Dashboard del bot, protegido por Authelia |
| Redmine app | `redmine-app` | 512 MB | 0.5 | Gestión de proyectos (reemplaza OpenProject) |
| Redmine DB | `redmine-db` | 256 MB | 0.5 | PostgreSQL 17 dedicado a Redmine |
| CodeSpartan UI | `codespartan-ui` | 256 MB | 0.5 | Storybook estático |
| CodeSpartan WWW | `codespartan-www` | 512 MB | 0.5 | Web corporativa Next.js (SSR) |
| Cyberdyne social posts | `cyberdyne-social-posts` | 128 MB | 0.25 | App de publicación de posts con IA (reemplaza TrackWorks), backend en Supabase |
| Dental IA | `dental-ia-web` | 512 MB | 0.5 | Next.js SSR (DentalFlow) |
| Mambo Cloud | `mambo-cloud-app` | 128 MB | 0.25 | Sitio estático (nginx) |

**Subtotal Applications**: ~3.4 GB límite (9 contenedores)

### Totales VPS principal

- **RAM Total Límites**: ~8.3 GB (excede intencionadamente la RAM física de 3.4 GB — overcommitment)
- **Contenedores Totales**: 25 (16 platform + 9 applications)
- **RAM real de uso**: comprobar con `ssh leonidas@91.98.137.217 "docker stats --no-stream"` — no incluida aquí para no quedar desactualizada

> **Nota**: La suma de límites excede la RAM física porque los contenedores rara vez usan su límite máximo simultáneamente ("overcommitment"), práctica estándar y ya validada en este VPS durante meses de operación.

## Resource Allocation Breakdown — VPS secundario (cx33, Supabase self-hosted)

| Servicio | Contenedor | RAM Limit | Descripción |
|----------|-----------|-----------|-------------|
| Studio | `supabase-studio` | 512 MB | UI de administración |
| Kong | `supabase-kong` | 512 MB | API Gateway propio de Supabase (solo IP privada) |
| Auth (GoTrue) | `supabase-auth` | 256 MB | Autenticación |
| PostgREST | `supabase-rest` | 256 MB | API REST sobre Postgres |
| Realtime | `realtime-dev.supabase-realtime` | 512 MB | Suscripciones en tiempo real |
| Storage | `supabase-storage` | 256 MB | Almacenamiento de ficheros |
| imgproxy | `supabase-imgproxy` | 512 MB | Procesado de imágenes |
| Meta | `supabase-meta` | 256 MB | Metadatos de Postgres |
| Edge Functions | `supabase-edge-functions` | 512 MB | Funciones serverless |
| Postgres | `supabase-db` | 1 GB | Base de datos principal |
| Supavisor | `supabase-pooler` | 256 MB | Connection pooler |

**Subtotal Supabase**: ~4.75 GB límite sobre un VPS de 8 GB (11 contenedores) — sin overcommitment significativo, margen amplio.

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
# VPS principal
ssh leonidas@91.98.137.217 "docker stats --no-stream"
ssh leonidas@91.98.137.217 "docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | sort -k2 -h"

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

## Guidelines por Tipo de Servicio

### Databases (PostgreSQL, Supabase Postgres)
- **RAM**: 256 MB - 1 GB
- **CPU**: 0.5 - 1.0
- **Razón**: Necesitan cachear datos en memoria para buen rendimiento

### APIs/Backend (Node.js, Python, Go)
- **RAM**: 512 MB - 1 GB
- **CPU**: 0.5 - 1.0
- **Razón**: Procesan lógica de negocio, necesitan recursos moderados

### Frontend/SPA (React, Next.js)
- **RAM**: 256 MB - 512 MB
- **CPU**: 0.5
- **Razón**: Build artifacts pueden ser grandes, SSR consume recursos

### Static Sites (Nginx)
- **RAM**: 128 MB
- **CPU**: 0.25
- **Razón**: Solo sirven archivos estáticos, muy livianos

### Reverse Proxy/Load Balancer (Traefik)
- **RAM**: 512 MB
- **CPU**: 0.5
- **Razón**: Manejan todo el tráfico entrante

### Monitoring (Grafana, Loki, VictoriaMetrics)
- **RAM**: 512 MB - 1 GB
- **CPU**: 0.5 - 1.0
- **Razón**: Almacenan y consultan grandes volúmenes de métricas/logs

### Collectors (vmagent, Promtail, cAdvisor)
- **RAM**: 256 MB
- **CPU**: 0.25
- **Razón**: Recolectan y envían datos, uso moderado

### Exporters (node-exporter)
- **RAM**: 128 MB
- **CPU**: 0.1
- **Razón**: Exponen métricas simples, muy livianos

### Alert Systems (Alertmanager, ntfy-forwarder)
- **RAM**: 64 - 128 MB
- **CPU**: 0.1 - 0.15
- **Razón**: Procesan y enrutan alertas, bajo overhead

## Troubleshooting

### Contenedor alcanza límite de memoria

```bash
docker logs [container] | grep -i "out of memory"
docker events --filter 'event=oom' --since 1h

# Solución 1: Incrementar límite
# Editar docker-compose.yml → aumentar memory limit
docker compose down && docker compose up -d
```

### Contenedor alcanza límite de CPU

```bash
docker stats --no-stream | grep [container]
# Si CPU% está constantemente cerca de 100% del límite → incrementar límite o escalar
```

### Sistema completo sin memoria

```bash
free -h
docker system df
docker system prune -a --volumes
docker stats --no-stream | sort -k4 -h
```

## Monitoreo Continuo

### Grafana Dashboards

1. **System Overview**: CPU total, RAM total usada/disponible, disco, network I/O
2. **Container Resources**: CPU/memoria por contenedor, top 10 por uso
3. **Health Status**: contenedores healthy/unhealthy, reintentos, uptime

### Alertas Configuradas

- CPU > 80% por 5 minutos
- RAM > 90% por 3 minutos
- Disk > 85%
- Contenedor unhealthy > 2 minutos
- Contenedor reiniciado > 3 veces en 10 minutos

## Best Practices

1. ✅ Siempre define resource limits en nuevos servicios
2. ✅ Usa health checks para auto-recovery
3. ✅ Monitorea constantemente con Grafana
4. ✅ Documenta cambios de límites en commits
5. ✅ Testea límites en staging antes de producción
6. ⚠️ No sobrecargar VPS — máximo 80% RAM usage sostenido
7. ⚠️ Overcommit con cuidado — conocer patrones de uso real (`docker stats`)

## Referencias

- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)
- [Docker Compose Deploy Spec](https://docs.docker.com/compose/compose-file/deploy/)

---

**Última actualización**: 2026-07-13
**Responsable**: DevOps Team
**Revisión**: Mensual
