# Kong API Gateway

Kong API Gateway proporciona rate limiting, CORS, logging y otras funcionalidades de API management para las aplicaciones de la plataforma.

## Arquitectura

```
Internet --> Traefik (SSL/443) --> Kong (8000) --> API Backend (3001) --> MongoDB
                                      |
                                      v
                                   Prometheus (metricas :8100)
                                   Loki (logs JSON)
```

## Configuracion Actual

### Servicios Configurados

| Servicio | Host | Backend | Rate Limit | Estado |
|----------|------|---------|------------|--------|
| Produccion | api.cyberdyne-systems.es | trackworks-api:3001 | 50 req/s | Activo |
| Staging | api-staging.cyberdyne-systems.es | trackworks-api-staging:3001 | 100 req/s | Activo |

### Plugins Habilitados

| Plugin | Configuracion | Proposito |
|--------|---------------|-----------|
| rate-limiting | 50/100 req/s por IP | Control de trafico |
| cors | Origenes por servicio | Cross-Origin Resource Sharing |
| prometheus | Puerto 8100 | Metricas |
| request-transformer | Headers X-Kong-* | Tracking |

### Redes

| Red | Subnet | Proposito |
|-----|--------|-----------|
| web | 172.20.0.0/16 | Recibe trafico de Traefik |
| kong_cyberdyne | 172.26.0.0/24 | Conecta con APIs (internal) |

## Archivos de Configuracion

### Ubicaciones

```
codespartan/platform/kong/cyberdyne/
├── docker-compose.yml    # Configuracion del contenedor
├── kong.yml              # Configuracion declarativa
└── README.md             # Documentacion
```

### docker-compose.yml

```yaml
services:
  kong:
    image: kong:3.9
    container_name: kong-cyberdyne
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/declarative/kong.yml
      KONG_PROXY_LISTEN: "0.0.0.0:8000"
      KONG_STATUS_LISTEN: "0.0.0.0:8100"
    networks:
      - web
      - kong_cyberdyne
```

### kong.yml (extracto)

```yaml
_format_version: "3.0"
services:
  - name: cyberdyne-api-production
    url: http://trackworks-api:3001
    routes:
      - name: api-production-route
        hosts:
          - api.cyberdyne-systems.es
    plugins:
      - name: rate-limiting
        config:
          second: 50
          minute: 3000
      - name: cors
        config:
          origins:
            - https://cyberdyne-systems.es
            - https://www.cyberdyne-systems.es
```

## Comandos Utiles

### Estado y Logs

```bash
# Ver estado del contenedor
docker ps --filter "name=kong-cyberdyne"

# Ver logs en tiempo real
docker logs kong-cyberdyne -f

# Health check
docker exec kong-cyberdyne kong health

# Ver configuracion cargada
docker exec kong-cyberdyne kong config db_export
```

### Recargar Configuracion

```bash
# Sin downtime
docker exec kong-cyberdyne kong reload
```

### Metricas

```bash
# Desde el VPS
curl http://localhost:8100/metrics

# Metricas en Grafana
# Job: kong-cyberdyne (configurado en prometheus.yml)
```

## Verificacion

### Test de Endpoints

```bash
# Produccion
curl -I https://api.cyberdyne-systems.es/api/v1/health

# Staging
curl -I https://api-staging.cyberdyne-systems.es/api/v1/health
```

### Verificar Rate Limiting

```bash
# Headers de rate limit en respuesta
curl -I https://api.cyberdyne-systems.es/api/v1/health | grep -i ratelimit

# Respuesta esperada:
# ratelimit-limit: 50
# ratelimit-remaining: 49
# ratelimit-reset: 1
```

### Verificar Headers de Kong

```bash
curl -I https://api.cyberdyne-systems.es/api/v1/health | grep -i kong

# Respuesta esperada:
# server: kong/3.9.1
```

## Troubleshooting

### Kong no inicia

1. Validar kong.yml:
   ```bash
   docker run --rm \
     -e KONG_DATABASE=off \
     -v /opt/codespartan/platform/kong/cyberdyne/kong.yml:/kong.yml \
     kong:3.9 kong config parse /kong.yml
   ```

2. Verificar redes:
   ```bash
   docker network ls | grep kong
   docker network inspect kong_cyberdyne
   ```

### API no responde via Kong

1. Verificar conectividad desde Kong:
   ```bash
   docker exec kong-cyberdyne wget -qO- http://trackworks-api:3001/api/v1/health
   ```

2. Ver logs de Kong:
   ```bash
   docker logs kong-cyberdyne --tail 100
   ```

3. Verificar que API esta en red kong_cyberdyne:
   ```bash
   docker inspect trackworks-api --format '{{json .NetworkSettings.Networks}}' | jq
   ```

### Rate limit demasiado agresivo

1. Modificar `/opt/codespartan/platform/kong/cyberdyne/kong.yml`
2. Cambiar valores de `second` y `minute` en rate-limiting
3. Recargar sin downtime:
   ```bash
   docker exec kong-cyberdyne kong reload
   ```

### Traefik no descubre Kong

1. Verificar labels en docker-compose.yml
2. Verificar que Kong esta en red `web`
3. Reiniciar Traefik:
   ```bash
   docker restart traefik
   ```

## Anadir Nueva API a Kong

### 1. Editar kong.yml

Agregar nuevo servicio:

```yaml
services:
  - name: nueva-api
    url: http://nueva-api-container:3000
    routes:
      - name: nueva-api-route
        hosts:
          - api.nuevo-dominio.com
    plugins:
      - name: rate-limiting
        config:
          second: 50
          minute: 3000
      - name: cors
        config:
          origins:
            - https://nuevo-dominio.com
```

### 2. Actualizar docker-compose.yml de la API

```yaml
# Quitar labels de Traefik
# Cambiar red de 'web' a 'kong_cyberdyne'
networks:
  - kong_cyberdyne
  - api_internal
```

### 3. Agregar router en Kong docker-compose.yml

```yaml
labels:
  - traefik.http.routers.kong-nueva-api.rule=Host(`api.nuevo-dominio.com`)
  - traefik.http.routers.kong-nueva-api.service=kong-cyberdyne
```

### 4. Redeploy

```bash
# Deploy Kong
cd /opt/codespartan/platform/kong/cyberdyne
docker compose up -d

# Deploy nueva API
cd /opt/codespartan/apps/nuevo-dominio/api
docker compose up -d
```

## Recursos

### Consumo

| Recurso | Limite | Uso Real |
|---------|--------|----------|
| CPU | 0.5 cores | ~0.1 cores |
| RAM | 512 MB | ~150-200 MB |

### Documentacion Externa

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Declarative Config](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Kong Plugins](https://docs.konghq.com/hub/)

## Historial de Cambios

| Fecha | Cambio |
|-------|--------|
| 2026-01-16 | Implementacion inicial Kong para Cyberdyne |
| 2026-01-16 | Rate limiting 50 req/s prod, 100 req/s staging |
| 2026-01-16 | Integracion con Traefik y Prometheus |
