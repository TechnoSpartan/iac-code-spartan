# 🔐 Secret Inventory & Migration Plan

**Fecha**: 2025-12-08
**Estado**: 📋 Planning → 🔄 In Progress

---

## 📊 Secretos Identificados

### 1. **Authelia Authentication**

#### Hardcodeados en: `configure-smtp.yml` (líneas 87, 150, 169)

| Secreto | Valor Actual | Acción |
|---------|--------------|--------|
| `AUTHELIA_JWT_SECRET` | `insecure_jwt_secret_please_change_in_production` | ⚠️ CAMBIAR + Migrar a GitHub Secret |
| `AUTHELIA_ENCRYPTION_KEY` | `insecure_encryption_key` | ⚠️ CAMBIAR + Migrar a GitHub Secret |
| `AUTHELIA_SESSION_SECRET` | (no existe actualmente) | ✨ GENERAR + Agregar a GitHub Secret |

**Riesgo**: 🔴 CRÍTICO - Estos secrets permiten descifrar sesiones y tokens JWT

---

### 2. **Authelia SMTP (Hostinger)**

#### Hardcodeados en: `configure-smtp.yml` (líneas 165-179)

| Secreto | Valor Actual | Acción |
|---------|--------------|--------|
| `AUTHELIA_SMTP_HOST` | `smtp.hostinger.com` | ✅ OK - No es sensible, pero parametrizar |
| `AUTHELIA_SMTP_PORT` | `465` | ✅ OK - No es sensible |
| `AUTHELIA_SMTP_USERNAME` | `iam@codespartan.es` | ⚠️ Migrar a GitHub Secret |
| `AUTHELIA_SMTP_PASSWORD` | `Codespartan$2` | 🔴 CRÍTICO - Migrar a GitHub Secret |
| `AUTHELIA_SMTP_SENDER` | `noreply@codespartan.es` | ✅ OK - No es sensible |
| `AUTHELIA_SMTP_STARTUP_CHECK` | `iam@codespartan.es` | ✅ OK - No es sensible |

**Riesgo**: 🔴 CRÍTICO - Password SMTP expuesto permite envío de emails arbitrarios

**Archivo afectado**: `.github/workflows/configure-smtp.yml`

---

### 3. **Authelia Users Database**

#### Hardcodeados en: `codespartan/platform/authelia/users_database.yml`

| Secreto | Valor Actual | Acción |
|---------|--------------|--------|
| `AUTHELIA_ADMIN_PASSWORD_HASH` | `$argon2id$v=19$m=65536...` (password: codespartan123) | ⚠️ Mantener hash, documentar rotación |

**Riesgo**: 🟡 MEDIO - Hash argon2id es seguro, pero password debe cambiarse

**Nota**: El hash NO necesita migración (ya está seguro), pero documentar cómo rotarlo.

---

### 4. **MongoDB (TrackWorks/Cyberdyne API)**

#### Hardcodeados en: `codespartan/apps/cyberdyne-systems-es/api/docker-compose.yml` (líneas 8, 40)

| Secreto | Valor Actual | Acción |
|---------|--------------|--------|
| `MONGODB_ROOT_USERNAME` | `truckworks` | ⚠️ Migrar a GitHub Secret |
| `MONGODB_ROOT_PASSWORD` | `truckworks_secure_password_2025` | 🔴 CRÍTICO - Migrar a GitHub Secret |
| `MONGODB_DATABASE` | `trackworks` | ✅ OK - No es sensible |

**Riesgo**: 🔴 CRÍTICO - Password hardcodeado permite acceso completo a base de datos

**Archivo afectado**: `codespartan/apps/cyberdyne-systems-es/api/docker-compose.yml`

---

### 5. **Redmine (Codespartan Cloud)**

#### Ya migrados a GitHub Secrets ✅

| Secreto | Estado |
|---------|--------|
| `REDMINE_POSTGRES_PASSWORD` | ✅ Ya está en GitHub Secrets |
| `REDMINE_SECRET_KEY_BASE` | ✅ Ya está en GitHub Secrets |
| `REDMINE_SMTP_PASSWORD` | ✅ Ya está en GitHub Secrets |

**Estado**: ✅ COMPLETADO - No requiere acción

---

### 6. **Backups (Restic + AWS S3)**

#### Ya migrados a GitHub Secrets ✅

| Secreto | Estado |
|---------|--------|
| `AWS_ACCESS_KEY_ID` | ✅ Ya está en GitHub Secrets |
| `AWS_SECRET_ACCESS_KEY` | ✅ Ya está en GitHub Secrets |
| `RESTIC_PASSWORD` | ✅ Ya está en GitHub Secrets |
| `RESTIC_REPOSITORY` | ✅ Ya está en GitHub Secrets |

**Estado**: ✅ COMPLETADO - No requiere acción

---

### 7. **Infrastructure (Terraform)**

#### Ya migrados a GitHub Secrets ✅

| Secreto | Estado |
|---------|--------|
| `HCLOUD_TOKEN` | ✅ Ya está en GitHub Secrets |
| `TF_VAR_hetzner_dns_token` | ✅ Ya está en GitHub Secrets |
| `VPS_SSH_HOST` | ✅ Ya está en GitHub Secrets |
| `VPS_SSH_USER` | ✅ Ya está en GitHub Secrets |
| `VPS_SSH_KEY` | ✅ Ya está en GitHub Secrets |

**Estado**: ✅ COMPLETADO - No requiere acción

---

### 8. **GitHub Container Registry**

#### Usado en workflows ✅

| Secreto | Estado |
|---------|--------|
| `GHCR_TOKEN` | ✅ Ya está en GitHub Secrets (usado en deploy-cyberdyne.yml) |

**Estado**: ✅ COMPLETADO - No requiere acción

---

## 🎯 Plan de Migración

### Fase 1: Generar Secretos Seguros (15 min)

```bash
# 1. JWT Secret (mínimo 32 caracteres)
openssl rand -base64 32

# 2. Encryption Key (mínimo 32 caracteres)
openssl rand -base64 32

# 3. Session Secret (64 caracteres recomendado)
openssl rand -base64 48

# 4. MongoDB Password (32 caracteres alfanumérico)
openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c32
```

### Fase 2: Crear GitHub Secrets (10 min)

Ir a: `https://github.com/TechnoSpartan/iac-code-spartan/settings/secrets/actions`

**Authelia SMTP:**
```
AUTHELIA_SMTP_HOST=smtp.hostinger.com
AUTHELIA_SMTP_PORT=465
AUTHELIA_SMTP_USERNAME=iam@codespartan.es
AUTHELIA_SMTP_PASSWORD=<password_real_de_hostinger>
AUTHELIA_SMTP_SENDER=noreply@codespartan.es
```

**Authelia Security:**
```
AUTHELIA_JWT_SECRET=<generado_con_openssl>
AUTHELIA_ENCRYPTION_KEY=<generado_con_openssl>
AUTHELIA_SESSION_SECRET=<generado_con_openssl>
```

**TrackWorks MongoDB:**
```
TRACKWORKS_MONGODB_USERNAME=truckworks
TRACKWORKS_MONGODB_PASSWORD=<generar_nuevo_password_seguro>
TRACKWORKS_MONGODB_DATABASE=trackworks
```

### Fase 3: Crear Templates (30 min)

#### 3.1 Template Authelia Configuration

Crear: `codespartan/platform/authelia/configuration.yml.template`

```yaml
# Usar variables de entorno en lugar de hardcodear
identity_validation:
  reset_password:
    jwt_secret: ${AUTHELIA_JWT_SECRET}

storage:
  encryption_key: ${AUTHELIA_ENCRYPTION_KEY}

notifier:
  smtp:
    host: ${AUTHELIA_SMTP_HOST}
    port: ${AUTHELIA_SMTP_PORT}
    username: ${AUTHELIA_SMTP_USERNAME}
    password: ${AUTHELIA_SMTP_PASSWORD}
    sender: ${AUTHELIA_SMTP_SENDER}
```

#### 3.2 Template MongoDB Docker Compose

Crear: `codespartan/apps/cyberdyne-systems-es/api/.env.example`

```bash
# MongoDB Credentials
MONGODB_ROOT_USERNAME=truckworks
MONGODB_ROOT_PASSWORD=change_me_in_production
MONGODB_DATABASE=trackworks

# API Configuration
NODE_ENV=production
PORT=3001
API_VERSION=v1
```

Actualizar: `docker-compose.yml` para usar `.env` file:

```yaml
services:
  mongodb:
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${MONGODB_ROOT_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGODB_ROOT_PASSWORD}
      - MONGO_INITDB_DATABASE=${MONGODB_DATABASE}

  api:
    environment:
      - MONGODB_URI=mongodb://${MONGODB_ROOT_USERNAME}:${MONGODB_ROOT_PASSWORD}@mongodb:27017/${MONGODB_DATABASE}?authSource=admin
```

### Fase 4: Actualizar Workflows (1-2 horas)

#### 4.1 Eliminar `configure-smtp.yml`

Este workflow tiene TODOS los secretos hardcodeados. Eliminarlo y reemplazar con deployment que use secrets.

#### 4.2 Crear nuevo `deploy-authelia.yml`

```yaml
- name: Create Authelia configuration from template
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.VPS_SSH_HOST }}
    username: ${{ secrets.VPS_SSH_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    envs: AUTHELIA_JWT_SECRET,AUTHELIA_ENCRYPTION_KEY,AUTHELIA_SMTP_HOST,AUTHELIA_SMTP_PORT,AUTHELIA_SMTP_USERNAME,AUTHELIA_SMTP_PASSWORD,AUTHELIA_SMTP_SENDER
    script: |
      # Copy template
      sudo cp /opt/codespartan/platform/authelia/configuration.yml.template /tmp/authelia_config.yml

      # Replace variables with envsubst
      export AUTHELIA_JWT_SECRET="${AUTHELIA_JWT_SECRET}"
      export AUTHELIA_ENCRYPTION_KEY="${AUTHELIA_ENCRYPTION_KEY}"
      export AUTHELIA_SMTP_HOST="${AUTHELIA_SMTP_HOST}"
      export AUTHELIA_SMTP_PORT="${AUTHELIA_SMTP_PORT}"
      export AUTHELIA_SMTP_USERNAME="${AUTHELIA_SMTP_USERNAME}"
      export AUTHELIA_SMTP_PASSWORD="${AUTHELIA_SMTP_PASSWORD}"
      export AUTHELIA_SMTP_SENDER="${AUTHELIA_SMTP_SENDER}"

      envsubst < /tmp/authelia_config.yml > /opt/codespartan/platform/authelia/configuration.yml

      # Restart Authelia
      cd /opt/codespartan/platform/authelia
      docker compose restart authelia
```

#### 4.3 Actualizar `deploy-cyberdyne.yml`

Agregar paso para crear `.env` file:

```yaml
- name: Create .env file from secrets
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.VPS_SSH_HOST }}
    username: ${{ secrets.VPS_SSH_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    envs: TRACKWORKS_MONGODB_USERNAME,TRACKWORKS_MONGODB_PASSWORD,TRACKWORKS_MONGODB_DATABASE
    script: |
      cat > /opt/codespartan/apps/cyberdyne-systems-es/api/.env << EOF
      MONGODB_ROOT_USERNAME=${TRACKWORKS_MONGODB_USERNAME}
      MONGODB_ROOT_PASSWORD=${TRACKWORKS_MONGODB_PASSWORD}
      MONGODB_DATABASE=${TRACKWORKS_MONGODB_DATABASE}
      NODE_ENV=production
      PORT=3001
      API_VERSION=v1
      EOF
```

### Fase 5: Actualizar .gitignore (5 min)

Asegurar que archivos con secretos NO se commiteen:

```bash
# Secrets and credentials
.env
.env.local
.env.*.local
*.pem
*.key
*_rsa
*_dsa
*_ecdsa
*_ed25519

# Authelia generated config (only template should be in git)
codespartan/platform/authelia/configuration.yml

# Backup sensitive files
*.backup
*.bak
*-backup

# Terraform state files (may contain secrets)
*.tfstate
*.tfstate.*
```

### Fase 6: Testing (30 min)

1. **Test Authelia con nuevos secrets:**
   ```bash
   gh workflow run deploy-authelia.yml
   ```

2. **Verificar SMTP funciona:**
   - Ir a https://auth.mambo-cloud.com
   - Intentar reset password
   - Verificar email llega

3. **Test MongoDB con nuevo password:**
   ```bash
   gh workflow run deploy-cyberdyne.yml
   ```

4. **Verificar API conecta:**
   ```bash
   curl https://api.cyberdyne-systems.es/api/v1/health
   ```

### Fase 7: Cleanup (15 min)

1. **Eliminar workflows con secrets hardcodeados:**
   - `configure-smtp.yml` → Eliminar completamente
   - `debug-authelia-login.yml` → Eliminar (usa password hardcodeado)
   - `generate-new-password.yml` → Actualizar para NO tener password hardcodeado
   - `verify-authelia-password.yml` → Actualizar para usar secret

2. **Eliminar comentarios con passwords:**
   ```bash
   # En users_database.yml eliminar:
   # Password: codespartan123
   ```

3. **Git history cleanup (OPCIONAL pero recomendado):**
   ```bash
   # WARNING: Esto reescribe historia de Git
   # Solo hacer si secretos en workflows son realmente sensibles
   git filter-repo --path .github/workflows/configure-smtp.yml --invert-paths
   ```

---

## 📝 Checklist de Migración

### Pre-requisitos
- [ ] Backup completo del sistema (`/opt/codespartan/scripts/backup.sh`)
- [ ] Acceso a cuenta de email SMTP (Hostinger)
- [ ] Permisos de administrador en GitHub repo

### Fase 1: Preparación
- [ ] Generar JWT secret con `openssl rand -base64 32`
- [ ] Generar encryption key con `openssl rand -base64 32`
- [ ] Generar session secret con `openssl rand -base64 48`
- [ ] Generar nuevo MongoDB password con `openssl rand -base64 24`

### Fase 2: GitHub Secrets
- [ ] Crear `AUTHELIA_JWT_SECRET`
- [ ] Crear `AUTHELIA_ENCRYPTION_KEY`
- [ ] Crear `AUTHELIA_SESSION_SECRET`
- [ ] Crear `AUTHELIA_SMTP_HOST`
- [ ] Crear `AUTHELIA_SMTP_PORT`
- [ ] Crear `AUTHELIA_SMTP_USERNAME`
- [ ] Crear `AUTHELIA_SMTP_PASSWORD`
- [ ] Crear `AUTHELIA_SMTP_SENDER`
- [ ] Crear `TRACKWORKS_MONGODB_USERNAME`
- [ ] Crear `TRACKWORKS_MONGODB_PASSWORD`
- [ ] Crear `TRACKWORKS_MONGODB_DATABASE`

### Fase 3: Templates
- [ ] Crear `configuration.yml.template` para Authelia
- [ ] Crear `.env.example` para Cyberdyne API
- [ ] Actualizar `docker-compose.yml` para usar variables de entorno

### Fase 4: Workflows
- [ ] Crear nuevo `deploy-authelia.yml` con secrets
- [ ] Actualizar `deploy-cyberdyne.yml` para crear `.env` file
- [ ] Test deploy de Authelia
- [ ] Test deploy de Cyberdyne

### Fase 5: Cleanup
- [ ] Eliminar `configure-smtp.yml`
- [ ] Actualizar `.gitignore`
- [ ] Eliminar comentarios con passwords
- [ ] Git commit con cambios

### Fase 6: Verificación
- [ ] Authelia inicia correctamente
- [ ] SMTP envía emails (test password reset)
- [ ] MongoDB acepta nuevo password
- [ ] API Cyberdyne conecta a MongoDB
- [ ] Todos los workflows pasan sin errores

### Fase 7: Documentación
- [ ] Documentar ubicación de secrets en GitHub
- [ ] Documentar proceso de rotación
- [ ] Actualizar runbooks con nuevos procedimientos
- [ ] Crear guía de troubleshooting

---

## 🔄 Rotación de Secretos

### Frecuencia Recomendada

| Secreto | Frecuencia | Método |
|---------|------------|--------|
| SMTP Password | Cada 6 meses | Cambiar en Hostinger + actualizar GitHub Secret |
| JWT Secret | Cada 12 meses | Generar nuevo + actualizar GitHub Secret + redeploy |
| Encryption Key | ⚠️ **NUNCA** | Cambiar requiere re-encriptar toda la DB |
| MongoDB Password | Cada 6 meses | Actualizar en MongoDB + GitHub Secret + redeploy |
| Session Secret | Cada 6 meses | Generar nuevo + actualizar GitHub Secret + redeploy |

### Procedimiento de Rotación

```bash
# 1. Generar nuevo secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Actualizar en GitHub
gh secret set AUTHELIA_JWT_SECRET --body "$NEW_SECRET"

# 3. Redeploy servicio
gh workflow run deploy-authelia.yml

# 4. Verificar funciona
curl -I https://auth.mambo-cloud.com

# 5. Documentar en changelog
```

---

## 🚨 Incidente Response

### Si un secret se expone:

1. **Inmediato (< 5 min):**
   ```bash
   # Rotar secret comprometido
   gh secret set <SECRET_NAME> --body "$(openssl rand -base64 32)"

   # Redeploy servicio afectado
   gh workflow run deploy-<service>.yml
   ```

2. **Corto plazo (< 1 hora):**
   - Revisar logs de acceso para actividad sospechosa
   - Cambiar credenciales en servicio externo (ej: SMTP)
   - Documentar incidente

3. **Mediano plazo (< 1 día):**
   - Auditar todos los accesos recientes
   - Revisar otros secrets potencialmente comprometidos
   - Actualizar procedimientos de seguridad

---

## 📚 Referencias

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Secret Management Guide](./SECRET_MANAGEMENT.md)
- [Authelia Configuration](https://www.authelia.com/configuration/prologue/introduction/)
- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Última actualización**: 2025-12-08
**Estado**: 📋 **PLANNING COMPLETADO** → Listo para implementación
