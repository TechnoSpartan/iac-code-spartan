# Plan de Mejoras - CodeSpartan Infrastructure

**Fecha**: 2025-11-18
**Estado**: Propuesto
**Prioridad**: Alta → Media → Baja

---

## Resumen Ejecutivo

Basado en el análisis exhaustivo del repositorio, se identificaron 5 áreas de mejora prioritarias. Este documento detalla cada una con análisis, impacto, y plan de acción.

**Estado general del proyecto**: ✅ PRODUCCIÓN MADURO

---

## 1. Configuración SMTP (Authelia) - ALTA PRIORIDAD

### Estado Actual

- ✅ Authelia desplegado y funcionando
- ✅ MFA con TOTP (Google Authenticator) activo
- ✅ Credenciales SMTP ya configuradas (Hostinger)
- ❌ SMTP comentado, usando filesystem para notificaciones

**Configuración en `platform/authelia/configuration.yml`:**

```yaml
# Líneas 144-145: ACTIVO
notifier:
  filesystem:
    filename: /data/notifications.txt

# Líneas 147-162: COMENTADO
# smtp:
#   host: smtp.hostinger.com
#   port: 465
#   username: iam@codespartan.es
#   password: Codespartan$2
#   sender: "Mambo Cloud Auth <noreply@codespartan.es>"
```

### Impacto

**Funcionalidades NO disponibles sin SMTP:**
- ❌ Password reset via email
- ❌ Email notifications para cambios de seguridad
- ❌ Alertas de logins sospechosos
- ❌ Invitaciones de usuarios por email

**Funcionalidades QUE SÍ funcionan actualmente:**
- ✅ SSO authentication
- ✅ MFA con TOTP
- ✅ Session management
- ✅ Access control

### Solución

**Opción A: Habilitar SMTP (Recomendado)**

Ya existe un workflow preparado: `.github/workflows/configure-smtp.yml`

**Pasos:**
1. Verificar credenciales Hostinger
2. Ejecutar workflow: `gh workflow run configure-smtp.yml`
3. Verificar logs: `docker logs authelia --tail 20`
4. Testear reset password

**Configuración final (líneas 156-178 del workflow):**

```yaml
notifier:
  # Mantener filesystem como fallback
  filesystem:
    filename: /data/notifications.txt

  # SMTP configurado
  smtp:
    host: smtp.hostinger.com
    port: 465
    timeout: 5s
    username: iam@codespartan.es
    password: Codespartan$2
    sender: "Mambo Cloud Auth <noreply@codespartan.es>"
    identifier: mambo-cloud.com
    subject: "[Mambo Cloud] {title}"
    startup_check_address: iam@codespartan.es
    disable_require_tls: false
    tls:
      server_name: smtp.hostinger.com
      skip_verify: false
```

**Nota**: Authelia puede tener AMBOS (filesystem + smtp). Filesystem sirve como backup local.

**Opción B: Cambiar a otro proveedor SMTP**

Si Hostinger no funciona, alternativas:
- SendGrid (Free tier: 100 emails/día)
- Mailgun (Free tier: 5,000 emails/mes)
- AWS SES (Free tier: 62,000 emails/mes)

### Verificación Post-Implementación

```bash
# 1. Ejecutar workflow
gh workflow run configure-smtp.yml

# 2. Verificar logs
docker logs authelia --tail 30 | grep -i "smtp\|mail"

# 3. Testear reset password
# - Ir a https://auth.mambo-cloud.com
# - Click "Forgot password?"
# - Verificar email recibido
```

### Tiempo Estimado
- 30 minutos (si credenciales Hostinger son correctas)
- 2 horas (si requiere configurar nuevo proveedor)

---

## 2. Network Isolation - MEDIA PRIORIDAD

### Estado Actual

**Apps CON network isolation correcta:**
- ✅ `cyberdyne-systems-es/api` - Red `trackworks` (MongoDB)
- ✅ `cyberdyne-systems-es/api-staging` - Red `trackworks-staging`
- ✅ `codespartan-cloud/project` - Red `openproject_internal` (PostgreSQL)
- ✅ `dental-io-com/www` - Red `dental_net` (preparada)
- ✅ `mambo-cloud-com/www` - Red `mambo_net` (preparada)

**Apps SIN network isolation (solo `web`):**
- ⚠️ `codespartan-cloud/www` - Solo web (puerto 3000)
- ⚠️ `codespartan-cloud/ui` - Solo web (Nginx estático)
- ⚠️ `cyberdyne-systems-es/www` - Solo web (Nginx estático)
- ⚠️ `cyberdyne-systems-es/staging` - Solo web

### Análisis

**Apps que NO necesitan internal network:**
- ✅ `codespartan-cloud/ui` - Storybook estático (solo Nginx)
- ✅ `cyberdyne-systems-es/www` - Frontend React estático (solo Nginx)
- ✅ `cyberdyne-systems-es/staging` - Frontend estático

**Apps que PODRÍAN necesitar internal network:**
- ⚠️ `codespartan-cloud/www` - App Node.js en puerto 3000
  - **Verificar**: ¿Tiene base de datos? ¿Redis? ¿Otro backend?
  - Si no tiene BD → OK solo con `web`
  - Si tiene BD → Agregar network isolation

### Riesgo de Seguridad

**Escenario actual (sin isolation):**
```
cyberdyne-frontend → web network ← cyberdyne-api
                  ↓
                trackworks-db
```

Si `cyberdyne-frontend` fuera comprometido:
- ❌ Puede acceder directamente a `trackworks-db` (mismo network)
- ❌ Puede acceder a otros contenedores en `web`

**Escenario ideal (con isolation):**
```
cyberdyne-frontend → web network (solo Traefik)

trackworks-api → web + trackworks network
trackworks-db → trackworks network (solo api)
```

Beneficios:
- ✅ Frontend NO puede acceder a BD directamente
- ✅ BD solo accesible por su API
- ✅ Aislamiento entre apps

### Recomendación

**ACCIÓN**: Verificar si `codespartan-cloud/www` tiene base de datos.

**Si NO tiene BD:**
- ✅ Configuración actual correcta

**Si SÍ tiene BD:**
- Implementar pattern del template:

```yaml
services:
  web:
    networks:
      - web                 # Traefik routing
      - codespartan_net     # Internal communication

  database:
    networks:
      - codespartan_net     # ONLY internal

networks:
  web:
    external: true
  codespartan_net:
    name: codespartan_internal
    driver: bridge
    internal: true          # No internet access
    ipam:
      config:
        - subnet: 172.26.0.0/24
```

**Subnets disponibles:**
- 172.26.0.0/24 - codespartan_internal
- 172.27.0.0/24 - reserva futura

### Tiempo Estimado
- 1 hora (si requiere implementación)
- 0 horas (si apps actuales son solo frontends estáticos)

---

## 3. Directorios Deprecated - COMPLETADO ✅

### Estado

**✅ Migración completada**

Los siguientes directorios deprecated **YA fueron eliminados**:
- ~~`cyberdyne/`~~ → `cyberdyne-systems-es/`
- ~~`cyberdyne-api/`~~ → Duplicate eliminado
- ~~`dental-io/`~~ → `dental-io-com/`
- ~~`mambo-cloud/`~~ → `mambo-cloud-com/`
- ~~`openproject/`~~ → `cyberdyne-systems-es/project/`

Directorios actuales:
```bash
codespartan/apps/
├── codespartan-cloud/
├── cyberdyne-systems-es/
├── dental-io-com/
└── mambo-cloud-com/
```

**No se requiere acción.**

---

## 4. Estandarizar Traefik Routing - MEDIA PRIORIDAD

### Estado Actual

**File Provider** (`platform/traefik/dynamic-config.yml`):
- codespartan-www (www.codespartan.cloud)
- codespartan-ui (ui.codespartan.cloud)
- Middlewares globales
- HTTP → HTTPS redirect

**Docker Provider** (labels en `docker-compose.yml`):
- cyberdyne-www (www.cyberdyne-systems.es)
- cyberdyne-api (api.cyberdyne-systems.es)
- mambo-cloud (www.mambo-cloud.com)
- Todos los servicios de plataforma

### Contexto Histórico

Según `docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md`:

**Problema**: Docker Provider no estaba descubriendo automáticamente `codespartan-www` y `codespartan-ui` a pesar de:
- ✅ Labels correctas
- ✅ Red `web` correcta
- ✅ `docker-socket-proxy` funcionando

**Solución temporal**: File Provider para CodeSpartan Cloud

### Análisis

**Ventajas File Provider:**
- ✅ Configuración centralizada
- ✅ Cambios sin recrear contenedores
- ✅ Fácil debugging
- ✅ Control explícito de routing

**Ventajas Docker Provider:**
- ✅ Auto-discovery de servicios
- ✅ Menos archivos de configuración
- ✅ Configuración junto al servicio (docker-compose.yml)
- ✅ Scaling automático

### Recomendación

**OPCIÓN A: Mantener híbrido (Recomendado)**

Usar ambos providers según el caso:

**File Provider para:**
- Middlewares globales (security-headers, compression, rate-limit)
- HTTP → HTTPS redirect global
- Routing estático que no cambia frecuentemente

**Docker Provider para:**
- Aplicaciones individuales
- Servicios que escalan
- Configuración auto-descubierta

**Ventajas del enfoque híbrido:**
- ✅ Lo mejor de ambos mundos
- ✅ Ya está funcionando en producción
- ✅ Traefik soporta múltiples providers simultáneamente

**OPCIÓN B: Migrar CodeSpartan Cloud a Docker Provider**

Investigar por qué Docker Provider falló originalmente y resolver:

**Pasos de investigación:**
1. Verificar si el problema persiste:
   - Agregar labels a `codespartan-www` docker-compose
   - Reiniciar Traefik
   - Verificar API: `curl http://localhost:8080/api/http/routers`

2. Si persiste, debug:
   - Logs de Traefik: `docker logs traefik | grep docker`
   - Verificar `docker-socket-proxy` permissions
   - Verificar versión de Traefik

**OPCIÓN C: Migrar TODO a File Provider**

Menos recomendado porque:
- ❌ Más archivos de configuración
- ❌ Cambios requieren edit + restart Traefik
- ❌ Menos flexible para scaling

### Decisión Recomendada

**Mantener configuración híbrida actual**

**Justificación:**
- Sistema estable y funcionando
- Cada provider usado para sus fortalezas
- Documentación clara del por qué

**Acción requerida:**
- ✅ Documentar patrón híbrido como estándar
- ✅ Actualizar guía de nuevas apps
- ❌ No migrar (riesgo > beneficio)

### Documentación Requerida

Agregar a `CLAUDE.md` o `docs/ARCHITECTURE.md`:

```markdown
## Traefik Routing Strategy

**Patrón híbrido**: File Provider + Docker Provider

### File Provider
Usado para configuración global y routing estático:
- Middlewares globales
- HTTP → HTTPS redirect
- CodeSpartan Cloud (www, ui)

### Docker Provider
Usado para aplicaciones individuales:
- Cyberdyne Systems (www, api)
- Mambo Cloud
- Servicios de plataforma

### Cuándo usar cada uno

**Use File Provider cuando:**
- Configuración global (middlewares)
- Routing que no cambia frecuentemente
- Debugging de problemas de discovery

**Use Docker Provider cuando:**
- Nueva aplicación (patrón por defecto)
- Servicio que puede escalar
- Configuración junto a la app
```

### Tiempo Estimado
- 1 hora (solo documentación)

---

## 5. Pin Docker Image Versions - MEDIA PRIORIDAD

### Estado Actual

**Con version pinning:**
- ✅ VictoriaMetrics: `v1.106.1`
- ✅ Grafana: `11.3.1`
- ✅ Loki: `3.2.1`
- ✅ Promtail: `3.2.1`
- ✅ cAdvisor: `v0.49.1`
- ✅ Node Exporter: `v1.8.2`
- ✅ vmagent: `v1.106.1`
- ✅ vmalert: `v1.106.1`
- ✅ Alertmanager: `v0.27.0`

**Sin version pinning (latest):**
- ⚠️ Authelia: `latest`
- ⚠️ docker-socket-proxy: `latest`

### Riesgo

**Usando `latest`:**
- ❌ Breaking changes no previstos
- ❌ Difícil rollback
- ❌ No reproducible
- ❌ Pull en producción puede romper servicio

**Ejemplo real:**
```yaml
# Malo
authelia:
  image: authelia/authelia:latest

# Bueno
authelia:
  image: authelia/authelia:4.38.10
```

### Recomendación

**ACCIÓN**: Pin versions en servicios con `latest`

**1. Authelia:**

Versión actual de `latest`:
```bash
docker image inspect authelia/authelia:latest --format '{{.RepoDigests}}'
```

Resultado esperado: `4.38.x`

**Actualizar `platform/authelia/docker-compose.yml`:**
```yaml
services:
  authelia:
    image: authelia/authelia:4.38.10  # Pin version actual
```

**2. docker-socket-proxy:**

```bash
docker image inspect tecnativa/docker-socket-proxy:latest --format '{{.RepoDigests}}'
```

**Actualizar `platform/docker-socket-proxy/docker-compose.yml`:**
```yaml
services:
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy:0.2.0  # Pin version
```

### Estrategia de Actualización

**Proceso recomendado:**

1. **Inventario de versions actuales**:
   ```bash
   docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}"
   ```

2. **Pin versions actuales** (no actualizar aún):
   - Usar la versión que está funcionando actualmente
   - Documentar en commit message

3. **Proceso de actualización** (futuro):
   - Revisar changelog de nueva versión
   - Testear en staging (cuando esté disponible)
   - Actualizar version en docker-compose
   - Deploy y verificar

4. **Documentar versions**:
   - Crear `docs/VERSIONS.md` con tabla de versiones
   - Incluir fecha de última actualización
   - Incluir breaking changes conocidos

### Script de Verificación

```bash
#!/bin/bash
# check-image-versions.sh

echo "=== Docker Images Sin Version Pinning ==="
echo ""

find codespartan -name "docker-compose.yml" -exec grep -H ":latest" {} \;

echo ""
echo "Total images con 'latest':"
find codespartan -name "docker-compose.yml" -exec grep -h ":latest" {} \; | wc -l
```

### Tiempo Estimado
- 2 horas (inventario + pin + testing)

---

## Priorización Final

### Alta Prioridad (Hacer esta semana)

1. **SMTP Configuration** ✅
   - Impacto: Habilita password reset y notificaciones
   - Esfuerzo: 30 min - 2h
   - Workflow ya preparado

### Media Prioridad (Hacer este mes)

2. **Network Isolation Verification** ⚠️
   - Impacto: Seguridad (si apps tienen BD)
   - Esfuerzo: 1h
   - Verificar `codespartan-cloud/www` requirements

3. **Pin Docker Versions** ⚠️
   - Impacto: Previene breaking changes
   - Esfuerzo: 2h
   - Solo 2 imágenes afectadas (Authelia, socket-proxy)

4. **Documentar Traefik Hybrid Strategy** ℹ️
   - Impacto: Claridad arquitectónica
   - Esfuerzo: 1h
   - Solo documentación

### Baja Prioridad (Opcional)

5. **Directorios Deprecated** ✅ COMPLETADO

---

## Checklist de Implementación

```markdown
- [ ] 1. SMTP Configuration
  - [ ] Verificar credenciales Hostinger
  - [ ] Ejecutar workflow `configure-smtp.yml`
  - [ ] Verificar logs Authelia
  - [ ] Testear password reset

- [ ] 2. Network Isolation
  - [ ] Verificar arquitectura codespartan-cloud/www
  - [ ] Si tiene BD → Implementar internal network
  - [ ] Si no tiene BD → Documentar "OK con solo web"

- [x] 3. Directorios Deprecated
  - [x] ~~Eliminar directorios~~ ✅ YA ELIMINADOS

- [ ] 4. Traefik Routing
  - [ ] Documentar patrón híbrido en ARCHITECTURE.md
  - [ ] Actualizar guía de nuevas apps

- [ ] 5. Docker Versions
  - [ ] Inventariar versiones actuales
  - [ ] Pin Authelia version
  - [ ] Pin docker-socket-proxy version
  - [ ] Crear docs/VERSIONS.md
  - [ ] Re-deploy y verificar
```

---

## Métricas de Éxito

**Post-implementación verificar:**

1. ✅ Authelia envía emails correctamente
2. ✅ Password reset funciona end-to-end
3. ✅ Todas las apps en producción estables (no breaking changes)
4. ✅ Documentación actualizada y clara
5. ✅ No hay directorios deprecated
6. ✅ Security posture mejorado (network isolation)

---

## Documentos Relacionados

- `codespartan/apps/MIGRATION.md` - Migración de estructura (COMPLETADO)
- `codespartan/docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md` - Contexto Traefik
- `codespartan/apps/_TEMPLATE/NETWORK_ISOLATION.md` - Guía network isolation
- `.github/workflows/configure-smtp.yml` - Workflow SMTP

---

**Última actualización**: 2025-11-18
**Próxima revisión**: 2025-11-25
