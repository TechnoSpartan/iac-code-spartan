# 🌐 Inventario de URLs - CodeSpartan Platform

**Última actualización:** 2026-07-13
**VPS principal:** 91.98.137.217 (Hetzner ARM64, `cax11`)
**VPS secundario:** IP privada `10.0.0.3` (Hetzner x86, `cx33`, tier APIs/BBDD)
**Dominios:** mambo-cloud.com, cyberdyne-systems.es, codespartan.cloud, dental-io.com (`codespartan.es` se gestiona aparte en Hostinger/WordPress)

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
| Twenty CRM | https://crm.codespartan.cloud | 🔄 Código listo, pendiente de desplegar | `twenty-server`, `twenty-worker`, `twenty-db`, `twenty-redis` | Ver `docs/06-implementation/PIPELINE_COMERCIAL.md` |
| job-hunter (bot) | vía `JOB_HUNTER_API_HOST` (variable propia, no gestionado por Terraform) | ✅ Operacional | `job-hunter-bot` | |
| job-hunter (dashboard) | vía `TRAEFIK_HOSTNAME` propio | ✅ Operacional, protegido por Authelia | `job-hunter-dashboard` | |
| Cyberdyne Systems | https://www.cyberdyne-systems.es | ✅ Operacional | `cyberdyne-social-posts` | Reemplaza a TrackWorks (app de publicación de posts con IA); backend en Supabase |
| Cyberdyne API | https://api.cyberdyne-systems.es | ✅ Operacional | (reenvía a `supabase-kong` en el VPS secundario, IP privada `10.0.0.3:8000`) | Ya no hay Kong local para Cyberdyne — retirado, redundante con el Kong propio de Supabase |
| Dental IO | https://www.dental-io.com | ✅ Operacional | `dental-io-web` | Sitio estático (nginx) |
| Mambo Cloud | https://www.mambo-cloud.com | ✅ Operacional | `mambo-cloud-app` | Sitio estático (nginx) |
| Staging/Lab (mambo-cloud, cyberdyne, dental-io) | `staging.*` / `lab.*` / `*-staging.*` | ❌ No desplegado | — | Subdominios reservados en Terraform, sin contenedor activo |

## 🖥️ VPS secundario — Supabase self-hosted (`CodeSpartan-apis`, IP privada `10.0.0.3`)

| Servicio | Acceso | Contenedor |
|----------|--------|------------|
| Kong (API Gateway propio de Supabase) | Solo IP privada `10.0.0.3:8000`, expuesto públicamente vía Traefik → `api.cyberdyne-systems.es` | `supabase-kong` |
| Studio | Interno (no expuesto públicamente) | `supabase-studio` |
| Auth, REST, Realtime, Storage, imgproxy, Meta, Edge Functions, Postgres, Supavisor | Internos, solo accesibles entre sí y vía Kong | `supabase-auth`, `supabase-rest`, `realtime-dev.supabase-realtime`, `supabase-storage`, `supabase-imgproxy`, `supabase-meta`, `supabase-edge-functions`, `supabase-db`, `supabase-pooler` |

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
curl -I https://www.cyberdyne-systems.es
curl -I https://api.cyberdyne-systems.es
curl -I https://www.dental-io.com
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

---

## 🔗 Referencias

- **Arquitectura:** `docs/02-architecture/ARCHITECTURE.md`
- **Aislamiento de red:** `docs/02-architecture/NETWORK_ISOLATION_CURRENT.md`
- **Recursos:** `docs/02-architecture/RESOURCES.md`

---

**Última verificación:** 2026-07-13
