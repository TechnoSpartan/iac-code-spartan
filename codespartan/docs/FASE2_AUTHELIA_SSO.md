# FASE 2: Authelia SSO - Implementación Completa

## 📋 Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Credenciales de Acceso](#credenciales-de-acceso)
3. [Arquitectura Implementada](#arquitectura-implementada)
4. [Configuración Detallada](#configuración-detallada)
5. [Problemas Encontrados y Soluciones](#problemas-encontrados-y-soluciones)
6. [Lecciones Aprendidas](#lecciones-aprendidas)
7. [Testing y Verificación](#testing-y-verificación)
8. [Troubleshooting](#troubleshooting)

---

## Resumen Ejecutivo

**FASE 2 completada exitosamente**: Todos los dashboards de la plataforma están ahora protegidos por Authelia SSO con autenticación de dos factores (MFA).

### URLs Protegidas

- **Portal de autenticación**: https://auth.mambo-cloud.com
- **Traefik Dashboard**: https://traefik.mambo-cloud.com
- **Grafana**: https://grafana.mambo-cloud.com
- **Backoffice**: https://backoffice.mambo-cloud.com

### Características Implementadas

✅ Single Sign-On (SSO) centralizado
✅ Multi-Factor Authentication (TOTP/Google Authenticator)
✅ Sesiones seguras en Redis
✅ Políticas de acceso granulares por dominio y grupo
✅ Protección contra brute-force
✅ Cookies seguras (HttpOnly, Secure, SameSite)

---

## Credenciales de Acceso

### Primera Configuración

1. **Accede a cualquier dashboard** (por ejemplo: https://traefik.mambo-cloud.com)
2. **Serás redirigido a Authelia**: https://auth.mambo-cloud.com

3. **Credenciales iniciales**:
   ```
   Usuario: admin
   Contraseña: codespartan123
   ```

4. **Configura MFA (primera vez)**:
   - Tras el primer login, Authelia te pedirá configurar MFA
   - Escanea el código QR con Google Authenticator o similar
   - Ingresa el código de 6 dígitos para verificar
   - **IMPORTANTE**: Guarda tu código de recuperación en lugar seguro

5. **Próximos logins**:
   - Usuario + Contraseña + Código MFA (6 dígitos)
   - La sesión dura 1 hora (configurable)
   - Opción "Remember Me" extiende la sesión a 1 mes

### Gestión de Usuarios

Los usuarios están definidos en:
```
/opt/codespartan/platform/authelia/users_database.yml
```

Para añadir nuevos usuarios, genera el hash de la contraseña:
```bash
docker exec -it authelia authelia crypto hash generate argon2 --password 'tu_contraseña'
```

---

## Arquitectura Implementada

### Flujo de Autenticación

```
Usuario → HTTPS → Traefik
                    ↓
            Middleware authelia@docker
                    ↓
            ¿Sesión válida? ─NO→ Redirigir a auth.mambo-cloud.com
                    ↓                       ↓
                   SÍ                  Login + MFA
                    ↓                       ↓
            Dashboard solicitado ←──────────┘
```

### Componentes

1. **Authelia** (puerto 9091)
   - Servidor de autenticación
   - Gestiona usuarios, sesiones, MFA
   - Expuesto vía Traefik en auth.mambo-cloud.com

2. **Redis** (puerto 6379)
   - Almacena sesiones de usuario
   - Solo accesible en red interna `authelia_internal`

3. **Traefik Middleware**
   - `authelia@docker`: ForwardAuth a Authelia
   - Aplicado a todos los routers que requieren autenticación

4. **Grafana Auth Proxy**
   - Confía en headers de Authelia
   - Auto-crea usuarios con rol Admin

### Redes Docker

```yaml
web:                  # Traefik ↔ Authelia ↔ Grafana
  external: true

authelia_internal:    # Authelia ↔ Redis (privada)
  driver: bridge
  internal: true
```

---

## Configuración Detallada

### Archivos Clave

#### 1. `codespartan/platform/authelia/configuration.yml`

Configuración principal de Authelia:

**Características destacadas**:
- TOTP con Google Authenticator (SHA1, 6 dígitos, 30s)
- Backend de archivos (users_database.yml)
- SQLite para persistencia
- Redis para sesiones
- Políticas de acceso por dominio

**Políticas de Acceso**:
```yaml
access_control:
  default_policy: deny
  rules:
    # Authelia portal público
    - domain: auth.mambo-cloud.com
      policy: bypass

    # Dashboards requieren MFA
    - domain:
        - traefik.mambo-cloud.com
        - grafana.mambo-cloud.com
        - backoffice.mambo-cloud.com
      policy: two_factor
      subject:
        - "group:admins"
```

#### 2. `codespartan/platform/authelia/users_database.yml`

Base de datos de usuarios:

```yaml
users:
  admin:
    displayname: "Administrator"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # codespartan123
    email: admin@mambo-cloud.com
    groups:
      - admins
      - dev
```

#### 3. `codespartan/platform/authelia/docker-compose.yml`

Deployment de Authelia + Redis:

**Labels de Traefik importantes**:
```yaml
- traefik.http.routers.authelia.rule=Host(`auth.mambo-cloud.com`)
- traefik.http.middlewares.authelia.forwardAuth.address=http://authelia:9091/api/verify?rd=https://auth.mambo-cloud.com
- traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true
- traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email
```

#### 4. Traefik con Authelia

**Antes** (Basic Auth):
```yaml
labels:
  - traefik.http.middlewares.traefik-auth.basicauth.usersfile=/users.htpasswd
  - traefik.http.routers.traefik.middlewares=traefik-auth,rate-limit-strict@file
```

**Después** (Authelia SSO):
```yaml
labels:
  # - traefik.http.middlewares.traefik-auth.basicauth.usersfile=/users.htpasswd
  - traefik.http.routers.traefik.middlewares=authelia@docker,rate-limit-strict@file
```

#### 5. Grafana con Authelia

**Variables de entorno añadidas**:
```yaml
environment:
  # FASE 2: Authelia SSO Integration
  - GF_AUTH_PROXY_ENABLED=true
  - GF_AUTH_PROXY_HEADER_NAME=Remote-User
  - GF_AUTH_PROXY_HEADER_PROPERTY=username
  - GF_AUTH_PROXY_AUTO_SIGN_UP=true
  - GF_AUTH_PROXY_HEADERS=Name:Remote-Name Email:Remote-Email
  - GF_USERS_ALLOW_SIGN_UP=false
  - GF_USERS_AUTO_ASSIGN_ORG=true
  - GF_USERS_AUTO_ASSIGN_ORG_ROLE=Admin
```

---

## Problemas Encontrados y Soluciones

### Problema 1: Authelia en Crash-Loop

**Síntoma**:
- Authelia se reiniciaba constantemente
- Logs mostraban: `"identity_providers: oidc: option 'jwks' is required"`
- Dashboards inaccesibles (HTTP 504 Gateway Timeout)

**Diagnóstico**:
1. El archivo `configuration.yml` local estaba correcto (sin OIDC)
2. El archivo en el VPS (`/opt/codespartan/platform/authelia/`) tenía configuración vieja
3. SCP no sobrescribía archivos existentes (`overwrite: false` por defecto)

**Root Cause**:
```yaml
# En .github/workflows/deploy-authelia.yml
- name: Copy Authelia files to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
    source: "codespartan/platform/authelia/*"
    target: "/opt/codespartan/platform/authelia/"
    # ❌ FALTABA: overwrite: true
```

**Solución**:
```yaml
- name: Copy Authelia files to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
    source: "codespartan/platform/authelia/*"
    target: "/opt/codespartan/platform/authelia/"
    overwrite: true  # ✅ AÑADIDO
```

**Commit**: `d957b1a` - "fix: Enable overwrite for Authelia config files in SCP"

---

### Problema 2: Configuración No Se Recargaba

**Síntoma**:
- Workflow reportaba deployment exitoso
- Logs mostraban que el archivo se actualizó (`Modify: 2025-11-15 20:55:41`)
- Authelia seguía crasheando con el mismo error OIDC

**Diagnóstico**:
```bash
# Archivo en disco: ✅ CORRECTO (sin OIDC)
$ cat /opt/codespartan/platform/authelia/configuration.yml
# NO contiene identity_providers

# Pero los logs del contenedor: ❌ ERROR OIDC
$ docker logs authelia
time="2025-11-15T20:52:21+01:00" level=error msg="identity_providers: oidc: option `jwks` is required"
```

**Root Cause**:
El workflow hacía `docker compose restart` que:
- Reinicia el contenedor existente
- NO recrea el contenedor
- NO recarga los archivos montados como volúmenes

**Solución**:
```bash
# ❌ MAL: Solo reinicia
docker compose restart authelia

# ✅ BIEN: Recrea el contenedor
docker compose down
docker compose up -d --force-recreate
```

**Workflow creado**: `fix-authelia-recreate.yml`

**Resultado**:
```
✅ NO OIDC ERRORS FOUND!
✅ Authelia is HEALTHY!
```

---

### Problema 3: Authelia Healthy pero HTTP 504

**Síntoma**:
- Authelia container healthy ✅
- Traefik puede alcanzar Authelia internamente ✅
- Pero desde fuera: HTTP 504 Gateway Timeout ❌

**Diagnóstico**:
```bash
# Test interno: ✅ FUNCIONA
$ docker exec traefik wget -O- http://authelia:9091/api/health
Connecting to authelia:9091 (172.18.0.6:9091)
written to stdout

# Test externo: ❌ 504
$ curl https://auth.mambo-cloud.com
Gateway Timeout
```

**Root Cause**:
Traefik no había detectado el nuevo middleware `authelia@docker` porque:
- El docker-compose.yml de Authelia cambió (añadió labels)
- Traefik auto-descubre via Docker API
- Pero el middleware se registró DESPUÉS de que Traefik ya estaba corriendo

**Solución**:
```bash
docker compose restart traefik
```

Tras el restart, Traefik detectó el middleware y empezó a funcionar:
```bash
$ curl -I https://auth.mambo-cloud.com
HTTP/2 200  # ✅ FUNCIONA
```

---

## Lecciones Aprendidas

### 1. SCP y Sobrescritura de Archivos

**Lección**: `appleboy/scp-action` tiene `overwrite: false` por defecto.

**Buena práctica**:
```yaml
- uses: appleboy/scp-action@v0.1.7
  with:
    source: "path/to/files/*"
    target: "/remote/path/"
    overwrite: true  # ⚠️ IMPORTANTE: Siempre especificar explícitamente
```

**Cuándo usar**:
- `overwrite: true` → Deployments (sobrescribir configuración)
- `overwrite: false` → Backups (no sobrescribir archivos existentes)

---

### 2. Docker Restart vs Recreate

**Lección**: `docker compose restart` NO recarga configuración de volúmenes.

**Diferencias**:

| Comando | Recarga Config | Recrea Container | Downtime |
|---------|----------------|------------------|----------|
| `docker compose restart` | ❌ NO | ❌ NO | ~5s |
| `docker compose up -d` | ⚠️ Solo nuevos | ⚠️ Solo si cambió | ~10s |
| `docker compose up -d --force-recreate` | ✅ SÍ | ✅ SÍ | ~15s |

**Buena práctica**:
```bash
# Cuando cambias archivos de configuración montados:
docker compose down
docker compose up -d --force-recreate

# Cuando solo necesitas restart rápido:
docker compose restart
```

---

### 3. Traefik Auto-Discovery

**Lección**: Traefik necesita restart para detectar nuevos middlewares de otros containers.

**Por qué**:
- Traefik escucha eventos de Docker API
- Detecta nuevos containers automáticamente
- Pero los middlewares definidos en labels de containers existentes requieren restart

**Orden correcto de deployment**:
```bash
# 1. Desplegar nuevo servicio (ej: Authelia)
cd /opt/codespartan/platform/authelia
docker compose up -d

# 2. Esperar a que esté healthy
docker inspect --format='{{.State.Health.Status}}' authelia
# healthy

# 3. Restart Traefik para detectar middlewares
cd /opt/codespartan/platform/traefik
docker compose restart traefik

# 4. Verificar
curl -I https://auth.mambo-cloud.com
# HTTP/2 200
```

---

### 4. Debugging de Configuración

**Estrategia efectiva**:

1. **Verificar archivo en disco**:
```bash
cat /path/to/config.yml
```

2. **Verificar timestamp del archivo**:
```bash
stat /path/to/config.yml | grep Modify
```

3. **Verificar qué lee el contenedor**:
```bash
docker exec container cat /config/configuration.yml
```

4. **Verificar volúmenes montados**:
```bash
docker inspect container | grep -A 10 "Mounts"
```

5. **Recrear para forzar recarga**:
```bash
docker compose down
docker compose up -d --force-recreate
docker logs container --tail 50
```

---

### 5. Workflows de GitHub Actions

**Lección**: Los workflows deben ser independientes y tener safety checks.

**Mal diseño** (lo que intentamos primero):
```yaml
# Un solo workflow que:
# 1. Deploy Authelia
# 2. Update Traefik
# 3. Update Grafana
# ❌ Si falla paso 2, todo queda roto
```

**Buen diseño** (lo que implementamos):
```yaml
# Workflow 1: deploy-authelia.yml
# - Deploy SOLO Authelia
# - NO toca otros servicios

# Workflow 2: enable-authelia-traefik.yml
# - Requiere confirmación manual
# - Verifica que Authelia esté corriendo
# - Tiene rollback automático

# Workflow 3: enable-authelia-grafana.yml
# - Requiere confirmación manual
# - Se ejecuta DESPUÉS de Traefik
# - Tiene rollback automático
```

**Safety checks clave**:
```yaml
# Verificar prerequisitos
if ! docker ps | grep -q "authelia.*Up"; then
  echo "❌ Authelia is not running!"
  exit 1
fi

# Backup antes de cambios
cp config.yml "config-backup-$(date +%s).yml"

# Rollback en error
if [ $? -ne 0 ]; then
  cp "$BACKUP_FILE" config.yml
  docker compose up -d --force-recreate
  exit 1
fi
```

---

### 6. Gestión de Credenciales

**Lección**: Las contraseñas hasheadas son inmutables tras deployment.

**Para cambiar contraseña de admin**:

1. Generar nuevo hash:
```bash
docker exec -it authelia authelia crypto hash generate argon2 \
  --password 'nueva_contraseña_segura'
```

2. Actualizar `users_database.yml`:
```yaml
users:
  admin:
    password: "$argon2id$v=19$m=65536,t=3,p=4$NUEVO_HASH_AQUI"
```

3. **IMPORTANTE**: Recrear container:
```bash
cd /opt/codespartan/platform/authelia
docker compose down
docker compose up -d --force-recreate
```

**Rotación de secretos**:
- `session.secret`: Invalida todas las sesiones activas
- `jwt_secret`: Invalida tokens de reset password
- `encryption_key`: Re-encripta storage (requiere migración)

---

## Testing y Verificación

### Tests Funcionales

#### 1. Authelia Portal

```bash
# Debe devolver HTTP 200
curl -I https://auth.mambo-cloud.com
```

**Respuesta esperada**:
```
HTTP/2 200
content-type: text/html; charset=utf-8
```

---

#### 2. Redirección a Authelia

```bash
# Traefik
curl -I https://traefik.mambo-cloud.com

# Grafana
curl -I https://grafana.mambo-cloud.com
```

**Respuesta esperada**:
```
HTTP/2 302
location: https://auth.mambo-cloud.com/?rd=https%3A%2F%2Ftraefik.mambo-cloud.com%2F
set-cookie: authelia_session=...
```

---

#### 3. Health Checks

```bash
# Authelia healthy
docker inspect --format='{{.State.Health.Status}}' authelia
# healthy

# Redis healthy
docker inspect --format='{{.State.Health.Status}}' authelia-redis
# healthy

# Traefik puede alcanzar Authelia
docker exec traefik wget -O- http://authelia:9091/api/health
# HTTP 200
```

---

#### 4. Logs Sin Errores

```bash
# No debe haber errores level=error o level=fatal
docker logs authelia --tail 100 | grep -i "level=error\|level=fatal"
# (vacío)

# No debe haber errores de OIDC
docker logs authelia | grep -i "oidc\|jwks"
# (vacío)
```

---

### Tests de Seguridad

#### 1. MFA Obligatorio

```bash
# Intentar acceder sin MFA debe fallar
curl -L -c cookies.txt -b cookies.txt \
  -d "username=admin&password=codespartan123" \
  https://auth.mambo-cloud.com/api/firstfactor

# Debe solicitar second factor
```

---

#### 2. Brute-Force Protection

```bash
# 3 intentos fallidos
for i in {1..3}; do
  curl -d "username=admin&password=wrong" \
    https://auth.mambo-cloud.com/api/firstfactor
done

# 4to intento debe ser bloqueado (HTTP 403)
```

---

#### 3. Headers de Seguridad

```bash
curl -I https://auth.mambo-cloud.com | grep -i "x-frame-options\|x-content-type-options\|csp"
```

**Debe incluir**:
```
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
content-security-policy: ...
```

---

## Troubleshooting

### Authelia No Responde (HTTP 504)

**Diagnóstico**:
```bash
# 1. Container running?
docker ps | grep authelia

# 2. Container healthy?
docker inspect --format='{{.State.Health.Status}}' authelia

# 3. Logs tienen errores?
docker logs authelia --tail 50 | grep -i error

# 4. Traefik puede alcanzar?
docker exec traefik wget -O- http://authelia:9091/api/health
```

**Soluciones**:
- Si container no está running → revisar logs, recrear
- Si no healthy → esperar 30s, revisar healthcheck
- Si logs con error → corregir configuración, recrear
- Si Traefik no alcanza → verificar redes docker

---

### Login No Funciona

**Síntoma**: Credenciales correctas pero login falla

**Verificar**:
```bash
# 1. Usuario existe en users_database.yml?
docker exec authelia cat /config/users_database.yml

# 2. Hash de contraseña correcto?
docker exec authelia authelia crypto hash validate argon2 \
  --password 'codespartan123' \
  --hash '$argon2id$v=19$m=65536,t=3,p=4$...'

# 3. Redis funciona?
docker exec authelia-redis redis-cli ping
# PONG
```

---

### MFA No Se Configura

**Síntoma**: No aparece QR code para MFA

**Verificar TOTP config**:
```bash
docker exec authelia cat /config/configuration.yml | grep -A 5 "totp:"
```

**Debe tener**:
```yaml
totp:
  disable: false  # ⚠️ Si está en true, MFA no funciona
  issuer: mambo-cloud.com
```

---

### Sesión Expira Inmediatamente

**Verificar**:
```bash
# 1. Redis funciona?
docker logs authelia-redis --tail 20

# 2. Authelia conecta a Redis?
docker logs authelia | grep -i redis
```

**Debe mostrar**:
```
Configuration: session: provider: redis: successfully connected
```

---

### Dashboards No Redirigen

**Síntoma**: Dashboards muestran login propio en vez de redirigir a Authelia

**Verificar middleware**:
```bash
# 1. Traefik tiene el middleware?
docker logs traefik | grep -i "authelia@docker"

# 2. Router usa el middleware?
docker exec traefik cat /etc/traefik/dynamic-config.yml
```

**Solución**:
```bash
# Restart Traefik para recargar middlewares
cd /opt/codespartan/platform/traefik
docker compose restart traefik
```

---

### Grafana No Auto-Login

**Síntoma**: Tras login en Authelia, Grafana pide login separado

**Verificar Auth Proxy**:
```bash
docker exec grafana env | grep GF_AUTH_PROXY
```

**Debe mostrar**:
```
GF_AUTH_PROXY_ENABLED=true
GF_AUTH_PROXY_HEADER_NAME=Remote-User
```

**Si falta**, añadir a docker-compose.yml y recrear:
```bash
docker compose up -d --force-recreate grafana
```

---

## Workflows de Gestión

### Deploy/Update Authelia

```bash
# Opción 1: GitHub Actions (recomendado)
gh workflow run deploy-authelia.yml

# Opción 2: Manual
cd /opt/codespartan/platform/authelia
docker compose pull
docker compose down
docker compose up -d --force-recreate
```

---

### Añadir Nuevo Usuario

1. Generar hash de contraseña:
```bash
docker exec -it authelia authelia crypto hash generate argon2 \
  --password 'contraseña_del_nuevo_usuario'
```

2. Editar `users_database.yml`:
```yaml
users:
  nuevo_usuario:
    displayname: "Nombre Completo"
    password: "$argon2id$v=19$m=65536,t=3,p=4$HASH_GENERADO"
    email: usuario@mambo-cloud.com
    groups:
      - dev  # Sin acceso a dashboards admin
```

3. Copiar al VPS:
```bash
scp users_database.yml leonidas@91.98.137.217:/opt/codespartan/platform/authelia/
```

4. Recrear Authelia:
```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/platform/authelia
docker compose down
docker compose up -d --force-recreate
```

---

### Resetear MFA de Usuario

Si un usuario pierde acceso a su dispositivo MFA:

1. Editar `/opt/codespartan/platform/authelia/users_database.yml`
2. Eliminar configuración TOTP del usuario (si existe)
3. Recrear Authelia
4. Usuario deberá configurar MFA nuevamente en próximo login

---

### Ver Sesiones Activas

```bash
# Conectar a Redis
docker exec -it authelia-redis redis-cli

# Listar todas las sesiones
KEYS authelia:session:*

# Ver detalles de sesión
GET authelia:session:SESSION_ID
```

---

### Invalidar Todas las Sesiones

```bash
# Útil si se compromete session.secret
docker exec -it authelia-redis redis-cli FLUSHALL
docker compose restart authelia
```

---

## Próximos Pasos

- [ ] Cambiar `session.secret` y `jwt_secret` a valores seguros (>32 chars)
- [ ] Configurar SMTP para notificaciones por email
- [ ] Considerar PostgreSQL en vez de SQLite para >100 usuarios
- [ ] Implementar backup automático de `users_database.yml`
- [ ] Configurar múltiples dominios si es necesario
- [ ] Revisar logs periódicamente para intentos de brute-force

---

## Referencias

- **Documentación oficial Authelia**: https://www.authelia.com/
- **Traefik ForwardAuth**: https://doc.traefik.io/traefik/middlewares/http/forwardauth/
- **Grafana Auth Proxy**: https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/auth-proxy/
- **Argon2 Password Hashing**: https://github.com/P-H-C/phc-winner-argon2

---

**Documentación generada**: 2025-11-15
**Autor**: Claude Code
**Versión**: 1.0
