# Plan: Pipeline Comercial CodeSpartan

> **Objetivo:** Infraestructura para prospección comercial y gestión de leads con
> Twenty CRM, Brevo para campañas de email, y Redmine para gestión de proyectos.

**Última verificación VPS:** 2026-07-12
**RAM total:** 3.4 GB | **RAM usada:** 1.5 GB (44%) | **RAM disponible:** 1.9 GB (56%)
**Disco:** 9.9 GB / 38 GB (28%)

**Revisión (2026-07-13):** se descarta la consolidación de PostgreSQL (Fase 1 original). El ahorro real es de ~54 MB de RAM, insuficiente para justificar el riesgo de migrar los datos de Redmine con downtime en producción. Twenty CRM se despliega con su propio PostgreSQL dedicado, igual que Redmine. Ver detalle en la Fase 1 más abajo.

---

## Arquitectura Final

```
┌─ DOMINIOS ──────────────────────────────────────────────────────┐
│ codespartan.es     → Microsoft 365 (correo corporativo diario)  │
│ codespartan.cloud  → Infraestructura marketing (SEPARADO)       │
│   ├── crm.codespartan.cloud     → Twenty CRM                    │
│   ├── project.codespartan.cloud → Redmine (existente)           │
│   └── mail.codespartan.cloud    → Subdominio envíos Brevo       │
└─────────────────────────────────────────────────────────────────┘

┌─ VPS ARM (cax11, 3.4 GB) ──────────────────────────────────────┐
│                                                                │
│  ┌─ apps/codespartan-cloud/redmine/ (existente, sin tocar) ──┐  │
│  │  redmine-app + redmine-db (postgres:17-alpine, propio)    │  │
│  │  red: redmine_internal (172.31.0.0/24, internal: true)    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌─ apps/codespartan-cloud/crm/ ────────────────────────────┐  │
│  │  twentycrm/twenty:latest    ARM64 ✓                      │  │
│  │    ├── server (frontend+API)    512 MB / 0.5 CPU         │  │
│  │    ├── worker (BullMQ jobs)     512 MB / 0.5 CPU         │  │
│  │    └── db (postgres:17-alpine, propio) 256 MB / 0.5 CPU  │  │
│  │  redis:7-alpine                 256 MB / 0.25 CPU        │  │
│  │  red: crm_internal (172.34.0.0/24, internal: true)       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  Servicios existentes (inalterados):                           │
│    traefik, grafana, loki, monitoring, authelia, portainer...  │
└────────────────────────────────────────────────────────────────┘

┌─ SERVICIOS EXTERNOS ─────────────────────────────────────────────────────┐
│                                                                          │
│  Brevo                                                                   │
│    ├── SMTP relay (smtp-relay.brevo.com:587) ← Redmine, Twenty, Authelia │
│    ├── Campañas email desde mail.codespartan.cloud                       │
│    └── Tracking: aperturas, clicks, respuestas                           │
│                                                                          │
│  Microsoft 365 (codespartan.es)                                          │
│    ├── Correo corporativo diario (INTACTO)                               │
│    └── Twenty sincroniza calendario/correo vía OAuth                     │
└──────────────────────────────────────────────────────────────────────────┘

┌─ FLUJO DE TRABAJO DIARIO ────────────────────────────────────────┐
│                                                                  │
│  1. BUSCAR leads                                                 │
│     LinkedIn / Google Maps / directorios sectoriales             │
│                          │                                       │
│  2. REGISTRAR en Twenty CRM                                      │
│     Pipeline: Prospecto → Contactado → Interesado →              │
│               Propuesta → Negociación → Cliente                  │
│                          │                                       │
│  3. CONTACTAR vía Brevo                                          │
│     Campaña desde mail.codespartan.cloud                         │
│     Plantilla personalizada con tracking                         │
│                          │                                       │
│  4. SEGUIMIENTO                                                  │
│     Brevo tracking → Twenty CRM (actualizar pipeline)            │
│     Cliente responde → se sincroniza en Twenty                   │
│                          │                                       │
│  5. CONVERTIR lead → proyecto                                    │
│     Twenty marca como "Cliente" → Crear proyecto en Redmine      │
│     Redmine = gestión del proyecto, no del lead                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Fase 1: PostgreSQL Compartido — DESCARTADA

### Decisión

Se evaluó consolidar Redmine y Twenty CRM en una única instancia PostgreSQL compartida (`postgres_internal`), pero **se descarta**: el ahorro real es de solo ~54 MB de RAM (ver justificación original abajo), lo que no compensa el riesgo de migrar los datos de Redmine con downtime en producción.

**Decisión final:** cada producto mantiene su propio PostgreSQL dedicado, igual que hoy. Redmine no se toca — cero downtime, cero riesgo de migración. Twenty CRM se despliega con su propio servicio `db` (ver Fase 3).

### Justificación original (referencia histórica, ya no aplica)

| Concepto                                  | Valor                                                                        |
| ----------------------------------------- | ----------------------------------------------------------------------------- |
| Instancias PostgreSQL actuales en VPS ARM | 1 (`redmine-db`, 54 MB real / 256 MB límite)                                 |
| Instancias futuras sin consolidar         | 2 (`redmine-db` + `twenty-db`)                                               |
| Ahorro de RAM si se consolida             | ~54 MB (se eliminaría `redmine-db`)                                          |

54 MB sobre 3.4 GB de RAM total (~1.6%) no justifica el riesgo de migración con downtime real de un servicio en producción.

---

## Fase 2: DNS - Subdominios y Verificación Brevo

### 2.1 Archivos a modificar

#### `codespartan/infra/hetzner/terraform.tfvars`

**Línea 25** - Añadir `"crm"` a `subdomains`:

```hcl
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "lab-staging", "api", "api-staging", "project", "ui", "mambo", "portainer", "crm"]
```

**Nueva sección** al final del archivo - `dns_additional_records`:

```hcl
dns_additional_records = {
  "codespartan.cloud" = [
    # Verificación de dominio Brevo (obtener valor exacto en Brevo Dashboard)
    { name = "mail", type = "TXT", value = "brevo-code=OBTENER_DE_BREVO_DASHBOARD" },
    # SPF para subdominio de envío
    { name = "mail", type = "TXT", value = "v=spf1 include:spf.brevo.com ~all" },
    # DKIM de Brevo (obtener valor en Brevo Dashboard > Senders & Domains)
    { name = "mail._domainkey.mail", type = "TXT", value = "OBTENER_DE_BREVO_DASHBOARD" },
    # DMARC (monitoreo, sin rechazo inicial - subir a p=reject cuando esté estable)
    { name = "_dmarc.mail", type = "TXT", value = "v=DMARC1; p=none; rua=mailto:postmaster@codespartan.cloud" },
  ]
}
```

### 2.2 Procedimiento en Brevo Dashboard

1. Ir a **Brevo > Senders & Domains > Add Domain**
2. Añadir `mail.codespartan.cloud`
3. Brevo generará 3 registros: código de verificación + DKIM + DMARC
4. Copiar los valores generados a `terraform.tfvars`
5. Aplicar Terraform

### 2.3 Aplicar cambios

```bash
cd codespartan/infra/hetzner
terraform plan   # verificar cambios
terraform apply   # aplicar
```

### 2.4 Verificar propagación DNS

```bash
dig TXT mail.codespartan.cloud +short
dig A crm.codespartan.cloud +short
```

---

## Fase 3: Twenty CRM

### 3.1 Compatibilidad ARM64

La imagen `twentycrm/twenty:latest` tiene builds multi-arch:

- `linux/amd64` ✓
- `linux/arm64` ✓

El VPS cax11 (ARM64) ejecutará Twenty nativamente sin emulación.

### 3.2 Archivos a crear

#### `codespartan/apps/codespartan-cloud/crm/docker-compose.yml`

```yaml
services:
  server:
    image: twentycrm/twenty:${TAG:-latest}
    container_name: twenty-server
    volumes:
      - twenty-local-data:/app/packages/twenty-server/.local-storage
    environment:
      NODE_PORT: 3000
      SERVER_URL: ${SERVER_URL:-https://crm.codespartan.cloud}
      PG_DATABASE_URL: postgres://${PG_USER:-twenty}:${PG_PASSWORD}@db:5432/twenty
      REDIS_URL: redis://redis:6379
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      STORAGE_TYPE: ${STORAGE_TYPE:-local}
      DISABLE_DB_MIGRATIONS: ${DISABLE_DB_MIGRATIONS:-}
    networks:
      - web
      - crm_internal
    depends_on:
      db:
        condition: service_healthy
    labels:
      - traefik.enable=true
      - traefik.http.routers.crm.rule=Host(`crm.codespartan.cloud`)
      - traefik.http.routers.crm.entrypoints=websecure
      - traefik.http.routers.crm.tls=true
      - traefik.http.routers.crm.tls.certresolver=le
      - traefik.http.services.crm.loadbalancer.server.port=3000
      - traefik.docker.network=web
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:3000/healthz"]
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 60s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          cpus: "0.1"
          memory: 256M

  worker:
    image: twentycrm/twenty:${TAG:-latest}
    container_name: twenty-worker
    command: ["yarn", "worker:prod"]
    volumes:
      - twenty-local-data:/app/packages/twenty-server/.local-storage
    environment:
      SERVER_URL: ${SERVER_URL:-https://crm.codespartan.cloud}
      PG_DATABASE_URL: postgres://${PG_USER:-twenty}:${PG_PASSWORD}@db:5432/twenty
      REDIS_URL: redis://redis:6379
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      STORAGE_TYPE: ${STORAGE_TYPE:-local}
      DISABLE_DB_MIGRATIONS: "true"
      DISABLE_CRON_JOBS_REGISTRATION: "true"
    networks:
      - crm_internal
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          cpus: "0.1"
          memory: 128M

  db:
    image: postgres:17-alpine
    container_name: twenty-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: twenty
      POSTGRES_USER: ${PG_USER:-twenty}
      POSTGRES_PASSWORD: ${PG_PASSWORD}
    volumes:
      - twenty-db-data:/var/lib/postgresql/data
    networks:
      - crm_internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PG_USER:-twenty}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.1"
          memory: 64M

  redis:
    image: redis:7-alpine
    container_name: twenty-redis
    command: ["--maxmemory-policy", "noeviction"]
    networks:
      - crm_internal
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.25"
          memory: 256M
        reservations:
          cpus: "0.05"
          memory: 32M

volumes:
  twenty-local-data:
    name: twenty_local_data
  twenty-db-data:
    name: twenty_db_data

networks:
  web:
    external: true
  crm_internal:
    name: crm_internal
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.34.0.0/24
```

#### `codespartan/apps/codespartan-cloud/crm/.env.example`

```env
TAG=latest
SERVER_URL=https://crm.codespartan.cloud

# PostgreSQL (instancia propia, dedicada a Twenty)
PG_USER=twenty
PG_PASSWORD=change_me_strong_password

# Encriptación (generar con: openssl rand -base64 32)
ENCRYPTION_KEY=change_me_random_64_chars

# Almacenamiento
STORAGE_TYPE=local

# Configuración en runtime (via Admin Panel de Twenty):
# - SMTP (Brevo): EMAIL_DRIVER=smtp, EMAIL_SMTP_HOST=smtp-relay.brevo.com, EMAIL_SMTP_PORT=587
# - Microsoft 365 OAuth (para sincronizar correo/calendario corporativo)
# - Pipeline de ventas personalizado
```

#### `codespartan/apps/codespartan-cloud/crm/.gitignore`

```
.env
```

### 3.3 GitHub Actions

#### `.github/workflows/deploy-crm.yml`

```yaml
name: Deploy Twenty CRM

on:
  workflow_dispatch:
  push:
    paths:
      - "codespartan/apps/codespartan-cloud/crm/**"

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Prepare deployment files
        run: |
          mkdir -p artifacts/crm
          cp -r codespartan/apps/codespartan-cloud/crm/* artifacts/crm/

      - name: Create .env file from secrets
        run: |
          cat > artifacts/crm/.env << 'EOF'
          TAG=latest
          SERVER_URL=${{ secrets.CRM_HOSTNAME || 'https://crm.codespartan.cloud' }}
          PG_USER=${{ secrets.CRM_PG_USER || 'twenty' }}
          PG_PASSWORD=${{ secrets.CRM_PG_PASSWORD }}
          ENCRYPTION_KEY=${{ secrets.CRM_ENCRYPTION_KEY }}
          STORAGE_TYPE=local
          EOF

      - name: Create remote directory
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            mkdir -p /opt/codespartan/apps/codespartan-cloud/crm

      - name: Copy files to VPS
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          source: "artifacts/crm/*"
          target: "/opt/codespartan/apps/codespartan-cloud/crm"
          strip_components: 2

      - name: Deploy Twenty CRM
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script_stop: true
          script: |
            set -euxo pipefail

            echo "=== Asegurando redes ==="
            docker network create web 2>/dev/null || true

            echo "=== Navegando al directorio CRM ==="
            cd /opt/codespartan/apps/codespartan-cloud/crm

            echo "=== Verificando .env ==="
            if [ ! -f .env ]; then
              echo "ERROR: .env file not found."
              exit 1
            fi

            echo "=== Desplegando Twenty CRM ==="
            docker compose pull
            docker compose up -d --wait

            echo "=== Verificando ==="
            docker ps --format 'table {{.Names}}\t{{.Status}}' | grep twenty
            echo "Twenty CRM desplegado: https://crm.codespartan.cloud"
```

### 3.4 GitHub Secrets (nuevos)

| Secret               | Propósito                                                  |
| -------------------- | ---------------------------------------------------------- |
| `CRM_PG_USER`        | Usuario PostgreSQL para Twenty (ej: `twenty`)              |
| `CRM_PG_PASSWORD`    | Contraseña PostgreSQL para Twenty                          |
| `CRM_ENCRYPTION_KEY` | Clave de encriptación (generar: `openssl rand -base64 32`) |
| `CRM_HOSTNAME`       | `crm.codespartan.cloud`                                    |

### 3.5 Configuración post-despliegue en Twenty

1. Acceder a `https://crm.codespartan.cloud`
2. Crear usuario administrador
3. **Pipeline de ventas** (Settings > Objects > Opportunities):
   - Stages: `Prospecto → Contactado → Interesado → Propuesta → Negociación → Cliente`
4. **Campos personalizados** en Companies/People:
   - `Sector` (texto)
   - `Tamaño empresa` (select)
   - `Origen del lead` (select: LinkedIn, Referencia, Web, Evento, Otros)
   - `Prioridad` (select: Alta, Media, Baja)
5. **Microsoft 365 OAuth** (Settings > Admin Panel):
   - Conectar cuenta `@codespartan.es` para sincronizar correo y calendario
6. **SMTP Brevo** (Settings > Admin Panel):
   - `EMAIL_DRIVER=smtp`
   - `EMAIL_SMTP_HOST=smtp-relay.brevo.com`
   - `EMAIL_SMTP_PORT=587`
   - Credenciales de Brevo

---

## Fase 4: Brevo - Campañas de Prospección

### 4.1 Configurar subdominio de envío

1. Ir a **Brevo > Campaigns > Senders & Domains**
2. Verificar `mail.codespartan.cloud` (los registros DNS ya deben estar propagados de la Fase 2)
3. Esperar validación (5-15 minutos)

### 4.2 Plantillas de email

Crear plantillas en Brevo para la secuencia de prospección:

| Plantilla              | Asunto sugerido                                           | Timing |
| ---------------------- | ---------------------------------------------------------- | ------ |
| `cold-01-presentacion` | "CodeSpartan: solución cloud para [sector]"               | Día 1  |
| `cold-02-valor`        | "Cómo [empresa similar] redujo costes un X% con nosotros" | Día 4  |
| `cold-03-seguimiento`  | "¿Has podido revisar mi propuesta?"                       | Día 8  |
| `cold-04-cierre`       | "Último intento :) ¿Hablamos 5 min?"                      | Día 14 |

### 4.3 Automatizaciones en Brevo

- **Trigger:** Contacto añadido a lista "Prospección"
- **Workflow:** Enviar secuencia de 4 emails con delays
- **Condición de salida:** Si responde → sale de la secuencia automática
- **Tracking:** Aperturas, clicks, respuestas

### 4.4 Sincronización Twenty ↔ Brevo

**Opción A - Manual (recomendado para empezar):**

- Exportar contactos de Twenty → Importar en Brevo
- Actualizar pipeline en Twenty según respuestas

**Opción B - Automática (futuro):**

- Script con Brevo API + Twenty API
- O usar n8n/Zapier como puente (ver `08-ADR/ADR-010-n8n.md` en `CodeSpartan-OS`: aplazado, no descartado)
- Sincronizar contactos y eventos de campaña

### 4.5 Buenas prácticas cold outreach

| Regla                             | Por qué                                         |
| ---------------------------------- | ----------------------------------------------- |
| Máximo 50 emails/día al principio | Calentar reputación del subdominio              |
| Personalizar cada email           | Tasa de apertura 3x mayor                       |
| No usar el dominio corporativo    | Proteger `codespartan.es` de listas negras      |
| Incluir enlace de unsubscribe     | Obligatorio por GDPR/Ley de Protección de Datos |
| Monitorizar bounce rate           | Si >5%, revisar calidad de la lista             |

---

## Fase 5: Personalizar Redmine (Corporativo)

### 5.1 Theme / CSS personalizado

Redmine tiene el plugin `view_customize` instalado (ver `Dockerfile`).
Permite inyectar CSS/JS sin tocar el core de Redmine.

**CSS para branding corporativo** (ejemplo):

```css
/* Colores corporativos CodeSpartan */
:root {
  --cs-primary: #1a56db;
  --cs-secondary: #0f172a;
  --cs-accent: #f59e0b;
}

#header {
  background: linear-gradient(135deg, var(--cs-secondary), var(--cs-primary));
}

#top-menu {
  background: var(--cs-secondary);
}

#main-menu li a:hover {
  background: var(--cs-primary);
}

/* Logo personalizado */
#header h1:before {
  content: "";
  display: inline-block;
  width: 32px;
  height: 32px;
  background: url("/images/codespartan-logo.png") no-repeat center;
  background-size: contain;
  margin-right: 8px;
}
```

### 5.2 Configuración corporativa en Redmine

- **Nombre de la instancia:** "CodeSpartan - Gestión de Proyectos"
- **Email de sistema:** `noreply@codespartan.es` (via Brevo SMTP)
- **Roles personalizados:**
  - `Cliente` (solo ve sus proyectos)
  - `Consultor` (gestiona proyectos asignados)
  - `Admin` (acceso total)

### 5.3 Plugins recomendados (ya documentados en PLUGINS.md)

| Plugin                  | Uso                                    |
| ----------------------- | --------------------------------------- |
| `view_customize`        | CSS/JS branding, ya instalado          |
| `redmine_discord`       | Notificaciones a Discord, ya instalado |
| `redmine_ckeditor`      | Editor WYSIWYG para descripciones/wiki |
| `redmine_dashboard`     | Dashboard personalizable por rol       |
| `redmine_knowledgebase` | Base de conocimiento para clientes     |

### 5.4 Integración Redmine ↔ Email (via Brevo)

Ya configurado en `.env.example`:

- SMTP: `smtp-relay.brevo.com:587`
- Dominio: `codespartan.es`
- Remitente: `noreply@codespartan.es`

---

## Resumen de subredes reservadas (actualizado)

| Subnet          | Red                 | Uso                                 |
| --------------- | -------------------- | ------------------------------------ |
| `172.20.0.0/16` | `web`               | Traefik routing                     |
| `172.21.0.0/24` | `authelia_internal` | Authelia SSO                        |
| `172.22.0.0/24` | `api_trackworks`    | Retirada (Cyberdyne ahora usa Supabase self-hosted en el 2º VPS) |
| `172.24.0.0/24` | `monitoring`        | VictoriaMetrics stack               |
| `172.25.0.0/24` | `docker_api`        | Socket proxy                        |
| `172.26.0.0/24` | `kong_cyberdyne`    | Retirada (redundante con el Kong propio de Supabase) |
| `172.29.0.0/24` | `mambo_internal`    | Mambo Cloud                         |
| `172.30.0.0/24` | `dental_internal`   | Dental IO                           |
| `172.31.0.0/24` | `redmine_internal`  | Redmine (permanente, no se toca)    |
| `172.34.0.0/24` | `crm_internal`      | **NUEVO:** Twenty CRM (server/worker/db/redis) |

---

## Orden de ejecución

| Paso | Fase | Tarea                                                                   | Depende de  |
| ---- | ---- | ----------------------------------------------------------------------- | ----------- |
| 1    | 2    | Añadir `crm` a subdomains en `terraform.tfvars`                         | -           |
| 2    | 2    | Añadir `dns_additional_records` para Brevo                              | -           |
| 3    | 2    | Configurar `mail.codespartan.cloud` en Brevo Dashboard                  | Paso 2      |
| 4    | 2    | `terraform apply`                                                       | Pasos 1-2   |
| 5    | 3    | Crear `apps/codespartan-cloud/crm/` (todos los archivos)                | -           |
| 6    | 3    | Crear `.github/workflows/deploy-crm.yml`                                | -           |
| 7    | 3    | Añadir GitHub Secrets para CRM                                          | -           |
| 8    | 3    | Push → Deploy automático Twenty CRM (crea su propia BD al arrancar)     | Pasos 5-7   |
| 9    | 3    | Configurar Twenty (pipeline, OAuth Microsoft 365, SMTP Brevo)           | Paso 8      |
| 10   | 4    | Verificar `mail.codespartan.cloud` en Brevo                             | Paso 4      |
| 11   | 4    | Crear plantillas de email en Brevo                                      | Paso 10     |
| 12   | 4    | Configurar automatizaciones de secuencia                                | Paso 11     |
| 13   | 5    | Personalizar Redmine (CSS corporativo via view_customize)               | -           |
| 14   | 5    | Configurar roles y permisos en Redmine                                  | Paso 13     |

---

## Riesgos y mitigaciones

| Riesgo                                                   | Impacto | Mitigación                                                                               |
| -------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------- |
| Twenty ocupa más RAM de lo estimado                      | Medio   | Límites estrictos (512 MB server, 512 MB worker, 256 MB db). Si excede, OOM kill y restart |
| Reputación de `mail.codespartan.cloud` se quema por spam | Bajo    | Subdominio aislado. No afecta a `codespartan.es`. Recrear subdominio si es necesario     |
| Conflicto de versiones PostgreSQL                        | Bajo    | Twenty espera PostgreSQL 15+, usamos 17-alpine (propio). Compatible                      |

---

## Scripts útiles

### Backup PostgreSQL de Twenty (instancia propia)

```bash
# Backup de la base de datos de Twenty
docker exec twenty-db pg_dump -U twenty twenty > backup_twenty_$(date +%Y%m%d).sql
```

Sigue el mismo patrón que ya usa `redmine-db` (backup independiente por servicio, ver `platform/stacks/backups/`).

### Verificar salud del sistema tras el despliegue

```bash
# Uso de RAM y disco
free -h && df -h /

# Todos los contenedores y su memoria
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}'

# Contenedores stopped (posibles problemas)
docker ps -a --filter "status=exited" --format 'table {{.Names}}\t{{.Status}}'

# Logs de Twenty en busca de errores
docker logs twenty-server --tail 50
docker logs twenty-worker --tail 50
```
