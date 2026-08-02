# 🌐 Inventario de URLs - CodeSpartan Platform

**Última actualización:** 2026-07-26
**VPS principal:** 91.98.137.217 (Hetzner ARM64, `cax11`, 3.4GB RAM)
**VPS secundario:** IP privada `10.0.0.3` / pública `46.224.195.174` (Hetzner x86, `cx33`, tier APIs/BBDD, 7.3GB RAM)
**Dominios:** mambo-cloud.com, cyberdyne-systems.es, codespartan.cloud, dental-ia.es (`codespartan.es` se gestiona aparte en Hostinger/WordPress)

---

## 🔧 Plataforma (Infraestructura)

| Servicio | URL | Autenticación | Contenedor(es) |
|----------|-----|----------------|-----------------|
| Traefik Dashboard | https://traefik.mambo-cloud.com | Authelia SSO + MFA | `traefik` |
| Grafana | https://grafana.mambo-cloud.com | Authelia SSO + MFA | `grafana` |
| Authelia | https://auth.mambo-cloud.com | Login + TOTP | `authelia`, `authelia-redis` |
| Backoffice | https://backoffice.mambo-cloud.com | Authelia SSO + MFA | `backoffice` |
| Portainer | https://portainer.mambo-cloud.com | Authelia SSO + MFA | `portainer` (vía `docker-socket-proxy`) |

Credenciales por defecto: `admin` / `codespartan123` + TOTP vía Authelia (https://auth.mambo-cloud.com).

## 🚀 Aplicaciones

| Aplicación | URL | Estado | Contenedor(es) | Notas |
|-----------|-----|--------|-----------------|-------|
| CodeSpartan WWW | https://www.codespartan.cloud | ✅ Operacional | `codespartan-www` | Next.js SSR, incluye chatbot (OpenAI) |
| CodeSpartan UI | https://ui.codespartan.cloud | ✅ Operacional | `codespartan-ui` | Storybook estático |
| Redmine | https://project.codespartan.cloud | ✅ Operacional | `redmine-app`, `redmine-db` | Reemplaza a OpenProject; PostgreSQL propio |
| Twenty CRM | https://crm.codespartan.cloud | ✅ Operacional | (reenvía a `twenty-server` en el VPS secundario, IP privada `10.0.0.3:3000`) | Corre en `CodeSpartan-apis`, no en el VPS principal — no tenía sitio cómodo aquí junto a Redmine/monitoring/job-hunter. Ver `docs/06-implementation/PIPELINE_COMERCIAL.md` |
| job-hunter (bot) | vía `JOB_HUNTER_API_HOST` (variable propia, no gestionado por Terraform) | ✅ Operacional | `job-hunter-bot` | |
| job-hunter (dashboard) | vía `TRAEFIK_HOSTNAME` propio | ✅ Operacional, protegido por Authelia | `job-hunter-dashboard` | |
| Cyberdyne Systems | https://www.cyberdyne-systems.es (y apex) | ✅ Operacional | (reenvía a `codespartan-frontend` en VPS secundario `10.0.0.3:3080`) | Stack completo en APIs VPS; Traefik file provider |
| Cyberdyne API | https://api.cyberdyne-systems.es | ✅ Operacional | (reenvía a `codespartan-api` en VPS secundario `10.0.0.3:3081`) | NestJS; ya no Supabase/Kong |
| Dental IA | https://www.dental-ia.es | ✅ Operacional | `dental-ia-web` | Sitio estático (nginx) |
| Mambo Cloud | https://www.mambo-cloud.com | ✅ Operacional | `mambo-cloud-app` | Sitio estático (nginx) |
| Staging/Lab (mambo-cloud, cyberdyne, dental-ia) | `staging.*` / `lab.*` / `*-staging.*` | ❌ No desplegado | — | Subdominios reservados en Terraform, sin contenedor activo |

## 🖥️ VPS secundario — Social Posts + Twenty CRM (`CodeSpartan-apis`, IP privada `10.0.0.3`)

| Servicio | Acceso | Contenedor |
|----------|--------|------------|
| Cyberdyne frontend | Solo IP privada `10.0.0.3:3080` → Traefik `www/apex.cyberdyne-systems.es` | `codespartan-frontend` |
| Cyberdyne API (Nest) | Solo IP privada `10.0.0.3:3081` → Traefik `api.cyberdyne-systems.es` | `codespartan-api` |
| Postgres / Redis / MinIO (social posts) | Internos (red `social_internal`) | `codespartan-db`, `codespartan-redis`, `codespartan-minio` |
| Twenty CRM (server) | Solo IP privada `10.0.0.3:3000` → Traefik `crm.codespartan.cloud` | `twenty-server` |
| Twenty CRM (worker, db, redis) | Internos (red `crm_internal`) | `twenty-worker`, `twenty-db`, `twenty-redis` |

**Supabase retirado** de este VPS (2026-07-25).

Patrón: contenedores publican solo en IP privada; Traefik en el VPS principal termina TLS (`codespartan/platform/traefik/dynamic/dynamic-config.yml`). No hay Traefik en este VPS.

## 🔒 Servicios Internos del VPS principal (No Expuestos Públicamente)

| Servicio | Contenedor | Función |
|----------|-----------|---------|
| docker-socket-proxy | `docker-socket-proxy` | Proxy de solo lectura al socket Docker |
| Watchtower | `watchtower` | Auto-actualización de imágenes etiquetadas |
| VictoriaMetrics | `victoriametrics` | Time-series database (puerto 8428, interno) |
| Loki | `loki` | Agregación de logs (puerto 3100, interno), vía Grafana |
| Promtail | `promtail` | Recolector de logs Docker → Loki |
| vmagent | `vmagent` | Recolector de métricas Prometheus |
| vmalert | `vmalert` | Evaluación de reglas de alertas (14 reglas activas) |
| Alertmanager | `alertmanager` | Gestión y routing de alertas |
| ntfy-forwarder | `ntfy-forwarder` | Reenvío de alertas a ntfy.sh (topic `codespartan-mambo-alerts`) |
| cAdvisor | `cadvisor` | Métricas de contenedores Docker |
| Node Exporter | `node-exporter` | Métricas del host |

---

## 🧪 Verificación Rápida

```bash
# Plataforma
curl -I https://traefik.mambo-cloud.com
curl -I https://grafana.mambo-cloud.com
curl -I https://auth.mambo-cloud.com
curl -I https://backoffice.mambo-cloud.com
curl -I https://portainer.mambo-cloud.com

# Aplicaciones
curl -I https://www.codespartan.cloud
curl -I https://ui.codespartan.cloud
curl -I https://project.codespartan.cloud
curl -I https://crm.codespartan.cloud
curl -I https://www.cyberdyne-systems.es
curl -I https://api.cyberdyne-systems.es
curl -I https://www.dental-ia.es
curl -I https://www.mambo-cloud.com
```

```bash
# Contenedores activos en el VPS principal
ssh leonidas@91.98.137.217 "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

---

## 📝 Notas Importantes

- **Credenciales predeterminadas**: `admin` / `codespartan123` + TOTP vía Authelia (protege Traefik, Grafana, Backoffice, Portainer).
- **SSL/TLS**: Let's Encrypt, renovación automática vía Traefik, certificados individuales por subdominio (sin wildcard).
- **DNS**: gestionado con Terraform (`codespartan/infra/hetzner/`) usando `hcloud_zone`/`hcloud_zone_rrset` (el antiguo proveedor `timohirt/hetznerdns` está retirado).
- **job-hunter** y **Redmine** usan hostnames vía variables de entorno propias (`.env` de cada app), no están en la lista `subdomains` de Terraform.
- **Traefik y la configuración dinámica**: hasta el 2026-07-19 se montaba `dynamic-config.yml` como fichero suelto (`--providers.file.filename`), lo que dejó a Traefik sirviendo una versión de 8 días pese a `--providers.file.watch=true` — un bind-mount de un solo fichero se queda apuntando al inodo viejo si el host lo reemplaza (p.ej. por SCP en el workflow de deploy), y el watcher nunca ve el cambio. Arreglado montando el directorio completo (`platform/traefik/dynamic/` → `--providers.file.directory=/etc/traefik/dynamic`), que no tiene ese problema. Si algún día se vuelve a un fichero suelto por lo que sea, verificar tras cada deploy con `docker exec traefik stat /etc/traefik/dynamic/dynamic-config.yml` que el mtime coincide con el del host.

---

## 🔗 Referencias

- **Arquitectura:** `docs/02-architecture/ARCHITECTURE.md`
- **Aislamiento de red:** `docs/02-architecture/NETWORK_ISOLATION_CURRENT.md`
- **Recursos:** `docs/02-architecture/RESOURCES.md`

---

**Última verificación:** 2026-07-20
