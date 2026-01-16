# Kong API Gateway - Template

Template para desplegar Kong API Gateway en modo DB-less para nuevos dominios.

## Uso Rapido

### 1. Copiar el template

```bash
# Reemplazar DOMAIN_NAME con el nombre del dominio (ej: dental-io, mambo-cloud)
cp -r codespartan/platform/kong/_TEMPLATE codespartan/platform/kong/DOMAIN_NAME
```

### 2. Configurar variables

Reemplazar las siguientes variables en `docker-compose.yml` y `kong.yml`:

| Variable | Descripcion | Ejemplo |
|----------|-------------|---------|
| `{{DOMAIN_NAME}}` | Nombre corto del dominio | `dental-io` |
| `{{DOMAIN_HOST}}` | Dominio principal | `dental-io.com` |
| `{{API_HOST}}` | Host de la API produccion | `api.dental-io.com` |
| `{{API_STAGING_HOST}}` | Host de la API staging | `api-staging.dental-io.com` |
| `{{API_CONTAINER}}` | Nombre del contenedor API | `dental-api` |
| `{{API_STAGING_CONTAINER}}` | Contenedor API staging | `dental-api-staging` |
| `{{API_PORT}}` | Puerto interno de la API | `3000` |
| `{{NETWORK_SUBNET}}` | Subnet de la red interna | `172.27.0.0/24` |
| `{{CORS_ORIGIN_PROD}}` | Origen CORS produccion | `https://dental-io.com` |
| `{{CORS_ORIGIN_WWW}}` | Origen CORS www | `https://www.dental-io.com` |
| `{{CORS_ORIGIN_STAGING}}` | Origen CORS staging | `https://staging.dental-io.com` |

### 3. Usar sed para reemplazar (opcional)

```bash
cd codespartan/platform/kong/DOMAIN_NAME

# Reemplazar todas las variables de una vez
sed -i '' 's/{{DOMAIN_NAME}}/dental-io/g' docker-compose.yml kong.yml
sed -i '' 's/{{DOMAIN_HOST}}/dental-io.com/g' docker-compose.yml kong.yml
sed -i '' 's/{{API_HOST}}/api.dental-io.com/g' docker-compose.yml kong.yml
sed -i '' 's/{{API_STAGING_HOST}}/api-staging.dental-io.com/g' docker-compose.yml kong.yml
sed -i '' 's/{{API_CONTAINER}}/dental-api/g' docker-compose.yml kong.yml
sed -i '' 's/{{API_STAGING_CONTAINER}}/dental-api-staging/g' docker-compose.yml kong.yml
sed -i '' 's/{{API_PORT}}/3000/g' docker-compose.yml kong.yml
sed -i '' 's/{{NETWORK_SUBNET}}/172.27.0.0\/24/g' docker-compose.yml kong.yml
sed -i '' 's/{{CORS_ORIGIN_PROD}}/https:\/\/dental-io.com/g' kong.yml
sed -i '' 's/{{CORS_ORIGIN_WWW}}/https:\/\/www.dental-io.com/g' kong.yml
sed -i '' 's/{{CORS_ORIGIN_STAGING}}/https:\/\/staging.dental-io.com/g' kong.yml
```

### 4. Crear workflow de GitHub Actions

Copiar y adaptar `.github/workflows/deploy-kong-cyberdyne.yml`:

```bash
cp .github/workflows/deploy-kong-cyberdyne.yml .github/workflows/deploy-kong-DOMAIN_NAME.yml
```

Editar el archivo y reemplazar `cyberdyne` por tu dominio.

### 5. Modificar la API existente

La API debe cambiar de red `web` a `kong_DOMAIN_NAME`:

```yaml
# ANTES (docker-compose.yml de la API)
networks:
  - web

# DESPUES
networks:
  - kong_DOMAIN_NAME
  - app_internal  # red interna para DB si aplica

# Y quitar los labels de Traefik de la API
# Kong ahora maneja el routing
```

### 6. Agregar scrape de Prometheus

En `codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'kong-DOMAIN_NAME'
    static_configs:
      - targets: ['kong-DOMAIN_NAME:8100']
    metrics_path: /metrics
```

## Arquitectura

```
Internet --> Traefik (SSL/443) --> Kong (8000) --> API Backend (PORT)
                                      |
                                      v
                                   Prometheus (metricas :8100)
                                   Loki (logs JSON)
```

## Redes

| Red | Tipo | Proposito |
|-----|------|-----------|
| `web` | Externa | Traefik -> Kong |
| `kong_DOMAIN_NAME` | Interna | Kong -> API |
| `app_internal` | Interna | API -> DB |

## Subnets Reservadas

| Subnet | Uso |
|--------|-----|
| 172.20.0.0/16 | web (Traefik) |
| 172.22.0.0/24 | trackworks (Cyberdyne interno) |
| 172.26.0.0/24 | kong_cyberdyne |
| 172.27.0.0/24 | kong_dental (disponible) |
| 172.28.0.0/24 | kong_mambo (disponible) |

## Verificacion

```bash
# Test endpoint produccion
curl -I https://api.DOMAIN.com/health

# Verificar headers rate-limit
curl -I https://api.DOMAIN.com/health | grep -i ratelimit

# Ver logs de Kong
docker logs kong-DOMAIN_NAME -f

# Health check
docker exec kong-DOMAIN_NAME kong health

# Metricas
curl http://localhost:8100/metrics
```

## Plugins Incluidos

| Plugin | Configuracion | Proposito |
|--------|---------------|-----------|
| rate-limiting | 50 req/s prod, 100 req/s staging | Control de trafico |
| cors | Origenes por servicio | Cross-Origin Resource Sharing |
| prometheus | Puerto 8100 | Metricas |
| request-transformer | Headers X-Kong-* | Tracking |

## Troubleshooting

### Kong no inicia

```bash
# Validar kong.yml
docker run --rm -e KONG_DATABASE=off -v $(pwd)/kong.yml:/kong.yml kong:3.9 kong config parse /kong.yml
```

### API no responde via Kong

```bash
# Verificar conectividad desde Kong
docker exec kong-DOMAIN_NAME wget -qO- http://API_CONTAINER:PORT/health

# Verificar que API esta en red kong_DOMAIN_NAME
docker inspect API_CONTAINER --format '{{json .NetworkSettings.Networks}}' | jq
```

### Rate limit demasiado agresivo

1. Modificar `kong.yml` (cambiar valores de second/minute)
2. Recargar sin downtime: `docker exec kong-DOMAIN_NAME kong reload`

## Recursos

- CPU: 0.5 cores (limite)
- RAM: 512 MB (limite), ~150-200 MB uso real

## Referencias

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Declarative Config](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Ejemplo Cyberdyne](../cyberdyne/)
