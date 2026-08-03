# DentalFlow

Landing pública Next.js SSR de DentalFlow, servida en `dental-ia.es` por la plataforma CodeSpartan.

## Arquitectura

| Pieza | Valor |
|-------|-------|
| Repositorio de aplicación | [TechnoSpartan/dental-ia.es](https://github.com/TechnoSpartan/dental-ia.es) |
| Imagen | `ghcr.io/technospartan/dental-ia:latest` |
| Plataforma | VPS principal Hetzner ARM64 (`cax11`) |
| Contenedor | `dental-ia-web` |
| Puerto interno | `3000` |
| Proyecto Compose | `dental-ia` |
| Red | `web` externa, accesible solo a través de Traefik |
| Persistencia | No utiliza base de datos ni volúmenes en esta versión |
| Autenticación | Pública, con bypass de Authelia |

Traefik termina TLS y enruta estos hosts al mismo contenedor:

| Host | Uso |
|------|-----|
| `dental-ia.es` | Landing pública principal |
| `www.dental-ia.es` | Landing pública principal |
| `staging.dental-ia.es` | Entorno reservado; usa la imagen de producción hasta disponer de staging propio |
| `lab.dental-ia.es` | Entorno reservado; usa la imagen de producción hasta disponer de laboratorio propio |

El nombre Compose explícito evita colisiones con otros stacks desplegados en directorios llamados `www`.

## CI/CD

El workflow `.github/workflows/deploy-dental-ia.yml` se ejecuta al cambiar este directorio en `main`, de forma manual o mediante un evento `repository_dispatch` de tipo `dental-ia-deploy` desde el repositorio de la aplicación.

1. Obtiene este repositorio y `TechnoSpartan/dental-ia.es`.
2. Construye una imagen `linux/arm64` y la publica en GHCR.
3. Copia el Compose al VPS principal.
4. Escribe `.env` con secretos de Brevo, inicia sesión en GHCR y recrea `dental-ia-web`.
5. Espera al healthcheck y verifica los dos hosts públicos.

Secrets requeridos:

| Secret | Uso |
|--------|-----|
| `GH_PAT` | Lectura del repositorio de aplicación y publicación/descarga de GHCR |
| `VPS_SSH_HOST` | Host SSH del VPS principal |
| `VPS_SSH_USER` | Usuario SSH de despliegue |
| `VPS_SSH_KEY` | Clave privada SSH de despliegue |
| `BREVO_API_KEY` / `BREVO_SMTP_PASS` | Clave SMTP Brevo (`xsmtpsib-…`) |
| `BREVO_SMTP_USER` | Login SMTP (fallback `REDMINE_SMTP_USERNAME`) |
| `DENTAL_PILOT_FROM_EMAIL` | Opcional. Remitente (default `noreply@codespartan.cloud`) |
| `DENTAL_PILOT_FROM_NAME` | Opcional. Nombre del remitente (default `DentalFlow`) |
| `DENTAL_PILOT_TO_EMAIL` | Opcional. Buzón de leads (default `contacto@codespartan.es`) |
| `TWENTY_API_KEY` | API key Twenty (Settings → API & Webhooks). Sin ella, solo email |
| `TWENTY_API_URL` | Opcional. Default `http://10.0.0.3:3000` (red privada) |
| `TWENTY_LEADS_ENABLED` | Opcional. Default `true` |

El DNS se gestiona con Terraform en `codespartan/infra/hetzner/terraform.tfvars`; no se configura desde el workflow.

## Operación

```bash
# Lanzar un despliegue manual
gh workflow run deploy-dental-ia.yml

# Estado y logs en el VPS
ssh leonidas@91.98.137.217 "docker ps --filter name=dental-ia-web"
ssh leonidas@91.98.137.217 "docker logs dental-ia-web --tail 100"

# Verificación pública
curl -I https://dental-ia.es
curl -I https://www.dental-ia.es
curl -s https://dental-ia.es/api/health
```

Endpoints de la aplicación:

| Endpoint | Uso |
|----------|-----|
| `GET /api/health` | Healthcheck del contenedor |
| `POST /api/pilot` | Formulario piloto → Brevo (email + auto-reply) + Twenty CRM API (`TWENTY_API_URL`) |
| `GET /privacidad` | Política de privacidad |
| `GET /aviso-legal` | Aviso legal |

## Desarrollo local

```bash
cd dental-ia.es
cp .env.example .env   # rellenar BREVO_API_KEY
pnpm install
pnpm dev

# Alternativa con Docker
docker build -t dental-ia .
docker run --rm -p 3000:3000 --env-file .env dental-ia
```

## Troubleshooting

| Síntoma | Comprobación | Acción |
|---------|-------------|--------|
| `404` de Traefik | `docker ps --filter name=dental-ia-web` | Inicia el workflow o ejecuta `docker compose up -d` desde el directorio de la aplicación |
| Fallo al descargar imagen | `docker login ghcr.io` en el VPS | Revisa que `GH_PAT` tenga acceso al paquete y al repositorio de aplicación |
| Contenedor no healthy | `docker logs dental-ia-web --tail 100` | Comprueba que `GET /api/health` responda `200` en el puerto `3000` |
| Form piloto 503/502 | Logs `[pilot-lead]` | Verifica `BREVO_API_KEY` y que `noreply@…` esté verificado en Brevo |
| Otra web deja de responder | `docker inspect dental-ia-web` | Confirma que el proyecto Compose sea `dental-ia`; nunca ejecutes comandos Compose con un proyecto compartido |

Twenty CRM no está enganchado a este form. Los leads llegan por email; la integración CRM es un paso posterior.
