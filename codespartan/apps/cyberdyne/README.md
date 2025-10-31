# Cyberdyne Systems - Despliegue TruckWorks

Infraestructura para el despliegue de la aplicación TruckWorks en cyberdyne-systems.es

## Arquitectura

```
cyberdyne/
├── backend/          # API Backend (ms-nd-bko-trackworks)
│   └── docker-compose.yml
└── frontend/         # Frontend React (ft-rc-bko-dummy)
    └── docker-compose.yml
```

## Dominios y Subdominios

### Backend API
- **Dominio principal**: `api.cyberdyne-systems.es`
- **Puerto**: 3001
- **Healthcheck**: `/api/v1/health`
- **Imagen Docker**: `ghcr.io/krbaio3/ms-nd-bko-trackworks:latest`

### Frontend
- **Dominio principal**: `www.cyberdyne-systems.es`
- **Dominio raíz**: `cyberdyne-systems.es` (redirige a www)
- **Staging**: `staging.cyberdyne-systems.es`
- **Lab**: `lab.cyberdyne-systems.es`
- **Puerto**: 80 (Nginx)
- **Imagen Docker**: `ghcr.io/krbaio3/ft-rc-bko-dummy:latest`

## Despliegue Automático (CI/CD)

### Backend API - `deploy-cyberdyne-api.yml`

Se ejecuta automáticamente cuando:
- Push a `codespartan/apps/cyberdyne/backend/**`
- Ejecución manual desde GitHub Actions

### Frontend - `deploy-cyberdyne.yml`

Se ejecuta automáticamente cuando:
- Push a `codespartan/apps/cyberdyne/frontend/**`
- Ejecución manual desde GitHub Actions

## Despliegue Manual

### Backend

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/cyberdyne/backend
docker compose pull && docker compose up -d
docker logs -f truckworks-api
```

### Frontend

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/cyberdyne/frontend
docker compose pull && docker compose up -d
docker logs -f cyberdyne-frontend
```

## URLs de Producción

- Backend API: https://api.cyberdyne-systems.es/api/v1/health
- Frontend: https://www.cyberdyne-systems.es
- Staging: https://staging.cyberdyne-systems.es
- Lab: https://lab.cyberdyne-systems.es

## Monitoreo

Logs en **Grafana**: https://grafana.mambo-cloud.com
- Backend: `{container_name="truckworks-api"}`
- Frontend: `{container_name="cyberdyne-frontend"}`

