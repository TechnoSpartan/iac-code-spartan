# DentalFlow — www.dental-ia.es

Landing Next.js (SSR) de DentalFlow by CodeSpartan.

## Stack en VPS

| Pieza | Valor |
|-------|--------|
| Imagen | `ghcr.io/technospartan/dental-ia:latest` |
| Contenedor | `dental-ia-web` |
| Puerto interno | `3000` |
| Red | `web` (Traefik) |
| Hosts | `dental-ia.es`, `www.dental-ia.es`, `staging.*`, `lab.*` |
| Auth | Pública (bypass Authelia) |
| Repo app | [TechnoSpartan/dental-ia.es](https://github.com/TechnoSpartan/dental-ia.es) |
| Workflow | `deploy-dental-ia.yml` |

## Despliegue

Automático al cambiar este directorio en `main`, o:

```bash
gh workflow run deploy-dental-ia.yml
```

También se puede disparar desde el repo de la app con `repository_dispatch` tipo `dental-ia-deploy`.

## Requisitos

- Secret `GH_PAT` con acceso a GHCR + repo `dental-ia.es`
- Secrets VPS: `VPS_SSH_HOST`, `VPS_SSH_USER`, `VPS_SSH_KEY`
- DNS apex/www ya gestionados por Terraform (`dental-ia.es` en `domains`)
- Build **linux/arm64** (VPS Hetzner cax11)

## Local (app)

```bash
cd dental-ia.es
npm ci
npm run dev
# o
docker build -t dental-ia .
docker run --rm -p 3000:3000 dental-ia
```

## Notas

- Sustituye el placeholder nginx estático anterior.
- Formulario piloto → `POST /api/pilot` (log server-side; conectar email después).
- Health: `GET /api/health`
