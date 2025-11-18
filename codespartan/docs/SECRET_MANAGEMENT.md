# 🔐 Secret Management - Guía Completa

## 📋 Tabla de Contenidos

1. [GitHub Secrets + Variables de Entorno](#github-secrets--variables-de-entorno)
2. [HashiCorp Vault](#hashicorp-vault)
3. [Comparación Detallada](#comparación-detallada)
4. [Recomendaciones por Caso de Uso](#recomendaciones-por-caso-de-uso)
5. [Migración de Secretos Actuales](#migración-de-secretos-actuales)

---

## 🔑 GitHub Secrets + Variables de Entorno

### ¿Qué es?

**GitHub Secrets** es un sistema de gestión de secretos integrado en GitHub Actions que permite almacenar información sensible de forma encriptada.

**Variables de Entorno** son valores no sensibles que se pueden compartir públicamente (como nombres de servicios, URLs, etc.).

### Características

#### ✅ Ventajas

1. **Integración nativa con GitHub Actions**
   - No requiere infraestructura adicional
   - Acceso directo desde workflows con `${{ secrets.SECRET_NAME }}`
   - Encriptación automática en reposo y en tránsito

2. **Fácil de usar**
   ```yaml
   # En workflow
   env:
     DATABASE_PASSWORD: ${{ secrets.DB_PASSWORD }}
   ```

3. **Sin costo adicional** (incluido en GitHub)
   - Hasta 100 secrets por repositorio
   - Hasta 100 variables de entorno por repositorio

4. **Auditoría integrada**
   - GitHub registra quién accede a secrets
   - Logs de uso en Security tab

5. **Scope granular**
   - Secrets a nivel de repositorio
   - Secrets a nivel de organización
   - Secrets a nivel de entorno (production, staging)

#### ❌ Limitaciones

1. **Solo para GitHub Actions**
   - No se puede usar fuera de workflows
   - No accesible desde aplicaciones en runtime

2. **Sin rotación automática**
   - Debes rotar manualmente
   - No hay expiración automática

3. **Sin versionado de secretos**
   - No puedes ver historial de cambios
   - No hay rollback de secretos

4. **Límites de tamaño**
   - Máximo 64KB por secret
   - Máximo 100 secrets por repo

5. **Sin búsqueda/consulta avanzada**
   - No hay API para listar secrets
   - No hay búsqueda por tags/metadata

### Casos de Uso Ideales

✅ **Perfecto para**:
- Secrets de CI/CD (tokens de deploy, SSH keys)
- Credenciales de servicios externos usados solo en workflows
- Variables de configuración de infraestructura
- Secrets que solo se usan durante el build/deploy

❌ **No ideal para**:
- Secrets que necesitan rotación frecuente
- Secrets usados por aplicaciones en runtime
- Secrets compartidos entre múltiples sistemas
- Secrets que necesitan auditoría avanzada

### Ejemplo de Implementación

```yaml
# .github/workflows/deploy-app.yml
name: Deploy App

on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          # Secrets desde GitHub Secrets
          DB_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
          
          # Variables de entorno (no sensibles)
          APP_ENV: production
          APP_NAME: myapp
        run: |
          # Los secrets están disponibles como variables de entorno
          echo "Deploying $APP_NAME to $APP_ENV"
          # Usar $DB_PASSWORD y $API_KEY
```

**Configuración en GitHub**:
1. Settings → Secrets and variables → Actions
2. New repository secret
3. Name: `DATABASE_PASSWORD`
4. Value: `tu_contraseña_segura`
5. Add secret

---

## 🏦 HashiCorp Vault

### ¿Qué es?

**HashiCorp Vault** es una herramienta enterprise-grade para gestionar secretos, encriptación y acceso a datos sensibles. Funciona como un servicio independiente que puede desplegarse en cualquier infraestructura.

### Características

#### ✅ Ventajas

1. **Gestión avanzada de secretos**
   - Rotación automática de credenciales
   - Expiración y renovación automática
   - Versionado de secretos
   - Búsqueda y consulta avanzada

2. **Múltiples backends (engines)**
   - **KV (Key-Value)**: Secretos estáticos
   - **Database**: Rotación automática de credenciales de BD
   - **AWS/Azure/GCP**: Credenciales dinámicas de cloud
   - **PKI**: Certificados SSL/TLS
   - **Transit**: Encriptación como servicio

3. **Control de acceso granular (ACLs)**
   - Políticas de acceso por usuario/rol
   - Auditoría completa de accesos
   - Integración con LDAP, OIDC, etc.

4. **Uso en runtime**
   - Accesible desde aplicaciones en ejecución
   - SDKs para múltiples lenguajes
   - Integración con Kubernetes, Docker, etc.

5. **Alta disponibilidad**
   - Modo HA (High Availability)
   - Replicación entre datacenters
   - Backup y restore

6. **Sin límites de tamaño**
   - Soporta secretos grandes
   - Sin límite de cantidad

#### ❌ Limitaciones

1. **Requiere infraestructura**
   - Necesitas desplegar y mantener Vault
   - Consume recursos (CPU, RAM, disco)
   - Requiere backup y mantenimiento

2. **Curva de aprendizaje**
   - Más complejo que GitHub Secrets
   - Requiere conocimiento de Vault CLI/API
   - Configuración inicial más compleja

3. **Costo de operación**
   - Si usas Vault Cloud: costo mensual
   - Si auto-hosteas: recursos del servidor
   - Tiempo de mantenimiento

4. **Punto único de fallo**
   - Si Vault cae, todas las apps fallan
   - Requiere alta disponibilidad para producción

### Casos de Uso Ideales

✅ **Perfecto para**:
- Secrets que necesitan rotación automática (DB passwords)
- Secrets usados por aplicaciones en runtime
- Múltiples sistemas que comparten secretos
- Requisitos de compliance (auditoría, encriptación)
- Entornos enterprise con muchos secretos

❌ **No ideal para**:
- Proyectos pequeños/simples
- Secrets solo usados en CI/CD
- Equipos sin experiencia con Vault
- Presupuesto limitado

### Ejemplo de Implementación

```bash
# 1. Instalar Vault (en VPS o como servicio)
docker run -d --name vault \
  -p 8200:8200 \
  -v vault-data:/vault/data \
  vault:latest

# 2. Inicializar Vault
vault operator init

# 3. Desbloquear Vault
vault operator unseal

# 4. Escribir secretos
vault kv put secret/database password="my-secure-password"

# 5. Leer secretos
vault kv get secret/database
```

**Integración con GitHub Actions**:
```yaml
# .github/workflows/deploy-app.yml
- name: Get secrets from Vault
  uses: hashicorp/vault-action@v3
  with:
    url: https://vault.example.com
    method: approle
    roleId: ${{ secrets.VAULT_ROLE_ID }}
    secretId: ${{ secrets.VAULT_SECRET_ID }}
    secrets: |
      secret/database password | DB_PASSWORD
      secret/api key | API_KEY

- name: Deploy
  env:
    DB_PASSWORD: ${{ env.DB_PASSWORD }}
    API_KEY: ${{ env.API_KEY }}
  run: |
    # Usar secrets
```

**Integración con aplicaciones (runtime)**:
```python
# Python example
import hvac

client = hvac.Client(url='https://vault.example.com')
client.token = os.environ['VAULT_TOKEN']

# Leer secret
secret = client.secrets.kv.v2.read_secret_version(path='database')
db_password = secret['data']['data']['password']
```

---

## 📊 Comparación Detallada

| Característica | GitHub Secrets | HashiCorp Vault |
|----------------|----------------|-----------------|
| **Costo** | ✅ Gratis (incluido) | ❌ Requiere infraestructura |
| **Facilidad de uso** | ✅ Muy fácil | ⚠️ Curva de aprendizaje |
| **Integración CI/CD** | ✅ Nativa | ⚠️ Requiere plugin |
| **Uso en runtime** | ❌ No | ✅ Sí |
| **Rotación automática** | ❌ No | ✅ Sí |
| **Versionado** | ❌ No | ✅ Sí |
| **Auditoría** | ⚠️ Básica | ✅ Avanzada |
| **Búsqueda/consulta** | ❌ No | ✅ Sí |
| **Límites** | ⚠️ 100 secrets, 64KB | ✅ Sin límites |
| **Alta disponibilidad** | ✅ (GitHub) | ⚠️ Requiere configuración |
| **Mantenimiento** | ✅ Cero | ❌ Requiere mantenimiento |
| **Compliance** | ⚠️ Básico | ✅ Enterprise-grade |

---

## 🎯 Recomendaciones por Caso de Uso

### Para CodeSpartan (Freelance/Startup)

#### Fase 1: GitHub Secrets (Inmediato) ✅

**Usar GitHub Secrets para**:
- ✅ Secrets de CI/CD (SSH keys, tokens de deploy)
- ✅ Credenciales de servicios externos (Hetzner, DNS)
- ✅ Passwords de servicios de infraestructura (Traefik, Grafana)
- ✅ Tokens de GitHub (GH_PAT)

**Ventajas**:
- Sin costo adicional
- Fácil de implementar
- Suficiente para la mayoría de casos

**Implementación**:
1. Mover todos los secretos hardcodeados a GitHub Secrets
2. Actualizar workflows para usar `${{ secrets.XXX }}`
3. Eliminar archivos con credenciales del repo

#### Fase 2: HashiCorp Vault (Opcional - Enterprise)

**Considerar Vault si**:
- Necesitas rotación automática de credenciales de BD
- Tienes múltiples aplicaciones que comparten secretos
- Requisitos de compliance estrictos
- Secrets usados en runtime por aplicaciones

**Implementación**:
1. Desplegar Vault en VPS (o usar Vault Cloud)
2. Migrar secretos críticos a Vault
3. Integrar aplicaciones con Vault SDK

### Para Enterprise

**Recomendación**: **Híbrido**

1. **GitHub Secrets** para CI/CD
2. **HashiCorp Vault** para:
   - Secrets de aplicaciones en runtime
   - Credenciales de bases de datos (con rotación)
   - Certificados SSL/TLS
   - Secrets compartidos entre sistemas

---

## 🔄 Migración de Secretos Actuales

### Paso 1: Identificar Secretos en el Repo

```bash
# Buscar contraseñas hardcodeadas
grep -r "password\|secret\|token\|key" --include="*.yml" --include="*.yaml" .

# Archivos problemáticos encontrados:
# - codespartan/platform/traefik/users.htpasswd
# - codespartan/platform/authelia/users_database.yml
# - codespartan/platform/authelia/configuration.yml (SMTP password)
```

### Paso 2: Crear GitHub Secrets

**Secrets a crear**:
1. `AUTHELIA_SMTP_PASSWORD` - Contraseña SMTP de Authelia
2. `AUTHELIA_SESSION_SECRET` - Secret de sesión de Authelia
3. `AUTHELIA_ENCRYPTION_KEY` - Encryption key de Authelia
4. `TRAEFIK_BASIC_AUTH` - Hash de basic auth de Traefik
5. `ACME_EMAIL` - Email para Let's Encrypt (ya existe)

### Paso 3: Actualizar Workflows

```yaml
# .github/workflows/deploy-authelia.yml
- name: Prepare configuration
  env:
    SMTP_PASSWORD: ${{ secrets.AUTHELIA_SMTP_PASSWORD }}
    SESSION_SECRET: ${{ secrets.AUTHELIA_SESSION_SECRET }}
    ENCRYPTION_KEY: ${{ secrets.AUTHELIA_ENCRYPTION_KEY }}
  run: |
    # Generar configuration.yml con secrets desde variables de entorno
    envsubst < configuration.yml.template > configuration.yml
```

### Paso 4: Crear Templates

```yaml
# codespartan/platform/authelia/configuration.yml.template
notifier:
  smtp:
    password: ${SMTP_PASSWORD}  # Se reemplaza en deploy
```

### Paso 5: Eliminar Secretos del Repo

```bash
# Agregar a .gitignore
echo "**/users.htpasswd" >> .gitignore
echo "**/users_database.yml" >> .gitignore

# Crear .example files
cp users.htpasswd users.htpasswd.example
# Editar .example para mostrar formato sin valores reales
```

---

## 📚 Referencias

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault GitHub Action](https://github.com/hashicorp/vault-action)

---

**Última actualización**: 2025-11-18  
**Estado**: ✅ Documentación completa

