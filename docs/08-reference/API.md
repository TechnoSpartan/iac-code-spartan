# APIs y Endpoints - Referencia

Documentación de APIs y endpoints disponibles en la plataforma.

## Traefik API

**Endpoint:** https://traefik.mambo-cloud.com/api

**Autenticación:** Basic Auth (admin/codespartan123)

**Endpoints principales:**
- `/api/http/routers` - Lista de routers configurados
- `/api/http/services` - Lista de servicios
- `/api/http/middlewares` - Lista de middlewares
- `/api/rawdata` - Datos raw de configuración

## Grafana API

**Endpoint:** https://grafana.mambo-cloud.com/api

**Autenticación:** Authelia SSO

**Endpoints principales:**
- `/api/datasources` - Gestión de datasources
- `/api/dashboards` - Gestión de dashboards
- `/api/alerts` - Gestión de alertas

## VictoriaMetrics API

**Endpoint:** http://localhost:8428/api/v1

**Endpoints principales:**
- `/api/v1/query` - Consultar métricas
- `/api/v1/query_range` - Consultar métricas en rango de tiempo
- `/api/v1/label/__name__/values` - Listar nombres de métricas

## Loki API

**Endpoint:** http://localhost:3100

**Endpoints principales:**
- `/ready` - Health check
- `/loki/api/v1/query` - Consultar logs
- `/loki/api/v1/query_range` - Consultar logs en rango de tiempo

## Alertmanager API

**Endpoint:** http://localhost:9093/api/v2

**Endpoints principales:**
- `/api/v2/alerts` - Listar alertas activas
- `/api/v2/silences` - Gestión de silences
- `/api/v2/status` - Estado del Alertmanager

## vmalert API

**Endpoint:** http://localhost:8880/api/v1

**Endpoints principales:**
- `/api/v1/rules` - Listar reglas de alertas
- `/api/v1/alerts` - Listar alertas activas

## Ejemplos de Uso

### Consultar métricas

```bash
# CPU usage
curl 'http://localhost:8428/api/v1/query?query=100%20-%20(avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))%20*%20100)'

# Memory usage
curl 'http://localhost:8428/api/v1/query?query=(1%20-%20(node_memory_MemAvailable_bytes%20/%20node_memory_MemTotal_bytes))%20*%20100'
```

### Consultar logs

```bash
# Logs de Traefik
curl 'http://localhost:3100/loki/api/v1/query_range?query={container="traefik"}&limit=100'
```

## Documentación Completa

Para más detalles sobre cada API, consulta la documentación oficial:
- [Traefik API](https://doc.traefik.io/traefik/operations/api/)
- [Grafana API](https://grafana.com/docs/grafana/latest/developers/http_api/)
- [VictoriaMetrics API](https://docs.victoriametrics.com/#prometheus-querying-api-usage)
- [Loki API](https://grafana.com/docs/loki/latest/api/)

