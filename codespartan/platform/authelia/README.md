# Authelia SSO - Mambo Cloud Platform

Single Sign-On y autenticación de dos factores para todos los dashboards de la plataforma.

## 🔐 Credenciales

```
URL (mambo-cloud):     https://auth.mambo-cloud.com
URL (codespartan.cloud): https://auth.codespartan.cloud   # CRM y futuros hosts *.codespartan.cloud
Usuario: admin
Contraseña: ver password manager (rotada vía secret AUTHELIA_ADMIN_PASSWORD_HASH, no vive en el repo)
MFA: Configurar en primer login (Google Authenticator)
```

### Multi-domain (cookie scope)

Authelia v4 exige que cada `session.cookies[].authelia_url` comparta eTLD+1 con su `domain`.
Por eso hay **dos portales** y **dos middlewares** ForwardAuth:

| Cookie domain | Portal | Middleware Traefik | Ejemplo protegido |
|---|---|---|---|
| `mambo-cloud.com` | `auth.mambo-cloud.com` | `authelia@docker` | grafana, traefik, portainer |
| `codespartan.cloud` | `auth.codespartan.cloud` | `authelia-codespartan@docker` | `crm.codespartan.cloud` |

DNS: el subdominio `auth` debe existir en **ambos** dominios (Terraform `subdomains` incluye `auth`).
Tras cambiar cookies/config: siempre `docker compose up -d --force-recreate` (no hay hot-reload).

## 🚀 Quick Start

### Deploy
```bash
# Vía GitHub Actions (recomendado)
gh workflow run deploy-authelia.yml

# Manual
docker compose up -d
```

### Verificar
```bash
# Health check
docker inspect --format='{{.State.Health.Status}}' authelia
# healthy

# Test URL
curl -I https://auth.mambo-cloud.com
# HTTP/2 200

# Test redirección
curl -I https://traefik.mambo-cloud.com
# HTTP/2 302 → redirige a auth.mambo-cloud.com
```

## 📁 Archivos

- `configuration.yml.template` / `users_database.yml.template` - Plantillas versionadas; los `.yml` reales
  se generan en cada deploy (`deploy-authelia.yml`) sustituyendo secretos de GitHub y NUNCA se commitean
  (ver `.gitignore`).
- `docker-compose.yml` - Deployment (Authelia + Redis)
- `deploy.sh` - Script de deployment manual (deprecado, usar workflow)

## 🔧 Configuración

`users_database.yml` se genera en cada deploy a partir de `users_database.yml.template`
(placeholders `${AUTHELIA_ADMIN_PASSWORD_HASH}` / `${AUTHELIA_ADMIN_EMAIL}`), sustituidos con
GitHub Secrets vía `envsubst` — nunca se edita el archivo directamente en el VPS ni se commitea
el real. **No reutilices una contraseña que haya estado expuesta en el repo o en logs.**

### Rotar la contraseña de `admin`

1. Genera una contraseña fuerte y su hash localmente (nunca por un log de CI en un repo público):
   ```bash
   NEW_PW=$(openssl rand -hex 16)
   docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$NEW_PW"
   echo "Nueva contraseña (guárdala en tu password manager): $NEW_PW"
   ```
2. Actualiza el secret (esto no imprime el valor en ningún log):
   ```bash
   gh secret set AUTHELIA_ADMIN_PASSWORD_HASH --repo TechnoSpartan/iac-code-spartan --body '<hash generado>'
   ```
3. Dispara el redeploy, que regenera `users_database.yml` desde la plantilla con el hash nuevo:
   ```bash
   gh workflow run deploy-authelia.yml --repo TechnoSpartan/iac-code-spartan
   ```

### Añadir otro usuario

Genera su hash igual que arriba, añade un nuevo bloque `${AUTHELIA_OTRO_USUARIO_HASH}` a
`users_database.yml.template`, crea el secret correspondiente, y añade la variable al
`envsubst`/`env:` de `deploy-authelia.yml`.

### Políticas de Acceso

Editadas en `configuration.yml`:

```yaml
access_control:
  rules:
    - domain: traefik.mambo-cloud.com
      policy: two_factor  # Requiere MFA
      subject:
        - "group:admins"  # Solo grupo admins
```

## 🌐 Servicios Protegidos

- ✅ Traefik Dashboard
- ✅ Grafana
- ✅ Backoffice

Todos redirigen a https://auth.mambo-cloud.com para login.

## 🐛 Troubleshooting

### Authelia no responde (HTTP 504)

```bash
# Verificar estado
docker ps | grep authelia
docker logs authelia --tail 50

# Recrear container
docker compose down
docker compose up -d --force-recreate

# Restart Traefik para detectar middleware
cd ../traefik
docker compose restart traefik
```

### Login no funciona

```bash
# Verificar que la contraseña que estás probando coincide con el hash desplegado
# (sustituye <tu-contraseña> y <hash-en-users_database.yml> — nunca commitees el resultado)
docker exec authelia authelia crypto hash validate argon2 \
  --password '<tu-contraseña>' \
  --hash '<hash-en-users_database.yml>'

# Verificar Redis
docker exec authelia-redis redis-cli ping
# PONG

# Ver logs
docker logs authelia | grep -i error
```

### Dashboards no redirigen

```bash
# Restart Traefik
cd ../traefik
docker compose restart traefik

# Verificar middleware
docker logs traefik | grep -i authelia
```

## 📚 Documentación Completa

Ver `docs/05-security/AUTHELIA.md` para:
- Arquitectura detallada
- Problemas encontrados y soluciones
- Lecciones aprendidas
- Tests completos
- Gestión avanzada

## 🔒 Seguridad

**IMPORTANTE**: Esta configuración usa secretos de desarrollo. En producción:

1. Cambiar `session.secret` en configuration.yml (>32 chars aleatorios)
2. Cambiar `jwt_secret` en configuration.yml (>32 chars aleatorios)
3. Cambiar `encryption_key` en configuration.yml (>20 chars aleatorios)
4. Usar contraseñas fuertes para usuarios
5. Habilitar SMTP para notificaciones
6. Considerar PostgreSQL en vez de SQLite

## 📊 Monitoreo

```bash
# Ver sesiones activas
docker exec -it authelia-redis redis-cli
KEYS authelia:session:*

# Ver intentos de login
docker logs authelia | grep -i "authentication\|login"

# Ver usuarios bloqueados (brute-force)
docker logs authelia | grep -i "banned\|regulation"
```

---

**Última actualización**: 2025-11-15
**Versión**: FASE 2 completada
