# Plan de Migración VPS - Reorganización Apps

**Fecha:** 2025-11-10
**Estado:** 🚧 PENDIENTE - Requiere acceso SSH al VPS

## Problema

Los workflows de SSH a VPS están fallando con error de autenticación:
```
ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
```

**Posible causa:** El secret `VPS_SSH_KEY` en GitHub Actions puede estar desactualizado o el VPS cambió su configuración SSH.

---

## Estructura Local vs VPS

### Estructura LOCAL (IaC Repo) - ✅ REORGANIZADA

```
codespartan/apps/
├── codespartan-cloud/
│   ├── api/
│   ├── api-staging/
│   ├── mambo/
│   ├── project/          ← Redmine (docker-compose.yml) [OpenProject eliminado]
│   ├── staging/
│   ├── traefik/
│   ├── ui/
│   └── www/
│
├── cyberdyne-systems-es/
│   ├── api/              ← docker-compose.yml + .env.example
│   ├── api-staging/      ← docker-compose.yml
│   ├── mambo/
│   ├── staging/          ← docker-compose.yml
│   ├── traefik/          ← docker-compose.yml
│   ├── ui/
│   └── www/              ← docker-compose.yml
│
├── dental-io-com/
│   ├── api/
│   ├── api-staging/
│   ├── mambo/
│   ├── staging/
│   ├── traefik/
│   ├── ui/
│   └── www/              ← docker-compose.yml
│
└── mambo-cloud-com/
    ├── api/
    ├── api-staging/
    ├── backoffice/       ← Excepción (mantener)
    ├── mambo/
    ├── staging/
    ├── traefik/
    ├── ui/
    └── www/              ← docker-compose.yml
```

### Estructura VPS (DESCONOCIDA)

**⚠️ NO PODEMOS ACCEDER** por fallo de autenticación SSH.

Necesitamos conocer:
1. ¿Qué directorios existen en `/opt/codespartan/apps/`?
2. ¿Qué contenedores Docker están corriendo?
3. ¿Qué rutas antiguas tienen las aplicaciones desplegadas?

---

## Acciones Requeridas en VPS

### PASO 1: Acceso SSH Manual

**Debes ejecutar esto TÚ directamente en el VPS:**

```bash
ssh leonidas@91.98.137.217
```

### PASO 2: Verificar Estructura Actual

```bash
# Ver qué directorios existen
ls -la /opt/codespartan/apps/

# Ver todos los subdirectorios
find /opt/codespartan/apps -maxdepth 2 -type d | sort

# Ver docker-compose files desplegados
find /opt/codespartan/apps -name "docker-compose.yml"

# Ver contenedores corriendo
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

### PASO 3: Crear Nueva Estructura (si no existe)

```bash
# Crear estructura para codespartan-cloud
sudo mkdir -p /opt/codespartan/apps/codespartan-cloud/{api,api-staging,mambo,project,staging,traefik,ui,www}

# Crear estructura para cyberdyne-systems-es
sudo mkdir -p /opt/codespartan/apps/cyberdyne-systems-es/{api,api-staging,mambo,staging,traefik,ui,www}

# Crear estructura para dental-io-com
sudo mkdir -p /opt/codespartan/apps/dental-io-com/{api,api-staging,mambo,staging,traefik,ui,www}

# Crear estructura para mambo-cloud-com
sudo mkdir -p /opt/codespartan/apps/mambo-cloud-com/{api,api-staging,backoffice,mambo,staging,traefik,ui,www}

# Dar permisos correctos
sudo chown -R leonidas:leonidas /opt/codespartan/apps/
```

### PASO 4: Mover Aplicaciones Antiguas (si existen)

```bash
# Si existe /opt/codespartan/apps/cyberdyne/
if [ -d "/opt/codespartan/apps/cyberdyne" ]; then
  sudo mv /opt/codespartan/apps/cyberdyne/backend/* /opt/codespartan/apps/cyberdyne-systems-es/api/ 2>/dev/null || true
  sudo mv /opt/codespartan/apps/cyberdyne/backend-staging/* /opt/codespartan/apps/cyberdyne-systems-es/api-staging/ 2>/dev/null || true
  sudo mv /opt/codespartan/apps/cyberdyne/frontend/* /opt/codespartan/apps/cyberdyne-systems-es/www/ 2>/dev/null || true
  sudo mv /opt/codespartan/apps/cyberdyne/staging/* /opt/codespartan/apps/cyberdyne-systems-es/staging/ 2>/dev/null || true
fi

# OpenProject ha sido eliminado (reemplazado por Redmine)
# Si existe /opt/codespartan/apps/openproject/
if [ -d "/opt/codespartan/apps/openproject" ]; then
  echo "OpenProject ya no existe - eliminado en favor de Redmine" 
fi

# Si existe /opt/codespartan/apps/dental-io/
if [ -d "/opt/codespartan/apps/dental-io" ]; then
  sudo mv /opt/codespartan/apps/dental-io/* /opt/codespartan/apps/dental-io-com/www/ 2>/dev/null || true
fi

# Si existe /opt/codespartan/apps/mambo-cloud/
if [ -d "/opt/codespartan/apps/mambo-cloud" ]; then
  sudo mv /opt/codespartan/apps/mambo-cloud/* /opt/codespartan/apps/mambo-cloud-com/www/ 2>/dev/null || true
fi
```

### PASO 5: Detener Contenedores Antiguos

```bash
# Listar todos los contenedores relacionados
docker ps -a | grep -E "(cyberdyne|dental|mambo|redmine)"

# Detener y eliminar contenedores antiguos (CUIDADO)
docker stop $(docker ps -q --filter "name=cyberdyne") 2>/dev/null || true
docker stop $(docker ps -q --filter "name=dental") 2>/dev/null || true
docker stop $(docker ps -q --filter "name=mambo") 2>/dev/null || true
# OpenProject eliminado - ya no es necesario detenerlo
# docker stop $(docker ps -q --filter "name=openproject") 2>/dev/null || true
```

### PASO 6: Verificar Traefik

```bash
# Traefik debe estar corriendo
docker ps | grep traefik

# Ver configuración actual
docker logs traefik --tail 50

# Si Traefik no está corriendo, desplegarlo
cd /opt/codespartan/platform/traefik
docker compose up -d
```

---

## Workflows de GitHub Actions

### Estado Actual: ✅ ACTUALIZADOS

Los workflows YA tienen las rutas correctas:

- **deploy-cyberdyne.yml** → `cyberdyne-systems-es/www/**`
- **deploy-cyberdyne-api.yml** → `cyberdyne-systems-es/api/**`
- **deploy-dental-io.yml** → `dental-io-com/www/**`
- **deploy-mambo-cloud.yml** → `mambo-cloud-com/www/**`

### Problema: 🚨 SSH AUTH FALLA

Los workflows no pueden conectar al VPS. Necesitas:

1. **Verificar el secret `VPS_SSH_KEY` en GitHub:**
   - Ve a: https://github.com/TechnoSpartan/iac-code-spartan/settings/secrets/actions
   - Verifica que `VPS_SSH_KEY` contiene la clave privada correcta

2. **Generar nueva clave SSH si es necesario:**
   ```bash
   # En el VPS
   ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions
   cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys
   cat ~/.ssh/github_actions  # Copiar ESTA clave privada al secret de GitHub
   ```

---

## DNS y Subdominios

### Subdominios Configurados en Terraform

**Todos los dominios tienen estos subdominios:**
- `api`
- `api-staging`
- `backoffice` (solo mambo-cloud-com)
- `grafana`
- `lab`
- `lab-staging`
- `mambo`
- `project`
- `staging`
- `traefik`
- `ui`
- `www`

### Verificar DNS

```bash
dig api.cyberdyne-systems.es A
dig www.dental-io.com A
dig backoffice.mambo-cloud.com A
dig project.codespartan.cloud A
```

Todos deben resolver a: **91.98.137.217**

---

## Checklist de Despliegue

### Antes de Desplegar

- [ ] Acceso SSH al VPS funciona
- [ ] Estructura de directorios creada en VPS
- [ ] Contenedores antiguos detenidos
- [ ] Traefik corriendo correctamente
- [ ] Secret `VPS_SSH_KEY` actualizado en GitHub

### Orden de Despliegue

1. [ ] **Traefik** (si no está corriendo)
2. [ ] **Cyberdyne API** (`deploy-cyberdyne-api.yml`)
3. [ ] **Cyberdyne Frontend** (`deploy-cyberdyne.yml`)
4. [ ] **Dental-IO** (`deploy-dental-io.yml`)
5. [ ] **Mambo Cloud** (`deploy-mambo-cloud.yml`)
6. [ ] **OpenProject** (crear workflow para `codespartan-cloud/project`)

### Verificación Post-Despliegue

```bash
# Verificar todos los contenedores
docker ps

# Verificar logs
docker logs <nombre-contenedor> --tail 50

# Test endpoints
curl -I https://api.cyberdyne-systems.es
curl -I https://www.dental-io.com
curl -I https://backoffice.mambo-cloud.com
curl -I https://project.codespartan.cloud
```

---

## Próximos Pasos

1. **TÚ necesitas:**
   - Conectar al VPS: `ssh leonidas@91.98.137.217`
   - Ejecutar los comandos de verificación (PASO 2)
   - Crear la estructura de directorios (PASO 3)
   - Verificar/actualizar el secret SSH en GitHub

2. **Yo haré:**
   - Crear workflow para desplegar OpenProject
   - Limpiar workflows obsoletos
   - Documentar los cambios en CLAUDE.md

**⚠️ IMPORTANTE:** Hasta que no tengamos acceso SSH funcional, NO podemos desplegar nada.
