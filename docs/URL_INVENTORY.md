# 🌐 Inventario de URLs - CodeSpartan Mambo Cloud Platform

**Última actualización:** 2025-12-13
**VPS:** 91.98.137.217 (Hetzner ARM64)
**Dominios principales:** mambo-cloud.com, cyberdyne-systems.es, codespartan.cloud

---

## 📊 Resumen

| Categoría                | Cantidad        | Estado                     |
| ------------------------ | --------------- | -------------------------- |
| **Plataforma**           | 6 URLs          | ✅ Operacionales            |
| **Aplicaciones**         | 8 URLs          | ⚠️ Parcialmente desplegadas |
| **Total URLs**           | 14 URLs         | -                          |
| **Contenedores activos** | 21 contenedores | ✅ Running                  |

---

## 🔧 Plataforma (Infraestructura)

### Traefik - Reverse Proxy

- **URL:** <https://traefik.mambo-cloud.com>
- **Servicio:** Dashboard de Traefik
- **Credenciales:** admin / codespartan123
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `traefik`

### Grafana - Observabilidad

- **URL:** <https://grafana.mambo-cloud.com>
- **Servicio:** Dashboards de métricas y logs
- **Credenciales:** admin / codespartan123
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `grafana`
- **Datasources:**
  - VictoriaMetrics (métricas)
  - Loki (logs)
- **Dashboards:** 5 importados

### Authelia - SSO (Single Sign-On)

- **URL:** <https://auth.mambo-cloud.com>
- **Servicio:** Portal de autenticación con MFA
- **Credenciales:** admin / codespartan123
- **Estado:** ✅ OPERACIONAL
- **Contenedores:** `authelia`, `authelia-redis`
- **Funcionalidades:**
  - ✅ Login
  - ✅ 2FA (TOTP)
  - ✅ API Health: <https://auth.mambo-cloud.com/api/health>

### Backoffice - Panel de Gestión

- **URL:** <https://backoffice.mambo-cloud.com>
- **Servicio:** Panel de administración
- **Credenciales:** admin / codespartan123
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `backoffice`

### VictoriaMetrics - Métricas

- **URL:** <http://91.98.137.217:8428> (No expuesto públicamente)
- **Servicio:** Time-series database para métricas
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `victoriametrics`
- **UI interna:** <http://localhost:8428/vmui>

### Alertmanager - Gestión de Alertas

- **URL:** <http://91.98.137.217:9093> (No expuesto públicamente)
- **Servicio:** Gestión y routing de alertas
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `alertmanager`

---

## 🚀 Aplicaciones Desplegadas

### TruckWorks API (Cyberdyne Systems)

- **URL:** <https://api.cyberdyne-systems.es/api/v1/health>
- **Servicio:** Backend API REST para TruckWorks
- **Estado:** ✅ OPERACIONAL
- **Contenedores:** `trackworks-api`, `trackworks-mongodb`
- **Base de datos:** MongoDB 8.0
- **Endpoints:**
  - Health: <https://api.cyberdyne-systems.es/api/v1/health>
  - API Base: <https://api.cyberdyne-systems.es/api/v1/>

### Cyberdyne Systems - Frontend (Producción)

- **URL:** <https://www.cyberdyne-systems.es>
- **URL alternativa:** <https://cyberdyne-systems.es>
- **Servicio:** Frontend de TruckWorks (React/Next.js)
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `cyberdyne-frontend-web`

### Cyberdyne Systems - Staging

- **URL:** <https://staging.cyberdyne-systems.es>
- **Servicio:** Frontend staging para pruebas
- **Estado:** ❌ NO DESPLEGADO
- **Notas:** Configuración existe, contenedor no activo

### Cyberdyne Systems - Lab

- **URL:** <https://lab.cyberdyne-systems.es>
- **Servicio:** Ambiente de desarrollo/experimentación
- **Estado:** ❌ NO DESPLEGADO
- **Notas:** Configuración existe, contenedor no activo

### TruckWorks API Staging

- **URL:** <https://api-staging.cyberdyne-systems.es>
- **Servicio:** Backend staging para pruebas
- **Estado:** ❌ NO DESPLEGADO
- **Notas:** Configuración existe, contenedor no activo

### CodeSpartan UI

- **URL:** <https://ui.codespartan.cloud>
- **Servicio:** Dashboard de CodeSpartan
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `codespartan-ui`

### CodeSpartan WWW

- **URL:** <https://www.codespartan.cloud>
- **Servicio:** Sitio web corporativo CodeSpartan
- **Estado:** ⚠️ CONFIGURADO (verificar estado)
- **Notas:** Configuración existe, verificar contenedor

### Mambo Cloud WWW

- **URL:** <https://www.mambo-cloud.com>
- **Servicio:** Landing page Mambo Cloud
- **Estado:** ⚠️ CONFIGURADO (verificar estado)
- **Notas:** Configuración existe, verificar contenedor

### Redmine - Project Management

- **URL:** <https://redmine.codespartan.cloud> (estimada)
- **Servicio:** Gestión de proyectos
- **Estado:** ✅ CONTENEDORES ACTIVOS
- **Contenedores:** `redmine-app`, `redmine-db`
- **Notas:** Contenedores corriendo, verificar URL pública

### Dental.io

- **URL:** <https://www.dental-io.com> (estimada)
- **Servicio:** Aplicación dental
- **Estado:** ⚠️ CONFIGURADO (verificar estado)
- **Notas:** Configuración existe, verificar contenedor

### Mambo Cloud Staging

- **URL:** <https://staging.mambo-cloud.com>
- **Servicio:** Ambiente staging
- **Estado:** ❌ NO DESPLEGADO
- **Notas:** Configuración existe, contenedor no activo

### Mambo Cloud Lab

- **URL:** <https://lab.mambo-cloud.com>
- **Servicio:** Ambiente de laboratorio
- **Estado:** ❌ NO DESPLEGADO
- **Notas:** Configuración existe, contenedor no activo

---

## 🔒 Servicios Internos (No Expuestos Públicamente)

### Docker Socket Proxy

- **Puerto:** N/A (solo interno)
- **Servicio:** Proxy de seguridad para Docker socket
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `docker-socket-proxy`

### Loki - Log Aggregation

- **Puerto:** 3100 (interno)
- **Servicio:** Agregación y almacenamiento de logs
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `loki`
- **Acceso:** Vía Grafana

### Promtail - Log Shipper

- **Puerto:** N/A (solo interno)
- **Servicio:** Recolector de logs Docker → Loki
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `promtail`

### vmagent - Metrics Collector

- **Puerto:** 8429 (interno)
- **Servicio:** Recolector de métricas Prometheus
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `vmagent`

### vmalert - Alerting Rules

- **Puerto:** 8880 (interno)
- **Servicio:** Evaluación de reglas de alertas
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `vmalert`
- **Reglas activas:** 14 alertas configuradas

### cAdvisor - Container Metrics

- **Puerto:** 8080 (interno)
- **Servicio:** Métricas de contenedores Docker
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `cadvisor`

### Node Exporter - Host Metrics

- **Puerto:** 9100 (interno)
- **Servicio:** Métricas del host (CPU, RAM, Disk, Network)
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `node-exporter`

### ntfy-forwarder - Alert Notifications

- **Puerto:** N/A (webhook)
- **Servicio:** Forward de alertas a ntfy.sh
- **Estado:** ✅ OPERACIONAL
- **Contenedor:** `ntfy-forwarder`
- **Topic:** codespartan-mambo-alerts

---

## 🧪 Verificación Rápida

### Test de Endpoints Públicos

```bash
# Plataforma
curl -I https://traefik.mambo-cloud.com
curl -I https://grafana.mambo-cloud.com
curl -I https://auth.mambo-cloud.com
curl -I https://backoffice.mambo-cloud.com

# Aplicaciones
curl -I https://api.cyberdyne-systems.es/api/v1/health
curl -I https://www.cyberdyne-systems.es
curl -I https://ui.codespartan.cloud
```

### Verificar Contenedores Activos

```bash
ssh leonidas@91.98.137.217 "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### Ver Rutas en Traefik

```bash
ssh leonidas@91.98.137.217 "docker exec traefik wget -qO- http://localhost:8080/api/http/routers | jq '.[] | select(.status == \"enabled\") | {name: .name, rule: .rule, service: .service}'"
```

---

## 📝 Notas Importantes

### Credenciales Predeterminadas

- **Usuario:** admin
- **Password:** codespartan123
- **Aplica a:** Traefik, Grafana, Authelia, Backoffice

### SSL/TLS

- **Proveedor:** Let's Encrypt
- **Renovación:** Automática vía Traefik
- **Wildcard:** No (certificados individuales por subdomain)

### Dominios DNS (Hetzner)

Los siguientes dominios están configurados en Hetzner DNS:

**mambo-cloud.com:**

- traefik.mambo-cloud.com → 91.98.137.217
- grafana.mambo-cloud.com → 91.98.137.217
- auth.mambo-cloud.com → 91.98.137.217
- backoffice.mambo-cloud.com → 91.98.137.217
- <www.mambo-cloud.com> → 91.98.137.217
- staging.mambo-cloud.com → 91.98.137.217
- lab.mambo-cloud.com → 91.98.137.217

**cyberdyne-systems.es:**

- api.cyberdyne-systems.es → 91.98.137.217
- api-staging.cyberdyne-systems.es → 91.98.137.217
- <www.cyberdyne-systems.es> → 91.98.137.217
- staging.cyberdyne-systems.es → 91.98.137.217
- lab.cyberdyne-systems.es → 91.98.137.217
- cyberdyne-systems.es → 91.98.137.217

**codespartan.cloud:**

- ui.codespartan.cloud → 91.98.137.217
- <www.codespartan.cloud> → 91.98.137.217

### Próximos Pasos

Para completar el inventario, verificar:

1. ❓ Estado real de Redmine (URL pública)
2. ❓ Estado de <www.codespartan.cloud>
3. ❓ Estado de <www.mambo-cloud.com>
4. ❓ Estado de dental-io.com

---

## 🔗 Referencias

- **Traefik Dashboard:** Ver todas las rutas activas
- **Grafana Dashboards:** Ver métricas de todos los servicios
- **Documentación:** `docs/03-operations/RUNBOOK.md`
- **Arquitectura:** `docs/02-architecture/ARCHITECTURE.md`

---

**Última verificación:** 2025-12-13
**Documentado por:** Claude Code
