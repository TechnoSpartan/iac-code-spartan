# FASE 2 - Single Sign-On con Multi-Factor Authentication

**Estado**: ✅ COMPLETADA
**Fecha**: 2025-11-16
**Duración**: ~3 horas (incluyendo troubleshooting)

---

## Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Arquitectura Desplegada](#arquitectura-desplegada)
3. [Proceso de Implementación](#proceso-de-implementación)
4. [Problemas Encontrados y Soluciones](#problemas-encontrados-y-soluciones)
5. [Estado Actual](#estado-actual)
6. [Roadmap Completo de la Plataforma](#roadmap-completo-de-la-plataforma)
7. [Mejoras de Arquitectura Pendientes](#mejoras-de-arquitectura-pendientes)
8. [Workflows Creados](#workflows-creados)
9. [Configuración y Credenciales](#configuración-y-credenciales)
10. [Lecciones Aprendidas](#lecciones-aprendidas)

---

## Resumen Ejecutivo

FASE 2 implementa **Single Sign-On (SSO)** con **Multi-Factor Authentication (MFA)** usando Authelia, proporcionando autenticación centralizada para todos los dashboards y servicios de la plataforma Mambo Cloud.

### Objetivos Cumplidos

✅ **Authelia SSO** desplegado en https://auth.mambo-cloud.com
✅ **MFA con TOTP** - Microsoft/Google Authenticator
✅ **Protección de servicios** - Grafana, Traefik dashboard requieren autenticación
✅ **Redirección automática** - Al intentar acceder a servicios protegidos
✅ **Sesión persistente** - Remember Me de 1 mes
✅ **Sistema de notificaciones** - Filesystem-based para registro de dispositivos

### Servicios Protegidos

| Servicio | URL | Política |
|----------|-----|----------|
| Grafana | https://grafana.mambo-cloud.com | two_factor (admins) |
| Traefik Dashboard | https://traefik.mambo-cloud.com | two_factor (admins) |
| Backoffice | https://backoffice.mambo-cloud.com | two_factor (admins) |
| Authelia Portal | https://auth.mambo-cloud.com | bypass (público) |

---

## Arquitectura Desplegada

### Diagrama de Flujo de Autenticación

```
Usuario                Traefik              Authelia            Servicio
  |                       |                     |                  |
  |--1. GET /grafana----->|                     |                  |
  |                       |--2. ForwardAuth---->|                  |
  |                       |<--3. 401 Unauth-----|                  |
  |<--4. 302 Redirect-----|                     |                  |
  |       (auth.mambo-cloud.com)                |                  |
  |                       |                     |                  |
  |--5. Login Form------->|-------------------->|                  |
  |<--6. Form-------------|<--------------------|                  |
  |                       |                     |                  |
  |--7. Credentials------>|-------------------->|                  |
  |       (user+pass+OTP) |                     |                  |
  |                       |                     |--8. Validate---->|
  |                       |                     |     (Redis)      |
  |<--9. Set Cookie-------|<--------------------|                  |
  |                       |                     |                  |
  |--10. GET /grafana---->|                     |                  |
  |                       |--11. ForwardAuth--->|                  |
  |                       |      (with cookie)  |                  |
  |                       |<--12. 200 OK--------|                  |
  |                       |--13. Proxy--------->|----------------->|
  |<--14. Response--------|<--------------------|<-----------------|
```

### Componentes

#### 1. Authelia (SSO Server)
- **Imagen**: `authelia/authelia:latest`
- **Puerto**: 9091 (interno)
- **Redes**: `web` (Traefik), `authelia_internal` (Redis)
- **Volúmenes**:
  - `configuration.yml` - Configuración principal
  - `users_database.yml` - Base de datos de usuarios
  - `authelia_data` (Docker volume) - SQLite DB, logs, notificaciones

**Características**:
- Autenticación de usuarios con Argon2id password hashing
- TOTP (Time-based One-Time Password) para MFA
- Sesiones con Redis para alta disponibilidad
- Access control basado en dominios y grupos
- Notificaciones por archivo (filesystem)

#### 2. Redis (Session Store)
- **Imagen**: `redis:7-alpine`
- **Puerto**: 6379 (solo red interna)
- **Red**: `authelia_internal` (aislada, no accesible desde internet)
- **Persistencia**: Snapshot cada 60s si hay cambios

**Por qué Redis**:
- Sesiones compartidas entre múltiples instancias de Authelia (escalabilidad)
- Performance superior para operaciones de sesión
- TTL automático para expiración de sesiones

#### 3. Traefik (Reverse Proxy)
- **ForwardAuth Middleware**: Delega autenticación a Authelia
- **Router para Authelia**: `auth.mambo-cloud.com`
- **Headers**: `Remote-User`, `Remote-Groups`, `Remote-Name`, `Remote-Email`

**Configuración de Labels en servicios protegidos**:
```yaml
labels:
  - traefik.http.routers.grafana.middlewares=authelia@docker
```

### Redes Docker

```yaml
networks:
  web:
    external: true  # Compartida con Traefik

  authelia_internal:
    driver: bridge
    internal: true  # Sin acceso a internet
    ipam:
      config:
        - subnet: 172.21.0.0/24
```

**Modelo de seguridad**:
- Authelia en ambas redes: `web` (para Traefik) + `authelia_internal` (para Redis)
- Redis **solo** en `authelia_internal` - NO accesible desde internet
- Separación de responsabilidades: frontend (web) vs backend (internal)

---

## Proceso de Implementación

### Fase 1: Preparación (15 min)

1. **Recreación completa de Traefik** para limpiar estado anterior
   - Workflow: `deploy-traefik.yml`
   - Resultado: Traefik limpio sin configuraciones residuales

2. **Creación de archivos de configuración**
   - `configuration.yml` - 177 líneas con toda la configuración de Authelia
   - `users_database.yml` - Base de datos de usuarios con hash Argon2id
   - `docker-compose.yml` - Definición de servicios (Authelia + Redis)

3. **Generación de hash de contraseña**
   ```bash
   docker run authelia/authelia:latest authelia crypto hash generate argon2 \
     --password 'codespartan123'
   ```
   - Resultado: `$argon2id$v=19$m=65536,t=3,p=4$...$...`

### Fase 2: Despliegue Inicial (30 min)

1. **Deploy de Authelia**
   - Workflow: `deploy-authelia.yml`
   - SCP de archivos de configuración al VPS
   - `docker compose up -d`

2. **Problemas encontrados**:
   - ❌ SCP no sobrescribía archivos existentes
   - ❌ Docker compose restart no recarga volúmenes
   - ❌ Authelia crasheaba en loop sin error claro

3. **Soluciones aplicadas**:
   - ✅ Añadido `overwrite: true` a SCP action
   - ✅ Cambio de `restart` a `down && up --force-recreate`
   - ✅ Creación de workflow `fix-networks.yml`

### Fase 3: Configuración de MFA (45 min)

1. **Primer intento de login**
   - Portal accesible ✅
   - Credenciales rechazadas ❌

2. **Problema: Hash de contraseña incorrecto**
   - El hash inicial no coincidía con la contraseña
   - Solución: Workflow `generate-new-password.yml`
   - Genera hash directamente en el VPS con Authelia CLI

3. **Registro de dispositivo TOTP**
   - Click en "Añadir" generaba "correo enviado"
   - No había SMTP configurado
   - Solución: Workflow `get-otp-link.yml` para leer `/data/notifications.txt`
   - Código OTP: `YZGR882J`
   - Escaneo de QR con Microsoft Authenticator ✅

4. **Prueba de login completo**
   - Usuario: `admin`
   - Contraseña: `codespartan123`
   - Código TOTP: 6 dígitos de la app
   - **Resultado: ÉXITO** 🎉

### Fase 4: Integración SMTP (1h 30min - PARCIAL)

**Objetivo**: Configurar Hostinger SMTP para notificaciones por correo

**Datos de conexión**:
```yaml
smtp:
  host: smtp.hostinger.com
  port: 465
  username: iam@codespartan.es
  password: Codespartan$2
  sender: "Mambo Cloud Auth <noreply@codespartan.es>"
```

**Problemas encontrados**:

1. **Conflicto de notifiers**
   ```
   ERROR: notifier: please ensure only one of the 'smtp' or 'filesystem' notifier is configured
   ```
   - Authelia NO permite tener ambos al mismo tiempo
   - Intenté tener `filesystem` como fallback - rechazado

2. **Configuración inválida `elevated_session`**
   ```
   ERROR: configuration key not expected: identity_validation.elevated_session.elevation_duration
   ```
   - Intenté deshabilitar validación por correo para registro de dispositivos
   - La key `elevated_session` no existe en Authelia 4.39
   - Causó crash loop del contenedor

3. **Container en restart loop**
   - Authelia arrancaba y crasheaba inmediatamente
   - Logs se cortaban después de "Log severity set to info"
   - No mostraba error específico de SMTP

**Solución temporal**:
- ✅ Restaurar configuración con `filesystem` notifier
- ✅ Comentar SMTP en el archivo para uso futuro
- ✅ Reiniciar Traefik y Authelia → **HTTP 200** 🎉

**Estado SMTP**: ⏸️ **PREPARADO PERO DESHABILITADO**
- Configuración lista en el archivo (comentada)
- Requiere debugging adicional
- No es bloqueante para funcionalidad SSO

---

## Problemas Encontrados y Soluciones

### Problema 1: Password Hash Incorrecto

**Síntoma**: Login fallaba con credenciales correctas

**Causa Raíz**: El hash generado localmente no coincidía con la contraseña

**Solución**:
```yaml
# Workflow: generate-new-password.yml
NEW_HASH=$(docker exec authelia authelia crypto hash generate argon2 \
  --password 'codespartan123' 2>&1 | grep 'Digest:' | awk '{print $2}')

sed -i "s|password: \".*\"|password: \"$NEW_HASH\"|" \
  /opt/codespartan/platform/authelia/users_database.yml

docker compose down && docker compose up -d
```

**Lección**: Generar hashes **en el mismo entorno** donde se usarán

---

### Problema 2: Gateway Timeout después de recrear contenedor

**Síntoma**: HTTP 504 Gateway Timeout en `auth.mambo-cloud.com`

**Causa Raíz**:
- Authelia crasheaba en loop por configuración inválida
- Traefik no detectaba el router de Authelia

**Diagnóstico**:
```bash
# Contenedor en restart loop
docker ps -a --filter "name=authelia"
# STATUS: Restarting (1) X seconds ago

# Traefik no tiene router
docker exec traefik wget -qO- http://localhost:8080/api/http/routers | grep authelia
# No authelia router found
```

**Solución**:
1. Eliminar configuración inválida (`elevated_session`)
2. Restaurar `filesystem` notifier
3. Recrear servicios con `fix-networks.yml`
4. Reiniciar Traefik para detectar servicios

---

### Problema 3: SCP no sobrescribía archivos

**Síntoma**: Cambios en configuración no se aplicaban

**Causa Raíz**: `appleboy/scp-action` por defecto no sobrescribe archivos existentes

**Solución**:
```yaml
- name: Copy Authelia files to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
    overwrite: true  # ← CRÍTICO
    source: codespartan/platform/authelia/*
    target: /opt/codespartan/platform/authelia/
```

---

### Problema 4: Docker Compose Restart no recarga volúmenes

**Síntoma**: Cambios en archivos montados no se aplicaban

**Causa Raíz**: `docker compose restart` no recarga volúmenes

**Solución**:
```bash
# ❌ NO funciona para archivos de configuración
docker compose restart authelia

# ✅ Fuerza recreación del contenedor
docker compose down
docker compose up -d --force-recreate
```

---

### Problema 5: Notificaciones por correo sin SMTP

**Síntoma**: "Te hemos enviado un correo" pero no llega nada

**Causa Raíz**: Filesystem notifier escribe a archivo, no envía correo

**Solución Temporal**: Leer archivo de notificaciones
```bash
docker exec authelia cat /data/notifications.txt
```

**Workflow**: `get-otp-link.yml` automatiza esto

---

## Estado Actual

### ✅ Funcionando Perfectamente

- **Portal SSO**: https://auth.mambo-cloud.com (HTTP 200)
- **Login**: admin/codespartan123 ✅
- **MFA**: Microsoft Authenticator con TOTP ✅
- **Servicios protegidos**: Grafana, Traefik, Backoffice ✅
- **Redirección automática**: ForwardAuth middleware ✅
- **Sesiones persistentes**: Redis + cookies ✅

### ⏸️ Preparado pero Deshabilitado

- **SMTP de Hostinger**: Configuración lista, comentada
- **WebAuthn**: Configurado como `disable: true`
- **Duo Push**: Configurado como `disable: true`

### ⚠️ Requiere Atención

1. **SMTP Debugging**
   - Determinar por qué crashea con SMTP habilitado
   - Probar diferentes configuraciones de puerto/TLS
   - Verificar conectividad desde VPS a smtp.hostinger.com

2. **Warnings de Deprecación**
   - Actualizar sintaxis de configuración a nuevas keys de Authelia 4.38+
   - Ver logs para lista completa de warnings

---

## Roadmap Completo de la Plataforma

### FASE 1: Infraestructura Base ✅ COMPLETADA
- [x] Terraform + Hetzner Cloud (VPS ARM64)
- [x] Docker installation
- [x] Traefik reverse proxy
- [x] Let's Encrypt SSL automático
- [x] Monitoring stack (VictoriaMetrics, Grafana, Loki)
- [x] Alerting (vmalert + Alertmanager + ntfy)
- [x] GitHub Actions CI/CD

### FASE 2: Security & SSO ✅ COMPLETADA
- [x] Authelia SSO deployment
- [x] Multi-Factor Authentication (TOTP)
- [x] Protect dashboards (Grafana, Traefik)
- [x] Session management with Redis
- [ ] **PENDIENTE**: SMTP notifications
- [ ] **PENDIENTE**: WebAuthn (hardware keys)

### FASE 3: Container Management 🔜 PRÓXIMA
**Objetivo**: Gestión visual de contenedores y seguridad del Docker socket

#### 3.1 Docker Socket Proxy ⭐ CRÍTICO
**Problema actual**: Traefik tiene acceso directo a `/var/run/docker.sock`
```yaml
# ⚠️ INSEGURO - Acceso total al daemon de Docker
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Riesgos**:
- Container escape (si Traefik es comprometido)
- Acceso completo al sistema host
- Violación del principio de mínimo privilegio

**Solución**: [Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)

```yaml
services:
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy
    container_name: docker-socket-proxy
    environment:
      CONTAINERS: 1        # Permitir listar contenedores
      SERVICES: 0          # Denegar servicios de Swarm
      NETWORKS: 1          # Permitir acceso a redes
      INFO: 1              # Info básica
      IMAGES: 0            # Denegar listar imágenes
      POST: 0              # Denegar operaciones destructivas
      DELETE: 0            # Denegar borrado
      BUILD: 0             # Denegar builds
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - socket_proxy
    restart: unless-stopped

  traefik:
    # Cambiar esto:
    # - /var/run/docker.sock:/var/run/docker.sock:ro

    # Por esto:
    environment:
      - DOCKER_HOST=tcp://docker-socket-proxy:2375
    networks:
      - socket_proxy
      - web
```

**Beneficios**:
- ✅ Least privilege: Traefik solo ve lo que necesita
- ✅ Read-only access a Docker API
- ✅ No puede crear/destruir contenedores
- ✅ Capa adicional de seguridad
- ✅ Auditoría de accesos al socket

**Implementación**:
1. Crear `codespartan/platform/docker-socket-proxy/`
2. `docker-compose.yml` con configuración restrictiva
3. Modificar `traefik/docker-compose.yml` para usar el proxy
4. Workflow `deploy-docker-socket-proxy.yml`
5. Testing: Verificar que Traefik sigue detectando servicios

#### 3.2 Portainer CE 📦
**Objetivo**: Interfaz web para gestión de contenedores

**Características**:
- Gestión visual de contenedores, imágenes, redes, volúmenes
- Logs en tiempo real
- Console/exec en contenedores
- Deploy de stacks (docker-compose via UI)
- Resource usage monitoring
- User management con RBAC

**Arquitectura propuesta**:
```
Usuario → Traefik → Authelia (SSO+MFA) → Portainer
                         ↓
                 Docker Socket Proxy → Docker Daemon
```

**docker-compose.yml**:
```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H tcp://docker-socket-proxy:2375  # ← Usa el proxy
    volumes:
      - portainer_data:/data
    networks:
      - web
      - socket_proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.portainer.rule=Host(`portainer.mambo-cloud.com`)
      - traefik.http.routers.portainer.entrypoints=websecure
      - traefik.http.routers.portainer.tls.certresolver=le
      - traefik.http.services.portainer.loadbalancer.server.port=9000

      # ⭐ Proteger con Authelia
      - traefik.http.routers.portainer.middlewares=authelia@docker

    restart: unless-stopped

    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M

volumes:
  portainer_data:
    name: portainer_data

networks:
  web:
    external: true
  socket_proxy:
    external: true
```

**Ventajas sobre CLI**:
- ✅ Onboarding más fácil para nuevos devs
- ✅ Visualización rápida del estado del sistema
- ✅ Operaciones comunes sin SSH
- ✅ Deploy de nuevos servicios via UI
- ✅ Templates y App Templates

**Consideraciones de Seguridad**:
- ⚠️ Portainer es poderoso - requiere SSO + MFA
- ⚠️ Limitar acceso solo a grupo `admins` en Authelia
- ⚠️ Usar docker-socket-proxy con permisos mínimos
- ⚠️ Activar audit logs en Portainer

**Workflow de despliegue**:
1. Desplegar docker-socket-proxy primero
2. Actualizar Traefik para usar el proxy
3. Verificar que Traefik sigue funcionando
4. Desplegar Portainer
5. Configurar integración con Authelia

**URL final**: https://portainer.mambo-cloud.com

#### 3.3 Mejoras Adicionales
- [ ] Watchtower para auto-updates de contenedores
- [ ] Diun para notificaciones de nuevas imágenes
- [ ] Lazy para gestión desde terminal (TUI)

**Prioridad**: ALTA
**Dependencias**: Ninguna (puede hacerse inmediatamente después de FASE 2)
**Esfuerzo estimado**: 2-3 horas

---

### FASE 4: Application Deployment 📦
- [ ] Template de aplicación con network isolation
- [ ] CI/CD pipelines por aplicación
- [ ] Staging vs Production environments
- [ ] Database backups automatizados
- [ ] Health checks y auto-healing

### FASE 5: Advanced Monitoring 📊
- [ ] Application Performance Monitoring (APM)
- [ ] Distributed tracing (Jaeger/Tempo)
- [ ] Log aggregation avanzado
- [ ] Custom dashboards por aplicación
- [ ] SLO/SLI monitoring

### FASE 6: Disaster Recovery 🔄
- [ ] Backup completo de volumes
- [ ] Disaster recovery plan
- [ ] Infrastructure as Code testing
- [ ] Blue/Green deployments
- [ ] Rollback automático

---

## Mejoras de Arquitectura Pendientes

### Alta Prioridad

#### 1. Docker Socket Proxy
**Problema**: Traefik tiene acceso directo al socket de Docker (`/var/run/docker.sock`)

**Riesgo**:
- Si Traefik es comprometido, el atacante tiene control total del host
- Puede crear contenedores privilegiados
- Puede montar el filesystem del host
- Escalación de privilegios a root del host

**Solución**: [tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)

**Beneficios**:
- Filtrado de operaciones permitidas
- Read-only access
- Logging de todas las peticiones
- Least privilege principle

**Implementación**:
```yaml
# codespartan/platform/docker-socket-proxy/docker-compose.yml
services:
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: docker-socket-proxy
    environment:
      CONTAINERS: 1  # Allow container queries
      NETWORKS: 1    # Allow network queries
      SERVICES: 0    # Deny swarm services
      POST: 0        # Deny destructive operations
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - socket_proxy
    restart: unless-stopped
```

Luego modificar Traefik:
```yaml
# Cambiar de:
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro

# A:
environment:
  - DOCKER_HOST=tcp://docker-socket-proxy:2375
networks:
  - socket_proxy
```

**Referencias**:
- https://github.com/Tecnativa/docker-socket-proxy
- https://docs.traefik.io/providers/docker/#docker-api-access

---

#### 2. Secrets Management
**Problema**: Credenciales en plaintext en archivos de configuración

**Ejemplos actuales**:
- `users_database.yml` - Password hashes
- `configuration.yml` - JWT secrets, encryption keys
- Docker Compose - SMTP passwords (cuando se habilite)

**Soluciones posibles**:

**Opción A: Docker Secrets** (recomendado para Swarm)
```yaml
services:
  authelia:
    secrets:
      - jwt_secret
      - encryption_key
    environment:
      AUTHELIA_JWT_SECRET_FILE: /run/secrets/jwt_secret

secrets:
  jwt_secret:
    file: ./secrets/jwt_secret.txt
```

**Opción B: Vault by HashiCorp** (empresarial)
- Centralización de secretos
- Rotación automática
- Audit logs
- Dynamic secrets

**Opción C: GitHub Secrets + Deploy Scripts**
- Secretos en GitHub Secrets
- Inyección durante deploy via workflows
- Actualizar secrets sin commits

**Recomendación**: Empezar con Docker Secrets, evaluar Vault si crece

---

#### 3. Portainer para Gestión Visual
**Objetivo**: UI web para gestionar contenedores

**Beneficios**:
- Visualización del estado de todos los contenedores
- Logs en tiempo real
- Shell/exec en contenedores
- Deploy de stacks via UI
- Gestión de redes y volúmenes

**Seguridad**:
- DEBE estar protegido con Authelia (SSO + MFA)
- Usar docker-socket-proxy (no acceso directo al socket)
- Solo grupo `admins` tiene acceso

**Despliegue**:
```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://docker-socket-proxy:2375
    networks:
      - web
      - socket_proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.portainer.rule=Host(`portainer.mambo-cloud.com`)
      - traefik.http.routers.portainer.middlewares=authelia@docker
      - traefik.http.services.portainer.loadbalancer.server.port=9000
```

---

### Media Prioridad

#### 4. Resource Limits Review
**Estado**: Implementados pero requieren optimización

**Acción**: Monitorear uso real y ajustar limits/reservations

**Herramientas**:
```bash
# Ver uso actual
docker stats --no-stream

# Comparar con limits en docker-compose.yml
```

#### 5. Network Isolation Audit
**Estado**: Implementado parcialmente

**Pendiente**:
- Documentar todas las redes y su propósito
- Verificar que servicios internos NO están en `web`
- Crear diagrama de redes

#### 6. Backup Strategy
**Estado**: No implementado

**Crítico para backup**:
- Volúmenes de Docker (`authelia_data`, `grafana_data`, etc.)
- Bases de datos (VictoriaMetrics, Authelia SQLite)
- Configuraciones (`/opt/codespartan/platform/`)

**Solución propuesta**:
- Restic + B2/S3
- Backup diario automatizado
- Retention: 7 daily, 4 weekly, 12 monthly
- Workflow `backup.yml`

---

### Baja Prioridad

#### 7. WebAuthn Enablement
**Estado**: Preparado pero deshabilitado

**Cambio requerido**:
```yaml
# configuration.yml
webauthn:
  disable: false  # Cambiar de true
```

**Beneficios**:
- Passwordless authentication
- Hardware keys (YubiKey)
- Biometric authentication (Face ID, Touch ID)

#### 8. Multi-User Setup
**Estado**: Solo existe usuario `admin`

**Acción**: Crear usuarios adicionales con diferentes roles
```yaml
users:
  admin:
    groups: [admins, dev]
  developer:
    groups: [dev]
  viewer:
    groups: [viewers]
```

#### 9. Email Notifications
**Estado**: SMTP configurado pero deshabilitado

**Requiere**: Debugging de por qué crashea con SMTP habilitado

---

## Workflows Creados

Durante la implementación de FASE 2 se crearon 9 workflows de GitHub Actions para troubleshooting y operaciones:

### Deployment

1. **`deploy-authelia.yml`**
   - Despliega Authelia SSO al VPS
   - SCP de archivos de configuración
   - Docker compose up
   - Health check

### Diagnostics

2. **`check-authelia-labels.yml`**
   - Verifica labels de Traefik en contenedor
   - Muestra networks del contenedor
   - Detecta routers en Traefik
   - Muestra docker-compose.yml

3. **`test-authelia-direct.yml`**
   - Prueba acceso directo a Authelia (bypass Traefik)
   - Health API (`/api/health`)
   - Root endpoint con y sin Host header
   - Test desde contenedor de Traefik

4. **`check-authelia-status.yml`**
   - Estado del contenedor (running/restarting)
   - Últimas 40 líneas de logs
   - Identificación rápida de errores

### Maintenance

5. **`show-users-db.yml`**
   - Muestra `users_database.yml`
   - Estado del contenedor
   - Últimas líneas de logs

6. **`generate-new-password.yml`**
   - Genera nuevo hash Argon2 para contraseña
   - Actualiza `users_database.yml`
   - Hace backup automático
   - Recrea contenedor
   - Valida que el nuevo hash funciona

7. **`get-otp-link.yml`**
   - Lee `/data/notifications.txt` del contenedor
   - Extrae código de verificación OTP
   - Útil para registro de dispositivos MFA

### Operations

8. **`restart-traefik-authelia.yml`**
   - Reinicia ambos servicios
   - Espera 30s para startup
   - Verifica routers de Traefik
   - Prueba acceso al portal

9. **`fix-networks.yml`**
   - Recrea red `web` si no existe
   - `docker compose down && up --force-recreate`
   - Reinicia Traefik para detectar servicios
   - Útil cuando hay problemas de conectividad

### Uso Recomendado

```bash
# Troubleshooting general
gh workflow run check-authelia-status.yml

# Problemas de routing
gh workflow run check-authelia-labels.yml
gh workflow run test-authelia-direct.yml

# Password reset
gh workflow run generate-new-password.yml

# Registro de nuevo dispositivo MFA
# (después de hacer click en "Añadir" en el portal)
gh workflow run get-otp-link.yml

# Aplicar cambios de configuración
gh workflow run fix-networks.yml
gh workflow run restart-traefik-authelia.yml
```

---

## Configuración y Credenciales

### Servicios

| Servicio | URL | Usuario | Password | MFA |
|----------|-----|---------|----------|-----|
| Authelia Portal | https://auth.mambo-cloud.com | admin | codespartan123 | TOTP (Microsoft Authenticator) |
| Grafana | https://grafana.mambo-cloud.com | admin | codespartan123 | Via Authelia |
| Traefik | https://traefik.mambo-cloud.com | admin | codespartan123 | Via Authelia |

### Archivos de Configuración

#### `users_database.yml`
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

**⚠️ IMPORTANTE**: El password hash debe generarse con:
```bash
docker exec authelia authelia crypto hash generate argon2 \
  --password 'codespartan123'
```

#### `configuration.yml` - Secciones Clave

**TOTP**:
```yaml
totp:
  disable: false
  issuer: mambo-cloud.com
  algorithm: sha1
  digits: 6
  period: 30
  skew: 1
  secret_size: 32
```

**Access Control**:
```yaml
access_control:
  default_policy: deny

  rules:
    - domain: auth.mambo-cloud.com
      policy: bypass  # Portal público

    - domain:
        - traefik.mambo-cloud.com
        - grafana.mambo-cloud.com
        - backoffice.mambo-cloud.com
      policy: two_factor
      subject:
        - "group:admins"
```

**Session**:
```yaml
session:
  name: authelia_session
  domain: mambo-cloud.com
  same_site: lax
  expiration: 1h
  inactivity: 30m
  remember_me_duration: 1M

  redis:
    host: authelia-redis
    port: 6379
    database_index: 0
```

**Notifier** (estado actual):
```yaml
notifier:
  disable_startup_check: false

  filesystem:
    filename: /data/notifications.txt

  # SMTP (Hostinger) - Preparado pero deshabilitado
  # smtp:
  #   host: smtp.hostinger.com
  #   port: 465
  #   username: iam@codespartan.es
  #   password: Codespartan$2
  #   sender: "Mambo Cloud Auth <noreply@codespartan.es>"
```

---

## Lecciones Aprendidas

### Técnicas

1. **Hashes de Password**
   - ✅ Generar en el mismo entorno donde se usan
   - ✅ Usar CLI de Authelia dentro del contenedor
   - ❌ NO generar localmente y copiar

2. **Docker Compose**
   - ✅ `down && up --force-recreate` para aplicar cambios de volúmenes
   - ❌ `restart` NO recarga archivos montados
   - ✅ Usar health checks para startup dependencies

3. **Authelia Notifiers**
   - ❌ NO se puede tener `filesystem` y `smtp` simultáneamente
   - ✅ Filesystem funciona perfectamente para testing
   - ⚠️ SMTP requiere debugging adicional

4. **Troubleshooting**
   - ✅ Crear workflows para operaciones repetitivas
   - ✅ Logs detallados en cada paso
   - ✅ Verificar estado de contenedores (running vs restarting)
   - ✅ Test directo al contenedor (bypass Traefik) para aislar problemas

5. **Network Security**
   - ✅ Redes internas (`internal: true`) para backends
   - ✅ Mínima superficie de ataque (Redis solo en red interna)
   - ⚠️ Docker socket necesita proxy de seguridad

### Operacionales

1. **Workflows como Documentación Ejecutable**
   - Los workflows creados son la mejor documentación
   - Reutilizables para troubleshooting futuro
   - Auditoría de operaciones via GitHub Actions logs

2. **Iteración Rápida**
   - SCP + SSH es más rápido que rebuild de imágenes
   - Workflows permiten probar cambios en < 1 minuto
   - Backups automáticos antes de cambios críticos

3. **Seguridad en Capas**
   - Múltiples factores de autenticación
   - Network isolation
   - Least privilege (próximo: docker-socket-proxy)
   - Monitoring y alerting

### De Proceso

1. **Documentar los Fallos**
   - Los errores son aprendizaje
   - Documentar causa raíz y solución
   - Crear workflows para prevenir recurrencia

2. **Commit Frecuente**
   - Commits pequeños y frecuentes
   - Mensajes descriptivos
   - Estado funcional en cada commit

3. **Testing en Capas**
   - Test directo al contenedor
   - Test via Traefik (routing)
   - Test end-to-end (navegador)

---

## Próximos Pasos Inmediatos

### 1. SMTP Debugging (2-3h)

**Objetivo**: Determinar por qué Authelia crashea con SMTP habilitado

**Plan**:
1. Crear contenedor de prueba de Authelia con SMTP
2. Probar conectividad a `smtp.hostinger.com:465` desde VPS
3. Revisar docs de Authelia 4.39 para sintaxis correcta de SMTP
4. Test con diferentes configuraciones:
   - Puerto 587 (STARTTLS) vs 465 (SSL)
   - `disable_require_tls: true` temporalmente
   - Diferentes valores de `timeout`

**Verificación**:
```bash
# Test conectividad SMTP desde VPS
telnet smtp.hostinger.com 465
openssl s_client -connect smtp.hostinger.com:465

# Test autenticación
docker run --rm -it authelia/authelia:latest authelia crypto hash generate argon2
```

### 2. Docker Socket Proxy (2h)

**Prioridad**: ALTA - Crítico para seguridad

**Pasos**:
1. Crear `codespartan/platform/docker-socket-proxy/`
2. `docker-compose.yml` con permisos mínimos
3. Workflow `deploy-docker-socket-proxy.yml`
4. Modificar Traefik para usar el proxy
5. Verificar que Traefik detecta servicios correctamente
6. Documentar en `DOCKER_SOCKET_PROXY.md`

### 3. Portainer Deployment (1h)

**Dependencia**: Docker Socket Proxy

**Pasos**:
1. Crear `codespartan/platform/portainer/`
2. `docker-compose.yml` con integración a socket proxy
3. Labels de Traefik + Authelia middleware
4. Workflow `deploy-portainer.yml`
5. First-time setup via UI
6. Documentar acceso y best practices

---

## Referencias

### Authelia
- [Official Documentation](https://www.authelia.com/docs/)
- [Configuration Reference](https://www.authelia.com/configuration/prologue/introduction/)
- [TOTP](https://www.authelia.com/configuration/second-factor/time-based-one-time-password/)
- [Access Control](https://www.authelia.com/configuration/security/access-control/)

### Docker Security
- [Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

### Traefik
- [ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Docker Provider](https://doc.traefik.io/traefik/providers/docker/)

---

## Changelog

### 2025-11-16
- ✅ FASE 2 completada - SSO con MFA funcionando
- ✅ Authelia desplegado con Microsoft Authenticator
- ✅ Servicios protegidos: Grafana, Traefik, Backoffice
- ⏸️ SMTP preparado pero deshabilitado (requiere debugging)
- ✅ 9 workflows de troubleshooting creados
- ✅ Documentación completa de problemas y soluciones
- ✅ Roadmap actualizado con FASE 3 (Container Management)

---

**Documento creado por**: Claude Code
**Última actualización**: 2025-11-16
**Versión**: 1.0
