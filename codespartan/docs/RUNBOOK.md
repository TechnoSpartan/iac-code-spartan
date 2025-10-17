# RUNBOOK - CodeSpartan Mambo Cloud Platform

## 📋 Índice
1. [Descripción General](#descripción-general)
2. [Arquitectura](#arquitectura)
3. [Pre-requisitos](#pre-requisitos)
4. [Configuración Inicial](#configuración-inicial)
5. [Despliegue por Pasos](#despliegue-por-pasos)
6. [Gestión de Dominios](#gestión-de-dominios)
7. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
8. [Operaciones Rutinarias](#operaciones-rutinarias)
9. [Troubleshooting](#troubleshooting)
10. [Backups y Recuperación](#backups-y-recuperación)

## 🎯 Descripción General

La plataforma CodeSpartan Mambo Cloud es una infraestructura como código (IaC) completamente containerizada que proporciona:

- **VPS Hetzner ARM64** con Terraform
- **Traefik** como reverse proxy con SSL automático
- **Stack de monitoreo** (VictoriaMetrics + Grafana + Loki + Promtail)
- **Aplicaciones web** desplegadas automáticamente
- **CI/CD completo** con GitHub Actions

### Dominios Gestionados
- `mambo-cloud.com` - Dominio principal (DNS en Hetzner)
- `codespartan.es` - WordPress en Hostinger (no gestionado aquí)

### Subdominios Activos
- `traefik.mambo-cloud.com` - Dashboard de Traefik
- `grafana.mambo-cloud.com` - Dashboard de monitoreo
- `backoffice.mambo-cloud.com` - Panel de control
- `www.mambo-cloud.com` - Aplicación principal
- `staging.mambo-cloud.com` - Entorno de pruebas
- `lab.mambo-cloud.com` - Entorno de desarrollo

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions  │───▶│  Hetzner VPS    │
│                 │    │                  │    │                 │
│ - Terraform     │    │ - Deploy Infra   │    │ - Docker        │
│ - Docker Apps   │    │ - Deploy Apps    │    │ - Traefik       │
│ - Configs       │    │ - Deploy Stacks  │    │ - Monitoring    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                          │
                                               ┌─────────────────┐
                                               │  Hetzner DNS    │
                                               │                 │
                                               │ mambo-cloud.com │
                                               │ A/AAAA records │
                                               └─────────────────┘
```

## ✅ Pre-requisitos

### Cuentas y Tokens
- [ ] Cuenta Hetzner Cloud
- [ ] Token API Hetzner Cloud
- [ ] Token API Hetzner DNS
- [ ] Repositorio GitHub
- [ ] Dominio `mambo-cloud.com` configurado en Hetzner DNS

### Herramientas Locales
- [ ] Git
- [ ] Terraform >= 1.9.0
- [ ] SSH Key generada (`~/.ssh/id_ed25519`)
- [ ] Docker (opcional, para pruebas locales)

### Variables del VPS
- **IPv4**: `91.98.137.217`
- **IPv6**: `2a01:4f8:1c1a:7d21::1`
- **Arquitectura**: ARM64 (cax11)
- **Región**: Nuremberg (nbg1)

## 🔧 Configuración Inicial

### 1. Configurar Secrets en GitHub

Ir a tu repositorio GitHub → Settings → Secrets and variables → Actions:

```bash
# Secrets requeridos
HCLOUD_TOKEN=tu_token_hetzner_cloud
HETZNER_DNS_TOKEN=tu_token_hetzner_dns
VPS_SSH_HOST=91.98.137.217
VPS_SSH_USER=leonidas
VPS_SSH_KEY=tu_clave_privada_ssh_completa
```

### 2. Configurar SSH Key

```bash
# Generar clave SSH (si no existe)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "codespartan@mambo-cloud.com"

# La clave pública se usa en Terraform
# La clave privada va en VPS_SSH_KEY (GitHub Secrets)
```

### 3. Verificar Configuración DNS

El dominio `mambo-cloud.com` debe tener sus nameservers apuntando a Hetzner:
```
helium.ns.hetzner.de
hydrogen.ns.hetzner.de
oxygen.ns.hetzner.de
```

## 🚀 Despliegue por Pasos

### Paso 1: Provisionar Infraestructura

```bash
# Opción A: GitHub Actions (Recomendado)
# Ir a Actions → Deploy Infrastructure (Terraform) → Run workflow

# Opción B: Local
cd codespartan/infra/hetzner
export HCLOUD_TOKEN="tu_token"
export TF_VAR_hetzner_dns_token="tu_token_dns"
terraform init
terraform plan
terraform apply
```

**Resultado esperado:**
- VPS creado en Hetzner
- Registros DNS A/AAAA creados para subdominios
- Docker instalado automáticamente
- Red `web` creada

### Paso 2: Desplegar Traefik (Reverse Proxy)

```bash
# GitHub Actions → Deploy Traefik → Run workflow
```

**Verificar:**
```bash
# SSH al VPS
ssh root@91.98.137.217
docker ps | grep traefik
curl -k https://traefik.mambo-cloud.com
```

### Paso 3: Desplegar Stack de Monitoreo

```bash
# GitHub Actions → Deploy Monitoring Stack → Run workflow
```

**Verificar:**
```bash
ssh leonidas@91.98.137.217
docker ps | grep -E "victoriametrics|vmagent|loki|promtail|grafana|cadvisor|node-exporter"
curl -k https://grafana.mambo-cloud.com
```

### Paso 4: Desplegar Backoffice

```bash
# GitHub Actions → Deploy Backoffice → Run workflow
```

### Paso 5: Desplegar Aplicación Principal

```bash
# GitHub Actions → Deploy Mambo Cloud App → Run workflow
```

### Paso 6: Verificación Completa

Acceder a cada servicio:
- https://traefik.mambo-cloud.com (admin/codespartan123)
- https://grafana.mambo-cloud.com (admin/codespartan123)
- https://backoffice.mambo-cloud.com (admin/codespartan123)
- https://www.mambo-cloud.com
- https://staging.mambo-cloud.com
- https://lab.mambo-cloud.com

## 🌐 Gestión de Dominios

### Agregar Nuevo Dominio

1. **Actualizar Terraform:**
```hcl
# En terraform.tfvars
domains = ["mambo-cloud.com", "nuevo-dominio.com"]
```

2. **Configurar NS del dominio:**
Apuntar a nameservers de Hetzner

3. **Aplicar cambios:**
```bash
terraform plan
terraform apply
```

### Agregar Subdominios

1. **Editar terraform.tfvars:**
```hcl
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "nuevo-sub"]
```

2. **Configurar Traefik labels** en el docker-compose correspondiente

## 📊 Monitoreo y Observabilidad

### Grafana
- **URL**: https://grafana.mambo-cloud.com
- **Usuario**: admin
- **Password**: codespartan123
- **Datasources**: VictoriaMetrics, Loki

### Dashboards Preconfigurados
- **Infraestructura**: Métricas del VPS (CPU, RAM, Disk)
- **Traefik**: Request rate, response times, SSL certs
- **Docker**: Contenedores, imágenes, volúmenes
- **Logs**: Centralizados con Loki

### Dashboards Sugeridos
- **System Overview**: CPU, RAM, Disk total del VPS
- **Container Resources**: Recursos por contenedor
- **Traefik**: Request rate, response times, SSL status
- **Logs Explorer**: Búsqueda de logs en Loki

## 🚨 Sistema de Alertas

El sistema de alertas envía notificaciones proactivas cuando se detectan problemas.

### Arquitectura de Alertas

```
vmalert → Alertmanager → ntfy-forwarder → ntfy.sh → Tu móvil/web
```

### Recibir Notificaciones

**App Móvil (Recomendado):**
1. Instalar "ntfy" desde Play Store o App Store
2. Suscribirse al topic: `codespartan-mambo-alerts`
3. Activar notificaciones push

**Browser Web:**
- Visitar: https://ntfy.sh/codespartan-mambo-alerts

**Línea de comandos:**
```bash
curl -s ntfy.sh/codespartan-mambo-alerts/json
```

### Alertas Configuradas

| Categoría | Alerta | Condición | Severidad |
|-----------|--------|-----------|-----------|
| CPU | HighCPUUsage | > 80% por 5min | warning |
| CPU | CriticalCPUUsage | > 95% por 2min | critical |
| Memoria | HighMemoryUsage | > 90% por 3min | warning |
| Memoria | CriticalMemoryUsage | > 95% por 1min | critical |
| Disco | HighDiskUsage | > 85% por 5min | warning |
| Disco | CriticalDiskUsage | > 95% por 2min | critical |
| Servicios | ServiceDown | Servicio caído > 2min | critical |
| Contenedores | ContainerDown | Contenedor no visto > 2min | critical |
| VictoriaMetrics | HighMemory | > 1.5GB RAM | warning |
| Traefik | HighHTTP5xxRate | > 10 errores/s | warning |
| Traefik | CriticalHTTP5xxRate | > 50 errores/s | critical |

### Gestión de Alertas

```bash
# Ver alertas activas
ssh leonidas@91.98.137.217
curl http://localhost:8880/api/v1/rules | jq '.data.groups[].rules[] | select(.state=="firing")'

# Ver estado de Alertmanager
curl http://localhost:9093/api/v2/alerts | jq '.'

# Silenciar alerta por 1 hora (mantenimiento)
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "HighCPUUsage", "isRegex": false}],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
    "createdBy": "admin",
    "comment": "Ventana de mantenimiento"
  }'

# Ver silenciamientos activos
curl http://localhost:9093/api/v2/silences | jq '.[] | select(.status.state=="active")'
```

### Severidades de Alertas

- **critical**: Notificación inmediata, repite cada 1 hora, prioridad máxima (5)
- **warning**: Agrupa por 30s, repite cada 12 horas, prioridad 4
- **info**: Agrupa por 30s, repite cada 24 horas, prioridad 3

**Documentación completa**: Ver `codespartan/docs/ALERTS.md`

## 🔄 Operaciones Rutinarias

### Verificación de Recursos

```bash
# Verificar uso de recursos en tiempo real
ssh leonidas@91.98.137.217
docker stats --no-stream

# Verificar límites aplicados
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'

# Contenedores que más recursos consumen
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | sort -k2 -h

# Verificar salud de contenedores
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

### Actualizaciones

```bash
# Actualizar aplicación
git push origin main  # Activa GitHub Actions automáticamente

# Actualizar stack manualmente
ssh leonidas@91.98.137.217
cd /opt/codespartan/platform/stacks/monitoring
docker compose pull
docker compose up -d

# IMPORTANTE: Al actualizar docker-compose.yml con nuevos resource limits
# Debes RECREAR los contenedores para aplicar los límites
cd /opt/codespartan/apps/[app-name]
docker compose down
docker compose up -d
```

### Logs

```bash
# Ver logs de contenedor
ssh leonidas@91.98.137.217
docker logs traefik -f
docker logs grafana --tail 100

# Logs centralizados en Grafana
# Ir a Grafana → Explore → Loki datasource
```

### Backup de Configuración

```bash
# Backup automático de configuraciones
ssh root@91.98.137.217
tar -czf backup-$(date +%Y%m%d).tar.gz /opt/codespartan
scp root@91.98.137.217:backup-*.tar.gz ./
```

## 🚨 Troubleshooting

### Problema: Servicio no accesible
```bash
# 1. Verificar contenedor
docker ps | grep nombre_servicio

# 2. Verificar logs
docker logs nombre_servicio

# 3. Verificar red
docker network ls | grep web
docker network inspect web

# 4. Verificar Traefik
curl -H "Host: tu-dominio.com" http://localhost:80
```

### Problema: SSL no funciona
```bash
# Verificar certificados en Traefik
docker exec traefik ls -la /letsencrypt/

# Regenerar certificados
docker exec traefik rm /letsencrypt/acme.json
docker restart traefik
```

### Problema: DNS no resuelve
```bash
# Verificar registros DNS
dig mambo-cloud.com
dig traefik.mambo-cloud.com

# Verificar en Hetzner Console
# Cloud → DNS → mambo-cloud.com
```

### Problema: Contenedor consume demasiados recursos
```bash
# Identificar contenedor problemático
docker stats --no-stream | sort -k4 -h

# Ver límites configurados
docker inspect [container-name] | grep -A 10 "Memory"

# Aplicar límites (editar docker-compose.yml primero)
cd /opt/codespartan/[path-to-service]
# Agregar deploy.resources.limits en docker-compose.yml
docker compose down
docker compose up -d

# Verificar límites aplicados
docker stats --no-stream | grep [container-name]
```

### Problema: OOM (Out of Memory) Errors
```bash
# Verificar logs del sistema
dmesg | grep -i "out of memory"
dmesg | grep -i "oom"

# Verificar qué contenedor fue matado
docker events --filter 'event=oom' --since 1h

# Solución: Incrementar límites en docker-compose.yml
# O reducir carga/optimizar aplicación
```

### Problema: Alerta ServiceDown repetitiva para cadvisor
```bash
# Síntoma
# Alerta "ServiceDown" para cadvisor cada hora en Discord/ntfy.sh

# Diagnóstico
docker logs vmagent | grep cadvisor
# Buscar: "exceeds -promscrape.maxScrapeSize=16777216"

# Verificar tamaño de métricas
docker exec cadvisor wget -O- http://localhost:8080/metrics 2>/dev/null | wc -c

# Solución ya aplicada en docker-compose.yml
# cadvisor está configurado con filtros para reducir métricas:
#   --docker_only=true
#   --disable_metrics=disk,diskIO,tcp,udp,process,...
#   --store_container_labels=false

# Si el problema persiste, verificar que cadvisor use la config correcta
docker inspect cadvisor | jq '.[0].Args'

# Recrear contenedor si es necesario
cd /opt/codespartan/platform/stacks/monitoring
docker compose up -d cadvisor --force-recreate
```

## 💾 Backups y Recuperación

### Datos Críticos a Respaldar
- `/opt/codespartan/` - Toda la configuración
- Volúmenes Docker (Grafana, VictoriaMetrics, Loki)
- Certificados SSL (`/opt/codespartan/platform/traefik/letsencrypt/`)

### Recuperación de Desastre
1. Recrear VPS con Terraform
2. Restaurar configuraciones desde backup
3. Re-desplegar servicios con GitHub Actions
4. Verificar funcionamiento

### Scripts de Backup Automático
```bash
#!/bin/bash
# /opt/backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf /tmp/codespartan-backup-$DATE.tar.gz /opt/codespartan
# Subir a S3/otro storage
```

## 📚 Referencias y Documentación

- [Hetzner Cloud API](https://docs.hetzner.cloud/)
- [Traefik Documentation](https://doc.traefik.io/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Terraform Hetzner Provider](https://registry.terraform.io/providers/hetznercloud/hcloud/)

---

**Contacto**: infra@mambo-cloud.com  
**Repositorio**: https://github.com/CodeSpartan/iac-core-hetzner  
**Última actualización**: $(date)
