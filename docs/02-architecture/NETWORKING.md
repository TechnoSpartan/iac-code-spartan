# Networking - Arquitectura de Redes

Documentación sobre la arquitectura de redes de la plataforma.

## Redes Docker

### Red Externa: `web`

Red externa compartida para servicios que necesitan ser accesibles desde Traefik.

**Servicios conectados:**
- Traefik (reverse proxy)
- Aplicaciones frontend
- Dashboards (Grafana, Traefik dashboard)

**Configuración:**
```yaml
networks:
  web:
    external: true
```

### Redes Internas (Aislamiento)

Cada aplicación puede tener su propia red interna para aislamiento.

**Ejemplo:**
```yaml
networks:
  app_internal:
    driver: bridge
    internal: true  # Sin acceso a internet
    ipam:
      config:
        - subnet: 172.22.0.0/24
```

## Aislamiento de Red

### Estado Actual

- Red `web` compartida para todas las aplicaciones
- Algunas aplicaciones tienen redes internas propias

### Objetivo (Roadmap)

- Cada dominio en su red interna aislada
- Solo Kong gateways son dual-homed (web + internal)
- Máximo aislamiento entre aplicaciones

Ver [Arquitectura](ARCHITECTURE.md) para más detalles sobre el roadmap.

## Conectividad

### Flujo de Tráfico

```
Internet → Traefik (red: web) → Aplicación (red: web o internal)
```

### DNS Interno

Los contenedores pueden resolverse por nombre:
- `traefik` → IP del contenedor Traefik
- `grafana` → IP del contenedor Grafana
- `[app-name]` → IP del contenedor de la aplicación

## Troubleshooting de Red

```bash
# Ver redes Docker
docker network ls

# Inspeccionar red
docker network inspect web

# Ver contenedores en una red
docker network inspect web | grep -A 5 Containers

# Probar conectividad entre contenedores
docker exec [container1] ping [container2]
```

## Documentación Relacionada

- [Arquitectura Completa](ARCHITECTURE.md) - Diagramas y arquitectura detallada
- [System Overview](OVERVIEW.md) - Visión general del sistema

