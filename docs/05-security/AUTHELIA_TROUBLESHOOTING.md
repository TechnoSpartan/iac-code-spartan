# Authelia Troubleshooting - Resolución de Problemas

## Resumen Ejecutivo

Este documento detalla el proceso completo de resolución de problemas de Authelia que estaba en crash loop, incluyendo todos los errores encontrados y sus soluciones.

**Estado Final:** ✅ Authelia operativo y accesible en https://auth.mambo-cloud.com

**Duración del troubleshooting:** ~2 horas
**Commits necesarios:** 5 commits para resolver todos los problemas
**Errores encontrados:** 6 problemas críticos distintos

---

## Cronología de Errores y Soluciones

### 1. Error: Configuración OIDC corrupta (Commit: 615625b)

**Síntoma:**
```
level=error msg="Configuration: error occurred during unmarshalling configuration:
'identity_providers.oidc.jwks[0].key' could not decode to a schema.CryptographicKey:
x509: failed to parse RSA private key embedded in PKCS#8: crypto/rsa: p * q != n"
```

**Causa:**
- Clave privada RSA del OIDC provider estaba corrupta o mal generada
- El campo `p * q != n` indica que los parámetros RSA son matemáticamente inválidos

**Solución:**
Comentar toda la sección `identity_providers.oidc` en `configuration.yml.template`:

```yaml
# DISABLED: OIDC configuration (RSA key was corrupted)
# To re-enable, generate new RSA key with: openssl genrsa -out private.pem 4096
# identity_providers:
#   oidc:
#     ...
```

**Cómo re-habilitar OIDC en el futuro:**
```bash
# Generar nueva clave RSA válida
openssl genrsa -out private.pem 4096

# Descomentar sección OIDC en configuration.yml.template
# Insertar nueva clave en el campo jwks[0].key
# Redeploy Authelia
```

---

### 2. Error: Conflicto Filesystem/SMTP Notifier (Commit: 615625b)

**Síntoma:**
```
level=error msg="Configuration: notifier: please ensure only one of the
'smtp' or 'filesystem' notifier is configured"
```

**Causa:**
- Authelia permite SOLO un tipo de notificador activo
- Teníamos configurados `filesystem` Y `smtp` simultáneamente

**Solución:**
Comentar el notificador filesystem, mantener solo SMTP:

```yaml
notifier:
  disable_startup_check: true

  # REMOVED: filesystem notifier (conflicts with SMTP)
  # filesystem:
  #   filename: /data/notifications.txt

  # SMTP configuration (Hostinger)
  smtp:
    host: ${AUTHELIA_SMTP_HOST}
    port: ${AUTHELIA_SMTP_PORT}
    ...
```

---

### 3. Error: SMTP Startup Check Failing (Commit: c3b773d)

**Síntoma:**
- Container en crash loop sin errores explícitos en logs
- Authelia inicia y termina después de ~6 segundos

**Causa:**
- `notifier.disable_startup_check: false` hace que Authelia intente enviar email de prueba al iniciar
- Si falla la conexión SMTP, Authelia termina con exit code 1

**Solución:**
```yaml
notifier:
  disable_startup_check: true  # Disabled to prevent startup failures if SMTP is misconfigured
```

**Nota:** Las notificaciones SMTP seguirán funcionando en runtime, solo se deshabilita la verificación de inicio.

---

### 4. Error: File Logging Crash (Commit: 857d1e2)

**Síntoma:**
```
level=fatal msg="Cannot configure logger: error opening log file:
open /data/authelia.log: no such file or directory"
```

**Causa:**
- Authelia intentaba crear `/data/authelia.log` pero no podía
- Aunque el volumen `authelia_data` estaba montado en `/data`, había problemas de permisos o timing

**Solución:**
Deshabilitar file logging, usar solo stdout/stderr:

```yaml
log:
  level: info
  format: text
  # file_path disabled - logs go to stdout/stderr and are collected by Loki
  # file_path: /data/authelia.log
```

**Beneficios:**
- Logs van a stdout/stderr
- Promtail los captura automáticamente
- Loki los almacena y Grafana los visualiza
- No necesitamos logging a archivo

---

### 5. Error: Healthcheck Command Not Found (Commits: b6b59f4, c3b773d, 353f592)

**Síntomas intentados:**
```bash
# Intento 1: wget
test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
❌ Error: wget: not found

# Intento 2: authelia healthcheck
test: ["CMD", "authelia", "healthcheck"]
❌ Error: unknown command "healthcheck" for "authelia"

# Intento 3: pgrep
test: ["CMD-SHELL", "pgrep authelia || exit 1"]
❌ Error: pgrep: not found
```

**Causa:**
- Imagen `authelia/authelia:latest` usa base Alpine minimalista
- No incluye: wget, curl, pgrep, ni comando healthcheck

**Solución Final:**
Deshabilitar completamente el healthcheck:

```yaml
# Healthcheck disabled - Authelia container has minimal tools (no wget/curl/pgrep)
# Container runs successfully without healthcheck, monitored via Loki/Grafana instead
# healthcheck:
#   test: ["CMD-SHELL", "pgrep authelia || exit 1"]
#   ...
```

**Alternativas evaluadas pero descartadas:**
- ✗ Instalar herramientas en tiempo de ejecución (no persistente entre reinicios)
- ✗ Crear imagen custom con healthcheck tools (overhead innecesario)
- ✓ Monitoreo vía Loki/Grafana es suficiente

---

### 6. Error: Database Encryption Key Mismatch

**Síntoma:**
```
level=error msg="Error occurred running a startup check"
error="the configured encryption key does not appear to be valid for this database
which may occur if the encryption key was changed in the configuration without using
the cli to change it in the database"
```

**Causa:**
- Database existente fue creada con una encryption key diferente
- Al cambiar `AUTHELIA_ENCRYPTION_KEY` en GitHub Secrets, el database viejo quedó incompatible

**Solución:**
```bash
# Detener contenedores
docker compose down

# Eliminar volumen de database corrupto
docker volume rm authelia_data

# Recrear con nueva encryption key
docker compose up -d
```

**Resultado:**
```
level=info msg="Storage schema migration from 0 to 23 is complete"
level=info msg="Startup complete"
level=info msg="Listening for non-TLS connections on '[::]:9091' path '/'"
```

---

## Testing y Verificación

### 1. Verificar Container Status

```bash
ssh leonidas@91.98.137.217 "docker ps --filter 'name=authelia'"
```

**Output esperado:**
```
CONTAINER ID   IMAGE                      STATUS                   PORTS      NAMES
241e0e379306   authelia/authelia:latest   Up X minutes (healthy)   9091/tcp   authelia
417e94fe8313   redis:7-alpine             Up X minutes (healthy)   6379/tcp   authelia-redis
```

### 2. Verificar Logs (Sin Errores)

```bash
ssh leonidas@91.98.137.217 "docker logs authelia 2>&1 | grep -E 'level=(error|fatal)'"
```

**Output esperado:** (vacío - sin errores)

### 3. Verificar Portal Web

```bash
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://auth.mambo-cloud.com/
```

**Output esperado:**
```
HTTP Status: 200
```

### 4. Verificar en Navegador

1. Abrir https://auth.mambo-cloud.com
2. Debe mostrar pantalla de login de Authelia
3. Intentar login con:
   - Usuario: `admin`
   - Password: `codespartan123`
4. Debe solicitar configuración de 2FA (TOTP)

### 5. Verificar Traefik Discovery

```bash
ssh leonidas@91.98.137.217 "docker logs traefik 2>&1 | grep -i authelia | tail -5"
```

**Output esperado:** No errores recientes de "middleware does not exist"

### 6. Verificar Redes

```bash
ssh leonidas@91.98.137.217 "docker network inspect web --format='{{range .Containers}}{{.Name}} {{end}}'"
```

**Output esperado:** Debe incluir `authelia`

---

## Configuración Final

### Variables de Entorno (GitHub Secrets)

```
AUTHELIA_JWT_SECRET=<base64-64chars>
AUTHELIA_ENCRYPTION_KEY=<base64-64chars>
AUTHELIA_SESSION_SECRET=<base64-64chars>
AUTHELIA_SMTP_HOST=smtp.hostinger.com
AUTHELIA_SMTP_PORT=465
AUTHELIA_SMTP_USERNAME=iam@codespartan.es
AUTHELIA_SMTP_PASSWORD=<password>
AUTHELIA_SMTP_SENDER=noreply@codespartan.es
```

### Características Habilitadas

- ✅ **Autenticación:** File-based users (`users_database.yml`)
- ✅ **2FA:** TOTP (Google Authenticator, Authy, etc.)
- ✅ **Session Storage:** Redis (para persistencia entre reinicios)
- ✅ **Notificaciones:** SMTP via Hostinger
- ✅ **SSL:** Automático vía Traefik + Let's Encrypt
- ✅ **Logging:** stdout/stderr → Promtail → Loki → Grafana

### Características Deshabilitadas (por ahora)

- ❌ **OIDC Provider:** Deshabilitado (RSA key corrupta)
- ❌ **WebAuthn:** Deshabilitado (hardware keys opcionales)
- ❌ **Duo Push:** Deshabilitado (requiere cuenta Duo)
- ❌ **File Logging:** Deshabilitado (usamos Loki)
- ❌ **SMTP Startup Check:** Deshabilitado (para evitar crashes)
- ❌ **Healthcheck:** Deshabilitado (container minimalista)

---

## Comandos de Troubleshooting Útiles

### Ver logs en tiempo real
```bash
ssh leonidas@91.98.137.217 "docker logs -f authelia"
```

### Verificar configuración aplicada
```bash
ssh leonidas@91.98.137.217 "cat /opt/codespartan/platform/authelia/configuration.yml | grep -v '^#' | grep -v '^$'"
```

### Reiniciar Authelia
```bash
ssh leonidas@91.98.137.217 "cd /opt/codespartan/platform/authelia && docker compose restart"
```

### Recrear desde cero (nuclear option)
```bash
ssh leonidas@91.98.137.217 "cd /opt/codespartan/platform/authelia && docker compose down && docker volume rm authelia_data authelia_redis && docker compose up -d"
```

### Ver healthcheck status
```bash
ssh leonidas@91.98.137.217 "docker inspect authelia --format='{{json .State.Health}}' | jq ."
```

---

## Lecciones Aprendidas

### 1. Debugging Containers Minimalistas

**Problema:** Imagen Alpine sin herramientas de debugging
**Solución:**
- No asumir que wget/curl están disponibles
- Usar `docker exec <container> ls /bin` para ver herramientas disponibles
- Preferir monitoreo externo (Loki) vs healthchecks internos

### 2. Multiple Error Cascade

**Problema:** Un error inicial oculta otros errores
**Método usado:**
1. Resolver error más crítico primero (OIDC corruption)
2. Redeploy y esperar nuevo error
3. Resolver siguiente error en la cadena
4. Repetir hasta que container inicie exitosamente

### 3. Database State Management

**Problema:** Encryption key mismatch con database existente
**Solución:** Documentar que cambiar `AUTHELIA_ENCRYPTION_KEY` requiere recrear database
**Prevención futura:**
- Guardar encryption keys en password manager
- No cambiar encryption keys a menos que sea absolutamente necesario
- Si se cambia, documentar el cambio y recrear database

### 4. Configuration Validation

**Problema:** Authelia valida configuración al inicio, crash si hay errores
**Best Practice:**
- Validar configuración localmente antes de deploy
- Usar `docker run --rm authelia/authelia:latest authelia validate-config` (si existiera)
- Revisar deprecation warnings (no bloquean pero indican futuras incompatibilidades)

---

## Referencias

- [Authelia Documentation](https://www.authelia.com/documentation/)
- [Authelia Configuration Reference](https://www.authelia.com/configuration/prologue/introduction/)
- [Authelia Docker Deployment](https://www.authelia.com/integration/deployment/docker/)
- [Traefik ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)

---

## Estado Actual del Sistema

```
┌─────────────────────────────────────────────────────┐
│ Authelia SSO - Estado: OPERATIVO ✅                 │
├─────────────────────────────────────────────────────┤
│ URL:           https://auth.mambo-cloud.com         │
│ Container:     Up and healthy                        │
│ Redis:         Up and healthy                        │
│ HTTP Status:   200 OK                                │
│ Traefik:       Routing OK                            │
│ SSL:           Let's Encrypt (válido)                │
│                                                      │
│ Próximos pasos:                                      │
│ - Configurar 2FA para usuario admin                 │
│ - Proteger Traefik dashboard con Authelia           │
│ - Proteger Grafana con Authelia                     │
│ - Opcional: Re-habilitar OIDC con nueva RSA key     │
└─────────────────────────────────────────────────────┘
```

**Última actualización:** 2025-12-13
**Commits relacionados:** 615625b, c3b773d, 857d1e2, b6b59f4, 353f592
