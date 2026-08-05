# DentalFlow (app)

Aplicación real de DentalFlow (backend NestJS + frontend Next.js + Postgres + Redis), servida en `lab.dental-ia.es` por la plataforma CodeSpartan. Distinta de la landing de marketing (`dental-ia-es/www`, `dental-ia.es`/`www.dental-ia.es`), que sigue siendo un producto separado.

## Arquitectura

| Pieza | Valor |
|-------|-------|
| Repositorio de aplicación | [TechnoSpartan/flow-ts-dental-ia-es](https://github.com/TechnoSpartan/flow-ts-dental-ia-es) |
| Imágenes | `ghcr.io/technospartan/dental-lab-backend:latest`, `ghcr.io/technospartan/dental-lab-frontend:latest` |
| Plataforma | VPS secundario "APIs" Hetzner x86_64 (`cx33`), red privada `10.0.0.0/24` |
| Contenedores | `dental-lab-backend` (10.0.0.3:3091→3001), `dental-lab-frontend` (10.0.0.3:3090→3000), `dental-lab-db`, `dental-lab-redis` |
| Proyecto Compose | `dental-lab` |
| Red | `dental_lab_internal` (172.35.0.0/24) para backend↔db↔redis. Sin red `web`: Traefik corre en el VPS principal y alcanza este host por IP privada vía el *file provider* (ver más abajo) |
| Persistencia | Postgres propio (`dental_lab_postgres_data`), sin base de datos compartida con otras apps |
| Autenticación | Login propio de la app (JWT), pública de cara al usuario |

Traefik (VPS principal) termina TLS para `lab.dental-ia.es` y enruta por *path*, no por subdominio separado — un único origen para el navegador, sin CORS:

| Regla | Destino |
|-------|---------|
| `Host(lab.dental-ia.es) && (PathPrefix(/api) \|\| PathPrefix(/public))` | Backend (`10.0.0.3:3091`) |
| `Host(lab.dental-ia.es)` (resto) | Frontend (`10.0.0.3:3090`) |

Configurado en `codespartan/platform/traefik/dynamic/dynamic-config.yml` (routers `dental-lab-api`/`dental-lab-www`), igual patrón que `cyberdyne-api`/`cyberdyne-www`. El frontend se compila con `NEXT_PUBLIC_API_URL` vacío para que todas las llamadas a la API sean rutas relativas (`/api/v1/...`), resueltas por el navegador contra `lab.dental-ia.es` — es Traefik quien decide el enrutado, no la app.

`lab.dental-ia.es` estaba reservado en Terraform apuntando a la landing ("entorno reservado hasta tener laboratorio propio") — se repuntó aquí; el DNS no cambió.

## CI/CD

El workflow `.github/workflows/deploy-dental-lab.yml` se ejecuta al cambiar este directorio en `main`, de forma manual, o mediante un evento `repository_dispatch` de tipo `dental-lab-deploy` desde el repositorio de la aplicación.

1. Obtiene este repositorio y `TechnoSpartan/flow-ts-dental-ia-es`.
2. Construye **dos** imágenes `linux/amd64` (backend y frontend — el VPS de APIs es x86_64, a diferencia del VPS principal ARM64) y las publica en GHCR.
3. Copia el Compose al VPS de APIs (`/home/deploy/apps/dental-lab/`).
4. Escribe `.env` con los secretos, inicia sesión en GHCR y recrea los contenedores.
5. Espera a los healthchecks de backend y frontend, y verifica los hosts públicos.

Secrets requeridos:

| Secret | Uso |
|--------|-----|
| `GH_PAT` | Lectura del repositorio de aplicación y publicación/descarga de GHCR |
| `APIS_VPS_SSH_HOST` | Host SSH del VPS de APIs |
| `APIS_VPS_SSH_USER` | Usuario SSH de despliegue (`deploy`) |
| `APIS_VPS_SSH_KEY` | Clave privada SSH de despliegue |
| `DENTAL_LAB_POSTGRES_PASSWORD` | Password de Postgres del stack |
| `DENTAL_LAB_JWT_SECRET` | Firma de JWT (access + refresh) |
| `DENTAL_LAB_ANTHROPIC_API_KEY` | IA real (clasificación, borradores, prioridad) |

El DNS no se toca — `lab.dental-ia.es` ya existe en Terraform (`codespartan/infra/hetzner/terraform.tfvars`).

## Operación

```bash
# Lanzar un despliegue manual
gh workflow run deploy-dental-lab.yml

# Estado y logs en el VPS de APIs
ssh deploy@<APIS_VPS_SSH_HOST> "docker ps --filter name=dental-lab"
ssh deploy@<APIS_VPS_SSH_HOST> "docker logs dental-lab-backend --tail 100"
ssh deploy@<APIS_VPS_SSH_HOST> "docker logs dental-lab-frontend --tail 100"

# Verificación pública
curl -I https://lab.dental-ia.es
curl -s https://lab.dental-ia.es/health || true   # 404 esperado: /health no pasa por el router de API
curl -s -X POST https://lab.dental-ia.es/api/v1/auth/login  # 400/401 esperado, confirma que llega al backend

# Verificación directa en el VPS de APIs (red privada, sin pasar por Traefik)
ssh deploy@<APIS_VPS_SSH_HOST> "curl -s http://10.0.0.3:3091/health"
```

## Desarrollo local

El repositorio de la aplicación (`TechnoSpartan/flow-ts-dental-ia-es`) tiene su propio flujo de desarrollo local completo (backend + frontend + Postgres + Redis vía Docker Compose, sin necesidad de este repo de infraestructura). Ver su `README.md`.

## Troubleshooting

| Síntoma | Comprobación | Acción |
|---------|-------------|--------|
| `404` en `/` | `docker ps --filter name=dental-lab` | Lanza el workflow o `docker compose up -d` desde `/home/deploy/apps/dental-lab` |
| `404` en `/api/*` pero frontend OK | Revisa `dynamic-config.yml`, router `dental-lab-api`, `priority: 100` | El catch-all del frontend puede estar ganando; confirma que Traefik recargó el *file provider* |
| Backend no healthy | `docker logs dental-lab-backend --tail 100` | Revisa `DATABASE_URL`/`JWT_SECRET`; el propio contenedor aplica `prisma migrate deploy` al arrancar |
| Enlaces públicos rotos en emails a pacientes | `PUBLIC_BASE_URL` en `.env` del VPS | Debe ser `https://lab.dental-ia.es`, nunca `localhost` |
| Otra web deja de responder | `docker inspect dental-lab-backend` | Confirma que el proyecto Compose sea `dental-lab`; nunca ejecutes comandos Compose con un proyecto compartido |
