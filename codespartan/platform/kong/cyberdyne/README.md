# Kong API Gateway - Cyberdyne

API Gateway para las APIs de Cyberdyne Systems usando Kong en modo DB-less (declarativo).

## Arquitectura

```
Internet --> Traefik (SSL/443) --> Kong (8000) --> API Backend (3001)
                                      |
                                      v
                                   Prometheus (metricas)
                                   Loki (logs JSON)
```

## Servicios Configurados

| Servicio | Host | Backend | Rate Limit |
|----------|------|---------|------------|
| Produccion | api.cyberdyne-systems.es | trackworks-api:3001 | 50 req/s |
| Staging | api-staging.cyberdyne-systems.es | trackworks-api-staging:3001 | 100 req/s |

## Plugins Habilitados

- **rate-limiting**: Control de tasa por IP
- **cors**: Politicas CORS por servicio
- **prometheus**: Metricas en puerto 8100
- **request-transformer**: Headers de tracking

## Redes

| Red | Subnet | Proposito |
|-----|--------|-----------|
| web | 172.20.0.0/16 | Recibe trafico de Traefik |
| kong_cyberdyne | 172.26.0.0/24 | Conecta con APIs (internal) |

## Comandos Utiles

```bash
# Ver estado
docker ps --filter "name=kong-cyberdyne"

# Ver logs
docker logs kong-cyberdyne -f

# Health check
docker exec kong-cyberdyne kong health

# Recargar configuracion (sin downtime)
docker exec kong-cyberdyne kong reload

# Ver configuracion cargada
docker exec kong-cyberdyne kong config db_export

# Metricas Prometheus
curl http://localhost:8100/metrics
```

## Verificacion

```bash
# Test produccion
curl -I https://api.cyberdyne-systems.es/api/v1/health

# Ver headers rate-limit
curl -I https://api.cyberdyne-systems.es/api/v1/health | grep -i ratelimit

# Test staging
curl -I https://api-staging.cyberdyne-systems.es/api/v1/health
```

## Troubleshooting

### Kong no inicia

1. Validar kong.yml:
   ```bash
   docker run --rm -v $(pwd)/kong.yml:/kong.yml kong:3.9 kong config parse /kong.yml
   ```

2. Verificar redes:
   ```bash
   docker network ls | grep kong
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

1. Modificar `kong.yml` (cambiar minute/second)
2. Recargar sin downtime:
   ```bash
   docker exec kong-cyberdyne kong reload
   ```

## Archivos

- `docker-compose.yml` - Configuracion del contenedor Kong
- `kong.yml` - Configuracion declarativa (servicios, rutas, plugins)

## Recursos

- CPU: 0.5 cores (limite)
- RAM: 512 MB (limite), ~150-200 MB uso real
