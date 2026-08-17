# 🔒 Patrón de Aislamiento de Redes

## 🎯 Objetivo

Implementar aislamiento de red entre aplicaciones para mejorar la seguridad, evitando que diferentes aplicaciones puedan comunicarse entre sí innecesariamente.

## 🏗️ Arquitectura de Redes

### Diagrama de Red

```
┌─────────────────────────────────────────────────────────────┐
│                      Red "web" (Externa)                     │
│                  Gestionada por Traefik                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Traefik    │    │ cyberdyne-   │    │  another-    │  │
│  │    Proxy     │───▶│   frontend   │    │     web      │  │
│  └──────────────┘    └──────┬───────┘    └──────┬───────┘  │
│                             │                     │           │
└─────────────────────────────┼─────────────────────┼──────────┘
                              │                     │
                 ┌────────────▼──────┐  ┌──────────▼──────┐
                 │  cyberdyne_net    │  │   dental_net    │
                 │   (172.20.0.0/24) │  │ (172.21.0.0/24) │
                 │                   │  │                 │
                 │  ┌─────────────┐  │  │ ┌────────────┐ │
                 │  │ Backend API │  │  │ │  Database  │ │
                 │  └──────┬──────┘  │  │ └─────────── │ │
                 │         │         │  │               │ │
                 │  ┌──────▼──────┐  │  │               │ │
                 │  │  PostgreSQL │  │  │               │ │
                 │  └─────────────┘  │  │               │ │
                 └───────────────────┘  └─────────────────┘
                  RED AISLADA             RED AISLADA
```

### Tipos de Redes

#### 1. Red `web` (Externa)
- **Propósito**: Comunicación con Traefik
- **Configuración**: `external: true`
- **Acceso**: Todos los servicios que necesiten ser accesibles desde internet
- **Gestión**: Creada manualmente, compartida por todas las apps

```yaml
networks:
  web:
    external: true
```

#### 2. Redes Internas (`*_internal`)
- **Propósito**: Comunicación entre servicios de la misma aplicación
- **Configuración**: `internal: true` o `internal: false` según necesidad
- **Acceso**: SOLO servicios de la misma app
- **Gestión**: Creada automáticamente por docker-compose

```yaml
networks:
  backend:
    name: myapp_internal
    driver: bridge
    internal: true  # Sin acceso a internet
    ipam:
      config:
        - subnet: 172.23.0.0/24
```

## 📋 Reglas de Seguridad

### ✅ Buenas Prácticas

1. **Frontend/Backend expuesto** → Conectado a `web` + red interna
   ```yaml
   services:
     api:
       networks:
         - web           # Para Traefik
         - myapp_net     # Para DB/cache
   ```

2. **Base de datos** → SOLO red interna
   ```yaml
   services:
     database:
       networks:
         - myapp_net     # NO conectar a 'web'
   ```

3. **Cache/Redis** → SOLO red interna
   ```yaml
   services:
     redis:
       networks:
         - myapp_net     # NO conectar a 'web'
   ```

### ❌ Malas Prácticas

```yaml
# ❌ MAL: Base de datos en red pública
services:
  database:
    networks:
      - web  # NUNCA hacer esto

# ❌ MAL: Todos los servicios en web
services:
  app:
    networks:
      - web
  db:
    networks:
      - web  # Expone DB innecesariamente

# ❌ MAL: Sin redes definidas (usa red default compartida)
services:
  app:
    # Sin definir networks
```

## 🔐 Niveles de Aislamiento

### Nivel 1: Red Interna con Internet (`internal: false`)

Permite al servicio acceder a internet pero no ser accesible desde fuera.

```yaml
networks:
  backend:
    name: myapp_internal
    driver: bridge
    internal: false  # Puede acceder a internet
    ipam:
      config:
        - subnet: 172.23.0.0/24
```

**Usar cuando:**
- El servicio necesita descargar datos externos
- Requiere acceso a APIs externas
- Necesita actualizaciones desde internet

**Ejemplo:** Backend que consume API externa

### Nivel 2: Red Completamente Aislada (`internal: true`)

El servicio NO puede acceder a internet, máxima seguridad.

```yaml
networks:
  backend:
    name: myapp_internal
    driver: bridge
    internal: true  # Sin acceso a internet
    ipam:
      config:
        - subnet: 172.23.0.0/24
```

**Usar cuando:**
- Base de datos (PostgreSQL, MySQL, MongoDB)
- Cache (Redis, Memcached)
- Servicios internos sin necesidad de internet

**Ejemplo:** Base de datos PostgreSQL

## 📊 Testing del Aislamiento

### Verificar que la DB NO es accesible desde otra app

```bash
# Conectar al contenedor de cyberdyne
docker exec -it cyberdyne-frontend sh

# Intentar conectar a la DB de otro producto (debería FALLAR)
ping another-product-db
# ping: bad address 'another-product-db'

curl http://another-product-db:5432
# Could not resolve host: another-product-db
```

### Verificar que la app SÍ puede conectar a su propia DB

```bash
# Conectar al contenedor de la app
docker exec -it myapp-api sh

# Conectar a su propia DB (debería FUNCIONAR)
ping myapp-db
# PING myapp-db (172.23.0.2): 56 data bytes

psql -h myapp-db -U appuser -d appdb
# Conecta correctamente ✅
```

## 🎯 Ejemplo Completo: App con Frontend + Backend + DB

```yaml
version: '3.8'

services:
  # Frontend - Accesible desde internet
  frontend:
    image: nginx:alpine
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`myapp.mambo-cloud.com`)
      - traefik.http.routers.myapp.entrypoints=websecure
      - traefik.http.routers.myapp.tls.certresolver=le
    networks:
      - web        # Para Traefik
      - frontend   # Para comunicarse con backend
    restart: unless-stopped

  # Backend API - Accesible desde internet
  backend:
    image: node:18-alpine
    environment:
      - DATABASE_URL=postgresql://user:pass@database:5432/mydb
      - REDIS_URL=redis://cache:6379
    networks:
      - web        # Para Traefik (endpoint API)
      - frontend   # Para recibir requests del frontend
      - backend    # Para conectar a DB/Redis
    restart: unless-stopped

  # Database - SOLO red interna
  database:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=secretpassword
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - backend    # SOLO backend, NO web
    restart: unless-stopped

  # Redis Cache - SOLO red interna
  cache:
    image: redis:7-alpine
    networks:
      - backend    # SOLO backend, NO web
    restart: unless-stopped

networks:
  web:
    external: true

  frontend:
    name: myapp_frontend_net
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.30.0.0/24

  backend:
    name: myapp_backend_net
    driver: bridge
    internal: true  # Sin internet - máxima seguridad
    ipam:
      config:
        - subnet: 172.31.0.0/24

volumes:
  db-data:
```

## 🚨 Troubleshooting

### Problema: "Network not found"

```bash
# Crear la red web manualmente
docker network create web
```

### Problema: "Servicio no puede conectar a DB"

Verificar que ambos servicios están en la misma red interna:

```bash
docker network inspect myapp_backend_net

# Deberías ver tanto el backend como la DB listados
```

### Problema: "Container name already in use"

```bash
# Limpiar contenedores y redes antiguas
docker compose down
docker network prune
docker compose up -d
```

## 📚 Referencias

- [Docker Networks Documentation](https://docs.docker.com/network/)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Network Security Best Practices](https://docs.docker.com/network/network-tutorial-standalone/)

---

**Mantenido por**: CodeSpartan Team
**Última actualización**: 2025-10-15
