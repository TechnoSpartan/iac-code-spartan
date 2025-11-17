# CodeSpartan Cloud

Main domain for CodeSpartan tech services

**Domain**: codespartan.cloud

## Subdomains

- **www** - Main website (`www.codespartan.cloud`)
- **ui** - UI/Design system - Storybook (`ui.codespartan.cloud`)
- **api** - API services (production) - *Pendiente*
- **api-staging** - API services (staging) - *Pendiente*
- **staging** - Staging environment - *Pendiente*
- **lab** - Laboratory environment - *Pendiente*
- **lab-staging** - Lab staging - *Pendiente*
- **mambo** - Mambo service - *Pendiente*

## Status

✅ **Desplegado y funcionando**

- ✅ `www.codespartan.cloud` - Funcionando
- ✅ `ui.codespartan.cloud` - Funcionando

## Arquitectura

Todos los servicios siguen la arquitectura estándar de la plataforma CodeSpartan:
- Traefik reverse proxy
- SSL automático via Let's Encrypt
- Docker Compose deployments
- Network isolation per service
- **File Provider** para routing (ver [TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md](../../docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md))

## Despliegue

### Despliegue Automático (CI/CD)

Los servicios se despliegan automáticamente mediante GitHub Actions:

#### WWW (Main Website)
- **Workflow**: `Deploy CodeSpartan WWW`
- **Trigger**: Push a `codespartan/apps/codespartan-cloud/www/**`
- **Imagen**: `ghcr.io/technospartan/codespartan-www:latest`

#### UI (Storybook)
- **Workflow**: `Deploy CodeSpartan UI (Storybook)`
- **Trigger**: Push a `codespartan/apps/codespartan-cloud/ui/**`
- **Imagen**: `ghcr.io/technospartan/codespartan-ui:latest`

### Despliegue Manual

```bash
# Conectar al VPS
ssh leonidas@91.98.137.217

# Desplegar WWW
cd /opt/codespartan/apps/codespartan-cloud/www
docker compose pull
docker compose up -d

# Desplegar UI
cd /opt/codespartan/apps/codespartan-cloud/ui
docker compose pull
docker compose up -d
```

## Configuración de Traefik

Los routers están configurados en el **File Provider** de Traefik:

**Archivo**: `codespartan/platform/traefik/dynamic-config.yml`

```yaml
http:
  routers:
    codespartan-www:
      rule: "Host(`www.codespartan.cloud`)"
      entrypoints:
        - websecure
      service: codespartan-www-service
      tls:
        certResolver: le
      middlewares:
        - security-headers
        - compression

    codespartan-ui:
      rule: "Host(`ui.codespartan.cloud`)"
      entrypoints:
        - websecure
      service: codespartan-ui-service
      tls:
        certResolver: le
      middlewares:
        - security-headers
        - compression

  services:
    codespartan-www-service:
      loadBalancer:
        servers:
          - url: "http://codespartan-www:80"

    codespartan-ui-service:
      loadBalancer:
        servers:
          - url: "http://codespartan-ui:80"
```

### Agregar Nuevo Subdominio

1. Agregar router y servicio en `dynamic-config.yml`
2. Commit y push
3. Ejecutar `Deploy Traefik`
4. Ejecutar `Restart Traefik`

Ver [TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md](../../docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md) para más detalles.

## Troubleshooting

Si los dominios devuelven 404:

1. **Verificar contenedores**:
   ```bash
   gh workflow run "Quick Status"
   ```

2. **Verificar routers**:
   ```bash
   gh workflow run "Check Traefik Routers (Final)"
   ```

3. **Reiniciar Traefik**:
   ```bash
   gh workflow run "Restart Traefik"
   ```

4. **Consultar documentación completa**:
   - [TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md](../../docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md)

## Monitoreo

Logs disponibles en **Grafana**: https://grafana.mambo-cloud.com
- WWW: `{container_name="codespartan-www"}`
- UI: `{container_name="codespartan-ui"}`

## DNS Configuration

DNS records configurados en Terraform:
- `codespartan.cloud` → A/AAAA records
- `www.codespartan.cloud` → A/AAAA records
- `ui.codespartan.cloud` → A/AAAA records

---

**Última actualización**: 2025-11-17
