# 🌐 Network Initialization

Este directorio contiene la configuración para inicializar la red `web` con subnet explícita.

## ¿Por qué es necesario?

La red `web` es compartida por múltiples servicios y debe crearse **antes** de desplegar Traefik y otras aplicaciones. Al definirla con subnet explícita, obtenemos:

- ✅ IPs predecibles
- ✅ Mejor documentación
- ✅ Facilita troubleshooting
- ✅ Permite reglas de firewall específicas

## Uso

### Primera vez (Inicialización)

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Crear directorio
mkdir -p /opt/codespartan/platform/networks
cd /opt/codespartan/platform/networks

# Copiar docker-compose.yml (se hace vía deploy workflow)

# Crear la red
docker compose up -d

# Verificar
docker network inspect web
```

### ¿Qué hace?

1. Crea la red `web` con subnet `172.20.0.0/16`
2. Asigna gateway `172.20.0.1`
3. Ejecuta un contenedor dummy que termina inmediatamente
4. Deja la red creada para uso de otros servicios

### Verificación

```bash
# Listar redes
docker network ls | grep web

# Inspeccionar subnet
docker network inspect web --format='{{.IPAM.Config}}'
# Esperado: [{172.20.0.0/16  172.20.0.1 map[]}]
```

## Subnets Asignadas

| Red | Subnet | Uso | Internal |
|-----|--------|-----|----------|
| `web` | 172.20.0.0/16 | Pública (Traefik routing) | No |
| `authelia_internal` | 172.21.0.0/24 | Authelia + Redis | Sí |
| `api_trackworks` | 172.22.0.0/24 | TruckWorks API + MongoDB | Sí |
| `redmine_internal` | 172.23.0.0/24 | Redmine + PostgreSQL | Sí |
| `monitoring` | 172.24.0.0/24 | Stack de monitoreo | No |
| `docker_api` | 172.25.0.0/24 | Docker socket proxy | Sí |

## Notas

- La red `web` **NO** debe ser `internal: true` porque necesita acceso a internet para SSL certificates
- Los servicios pueden estar en múltiples redes (dual-homed)
- Las redes internas bloquean acceso a internet
