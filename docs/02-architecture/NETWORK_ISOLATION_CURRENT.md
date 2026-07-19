# 🔒 Network Isolation - Estado Actual

**Fecha:** 2026-07-13
**Análisis:** Evaluación del aislamiento de red actual (VPS principal, `cax11`)

---

## 📊 Resumen Ejecutivo

| Estado | Aplicaciones | Nivel de Aislamiento |
|--------|--------------|---------------------|
| ✅ **CORRECTO** | Redmine | Base de datos aislada (`redmine_internal`) |
| ✅ **CORRECTO** | Twenty CRM (código listo, pendiente desplegar) | Base de datos + redis aislados (`crm_internal`) |
| ✅ **CORRECTO** | Stack monitoring | Red interna dedicada |
| ✅ **CORRECTO** | Docker proxy | Red API dedicada, Traefik y Portainer solo acceden vía proxy |
| ⚠️ **MEJORABLE** | Frontends estáticos (cyberdyne, codespartan-ui, backoffice) | Solo en red pública, sin datos sensibles propios |

### Veredicto: 🟢 **MAYORMENTE IMPLEMENTADO**

El aislamiento crítico (bases de datos por producto) está correctamente implementado en Redmine y en el código ya preparado de Twenty CRM. Cyberdyne ya no tiene base de datos local (su backend vive en Supabase, en el VPS secundario, fuera del alcance de este documento).

---

## 🗺️ Arquitectura de Red Actual (VPS principal)

```
web (172.20.0.0/16)             - Red pública para Traefik routing
├─ Aplicaciones dual-homed (web + red interna):
│  ├─ authelia                  - authelia_internal + web
│  ├─ redmine-app               - redmine_internal + web
│  ├─ grafana                   - monitoring + web
│  ├─ vmagent                   - monitoring + web
│  ├─ job-hunter-dashboard       - monitoring + web
│  ├─ job-hunter-bot            - monitoring + web
│  ├─ mambo-cloud-app           - mambo_internal + web
│  └─ traefik                   - docker_api + web
│
└─ Aplicaciones solo públicas (sin red interna, sin datos propios):
   ├─ cyberdyne-social-posts    - SOLO web (backend real en Supabase, VPS secundario)
   ├─ codespartan-ui            - SOLO web (Storybook estático)
   ├─ codespartan-www           - SOLO web (Next.js, sin BD propia)
   ├─ dental-io-web             - SOLO web (nginx estático)
   └─ backoffice                - SOLO web (nginx estático)

authelia_internal (172.21.0.0/24, internal: true)
├─ authelia                     - SSO service
└─ authelia-redis               - Session storage (AISLADO ✅)

monitoring (172.24.0.0/24)
├─ victoriametrics              - Metrics storage
├─ vmagent                      - Metrics collector (+ web)
├─ vmalert                      - Alert evaluation
├─ alertmanager                 - Alert routing
├─ grafana                      - Visualization (+ web)
├─ loki                         - Log storage
├─ promtail                     - Log collector
├─ cadvisor                     - Container metrics
├─ node-exporter                - Host metrics
├─ ntfy-forwarder               - Notification forwarder
└─ job-hunter-bot / job-hunter-dashboard (+ web) - exponen métricas propias

docker_api (172.25.0.0/24, internal: true)
├─ docker-socket-proxy          - Filtered Docker socket
├─ traefik                      - Reverse proxy (+ web)
└─ portainer                    - Container management UI (vía proxy, no socket directo)

mambo_internal (172.29.0.0/24)
└─ mambo-cloud-app              - Sitio estático (red interna reservada, sin BD)

dental_internal (172.30.0.0/24)
└─ dental-io-web                - Sitio estático (red interna reservada, sin BD)

redmine_internal (172.31.0.0/24, internal: true)
├─ redmine-app                  - Project management
└─ redmine-db                   - Database, PostgreSQL propio (AISLADO ✅)

crm_internal (172.34.0.0/24, internal: true) — código listo, pendiente de desplegar
├─ twenty-server                - CRM frontend + API (+ web)
├─ twenty-worker                - Jobs en background (BullMQ)
├─ twenty-db                    - Database, PostgreSQL propio (AISLADO ✅)
└─ twenty-redis                 - Cola de jobs (AISLADO ✅)

# api_trackworks - RETIRADA (TrackWorks sustituido por cyberdyne-social-posts + Supabase)
# kong_cyberdyne - RETIRADA (redundante con el Kong propio de Supabase)
# openproject_internal - ELIMINADA (OpenProject reemplazado por Redmine)
```

---

## ✅ Aislamiento Correcto Implementado

### 1. Bases de Datos Aisladas por Producto

**PostgreSQL (Redmine):**
```
✅ redmine-db: SOLO en redmine_internal
❌ NO está en 'web'
✅ Solo accesible por redmine-app
```

**Redis (Authelia):**
```
✅ authelia-redis: SOLO en authelia_internal
❌ NO está en 'web'
✅ Solo accesible por authelia
```

**PostgreSQL + Redis (Twenty CRM, pendiente de desplegar):**
```
✅ twenty-db, twenty-redis: SOLO en crm_internal
❌ NO están en 'web'
✅ Solo accesibles por twenty-server / twenty-worker
```

Cada producto mantiene su propia base de datos dedicada (ver `docs/06-implementation/PIPELINE_COMERCIAL.md`, decisión de no consolidar Postgres entre Redmine y Twenty).

### 2. Stack de Monitoring Aislado

```
✅ Red 'monitoring' dedicada
✅ Servicios internos aislados (VictoriaMetrics, Loki, Alertmanager, vmalert)
✅ Solo grafana, vmagent y las apps que exponen métricas propias están dual-homed
```

### 3. Docker Socket Protegido

```
✅ docker-socket-proxy: SOLO en docker_api
✅ Traefik y Portainer acceden vía proxy (no directo al socket)
✅ Filtrado de operaciones peligrosas (solo lectura)
```

### 4. Cyberdyne ya no tiene base de datos local

```
✅ cyberdyne-social-posts: SOLO en 'web', sin red interna ni BD propia
✅ Su backend real vive en Supabase (VPS secundario, IP privada 10.0.0.3)
✅ El antiguo Kong-cyberdyne (red api_trackworks) fue retirado por redundante
```

---

## ⚠️ Áreas de Mejora (Opcionales)

### Frontends Solo en Red Pública

**codespartan-ui, backoffice:**
- Estado: SOLO en `web`
- Tipo: Frontend/dashboard estático
- Riesgo: Bajo (sin datos sensibles en el contenedor; backoffice protegido por Authelia)
- Recomendación: opcional, no aporta seguridad significativa dado que no manejan datos propios

**Análisis de riesgo:** no es necesario aislar frontends estáticos sin base de datos propia — todas las operaciones sensibles van vía servicios ya aislados (Redmine, Twenty, Supabase).

---

## 🔍 Verificación de Aislamiento

```bash
# MongoDB/Postgres NO accesible desde frontend
docker exec cyberdyne-social-posts nc -zv redmine-db 5432
# Resultado esperado: Connection refused / name not known ✅

# Redis NO accesible desde apps externas
docker exec codespartan-ui nc -zv authelia-redis 6379
# Resultado esperado: Name or service not known ✅

# Docker socket NO accesible directamente desde Traefik
docker exec traefik ls /var/run/docker.sock
# Resultado: No such file or directory ✅
```

---

## 📋 Subnets Asignadas (VPS principal)

| Subnet | Red | Estado |
|--------|-----|--------|
| `172.20.0.0/16` | `web` | Activa |
| `172.21.0.0/24` | `authelia_internal` | Activa, `internal: true` |
| `172.22.0.0/24` | `api_trackworks` | Retirada |
| `172.24.0.0/24` | `monitoring` | Activa |
| `172.25.0.0/24` | `docker_api` | Activa, `internal: true` |
| `172.26.0.0/24` | `kong_cyberdyne` | Retirada |
| `172.27.0.0/24` | `kong_dental` | Reservada (futuro) |
| `172.28.0.0/24` | `kong_mambo` | Reservada (futuro) |
| `172.29.0.0/24` | `mambo_internal` | Activa |
| `172.30.0.0/24` | `dental_internal` | Activa |
| `172.31.0.0/24` | `redmine_internal` | Activa, `internal: true` |
| `172.34.0.0/24` | `crm_internal` | Código listo, pendiente de desplegar, `internal: true` |

El VPS secundario (`CodeSpartan-apis`, Supabase) usa su propio rango de subredes, gestionado en `platform/supabase/`, fuera de este esquema `172.x`.

---

## 🎯 Recomendaciones

### Prioridad Alta: ✅ COMPLETADO

- [x] Aislar bases de datos de la red pública (Redmine, Twenty CRM)
- [x] Crear redes internas dedicadas por producto con `internal: true`
- [x] Proteger Docker socket con proxy
- [x] Retirar Kong-cyberdyne (redundante con Supabase)

### Prioridad Media: 🔄 OPCIONAL

- [ ] Desplegar Kong para dental-io y mambo-cloud (plantilla en `platform/kong/_TEMPLATE/`)

### Prioridad Baja: ⏸️ NO NECESARIO

- [ ] Crear redes internas para frontends estáticos sin BD propia — no aporta seguridad significativa

---

## 📊 Métricas de Seguridad

| Métrica | Valor | Estado |
|---------|-------|--------|
| **Bases de datos aisladas** | 2/2 activas + 1 lista para desplegar (100%) | ✅ Excelente |
| **Subnets explícitas** | 10/10 redes activas | ✅ Completo |
| **Internal flag activo** | En todas las redes con datos sensibles | ✅ Completo |

### Puntuación Global: 🟢 **9/10**

**Conclusión:** el aislamiento de red crítico está correctamente implementado y se mantiene como estándar para cada nuevo producto (Redmine, y ahora Twenty CRM). Las mejoras restantes (Kong para dental-io/mambo-cloud) son parte del roadmap de seguridad, no vulnerabilidades activas.

---

## 📚 Referencias

- **CLAUDE.md:** sección "Docker Networks" / "Reserved subnets"
- **Template:** `codespartan/apps/_TEMPLATE/NETWORK_ISOLATION.md`
- **Plan Twenty CRM:** `docs/06-implementation/PIPELINE_COMERCIAL.md`
- **Docker Networks:** https://docs.docker.com/network/
