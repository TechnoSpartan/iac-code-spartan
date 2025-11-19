# Quick Start - Despliegue Rápido

Guía rápida para desplegar la plataforma en 5 pasos.

## Pre-requisitos

Ver [Pre-requisitos](PREREQUISITES.md) para la lista completa.

## Paso 1: Configurar GitHub Secrets

Ve a tu repositorio GitHub → Settings → Secrets and variables → Actions → New repository secret

Añade estos secrets:

- `HCLOUD_TOKEN` - Token API de Hetzner Cloud
- `HETZNER_DNS_TOKEN` - Token API de Hetzner DNS
- `VPS_SSH_HOST` - IP del VPS (ej: 91.98.137.217)
- `VPS_SSH_USER` - Usuario SSH (ej: leonidas)
- `VPS_SSH_KEY` - Clave privada SSH completa

## Paso 2: Desplegar Infraestructura

1. Ve a Actions → Deploy Infrastructure (Terraform)
2. Click Run workflow → Run workflow
3. Espera 5-10 minutos

## Paso 3: Desplegar Traefik

1. Actions → Deploy Traefik
2. Run workflow
3. Verifica: https://traefik.mambo-cloud.com

## Paso 4: Desplegar Monitoring

1. Actions → Deploy Monitoring Stack
2. Run workflow
3. Verifica: https://grafana.mambo-cloud.com

## Paso 5: Desplegar Aplicaciones

1. Actions → Deploy [Nombre App]
2. Run workflow
3. Verifica la URL de la aplicación

## Verificación Completa

```bash
# Verificar todos los servicios
curl -I https://traefik.mambo-cloud.com
curl -I https://grafana.mambo-cloud.com
curl -I https://backoffice.mambo-cloud.com
```

## Siguiente Paso

Para más detalles, consulta la [Guía de Despliegue Completa](../04-deployment/DEPLOYMENT.md).

