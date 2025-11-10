# CodeSpartan Cloud

Main domain for CodeSpartan tech services

**Domain**: codespartan.cloud

## Subdomains

- **www** - Main website
- **api** - API services (production)
- **api-staging** - API services (staging)
- **staging** - Staging environment
- **lab** - Laboratory environment
- **lab-staging** - Lab staging
- **ui** - UI/Design system
- **mambo** - Mambo service

## Status

🚧 New domain - Subdomains not yet deployed

## DNS Configuration

DNS records should be configured in Terraform:
- `codespartan.cloud` → A/AAAA records
- All subdomains → A/AAAA records

## Architecture

All services follow the standard CodeSpartan platform architecture:
- Traefik reverse proxy
- Automatic SSL via Let's Encrypt
- Docker Compose deployments
- Network isolation per service
