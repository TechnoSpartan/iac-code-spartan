# Portainer CE - Container Management UI

**FASE 3.2**: Gestión visual de contenedores Docker

## Descripción

Portainer Community Edition proporciona una interfaz web para gestionar contenedores, imágenes, redes y volúmenes Docker sin necesidad de SSH o comandos CLI.

## Características

- 📊 **Dashboard visual** - Estado de todos los contenedores en tiempo real
- 📝 **Logs en vivo** - Ver logs de contenedores sin SSH
- 💻 **Console/Exec** - Ejecutar comandos dentro de contenedores desde el navegador
- 🚀 **Deploy stacks** - Desplegar docker-compose.yml vía UI
- 📈 **Resource monitoring** - CPU, RAM, Network por contenedor
- 👥 **User management** - RBAC (Role-Based Access Control)
- 🔐 **Protegido por Authelia** - SSO + 2FA obligatorio

## Acceso

- **URL:** https://portainer.mambo-cloud.com
- **Autenticación:** Via Authelia (https://auth.mambo-cloud.com)
- **Credenciales:** admin / codespartan123 + TOTP

## Arquitectura de Seguridad

```
Usuario → Traefik → Authelia (SSO+MFA) → Portainer
                         ↓
                 Docker Socket Proxy → Docker Daemon
```

**Seguridad implementada:**

- ✅ Portainer NO tiene acceso directo a `/var/run/docker.sock`
- ✅ Usa `docker-socket-proxy` con permisos read-only
- ✅ Protegido por Authelia SSO + Multi-Factor Authentication
- ✅ Solo usuarios en grupo `admins` pueden acceder
- ✅ Rate limiting estricto (10 req/s)
- ✅ SSL/TLS automático vía Let's Encrypt

## Configuración

### docker-compose.yml

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://docker-socket-proxy:2375  # Conexión segura vía proxy
    networks:
      - web          # Para Traefik
      - docker_api   # Para Docker socket proxy
    labels:
      - traefik.http.routers.portainer.middlewares=authelia@docker
```

### Redes

- **web** - Red pública para Traefik (routing)
- **docker_api** - Red interna para comunicación con docker-socket-proxy

## Deployment

### Via GitHub Actions (Recomendado)

```bash
gh workflow run deploy-portainer.yml
```

### Manual

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Deploy
cd /opt/codespartan/platform/portainer
docker compose up -d

# Verificar
docker ps --filter "name=portainer"
docker logs portainer
```

## Initial Setup

Al acceder por primera vez a https://portainer.mambo-cloud.com:

1. **Authelia SSO** - Login con admin/codespartan123 + TOTP
2. **Portainer Welcome** - Crear contraseña de admin de Portainer
3. **Environment** - Ya está configurado (Docker via socket proxy)
4. **Dashboard** - Listo para usar

## Operaciones Comunes

### Ver contenedores
1. Ir a **Containers**
2. Ver lista de todos los contenedores running/stopped

### Ver logs
1. Click en contenedor
2. Tab **Logs**
3. Ver logs en tiempo real

### Exec en contenedor
1. Click en contenedor
2. Tab **Console**
3. Command: `/bin/sh` o `/bin/bash`
4. Click **Connect**

### Deploy nuevo stack
1. **Stacks** → **Add stack**
2. Pegar docker-compose.yml
3. Click **Deploy**

## Troubleshooting

### Portainer no conecta a Docker

```bash
# Verificar docker-socket-proxy está running
docker ps --filter "name=docker-socket-proxy"

# Verificar red docker_api
docker network inspect docker_api

# Test de conectividad
docker exec portainer wget -qO- http://docker-socket-proxy:2375/version
```

### No puedo acceder (Authelia redirect loop)

```bash
# Verificar Authelia está healthy
docker ps --filter "name=authelia"

# Verificar logs de Traefik
docker logs traefik | grep portainer
```

### Portainer muestra "unauthorized endpoint"

```bash
# Recrear contenedor
docker compose down
docker compose up -d --force-recreate
```

## Resource Limits

- **CPU Limit:** 0.5 cores (50%)
- **Memory Limit:** 512M
- **CPU Reservation:** 0.1 cores
- **Memory Reservation:** 128M

## Health Check

Portainer incluye health check que verifica:
- API endpoint `/api/system/status` responde HTTP 200
- Intervalo: cada 30s
- Timeout: 5s
- Retries: 3
- Start period: 40s

## Referencias

- [Portainer Documentation](https://docs.portainer.io/)
- [Portainer CE vs BE](https://www.portainer.io/pricing)
- [Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy)
- [Authelia Integration](../../docs/05-security/AUTHELIA.md)

---

**Última actualización:** 2025-12-19
**Versión:** 1.0.0
**Estado:** ✅ Configurado y listo para deployment
