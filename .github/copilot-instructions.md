# Copilot Instructions

## Project shape

This repo is Infrastructure-as-Code for the CodeSpartan Mambo Cloud platform on Hetzner Cloud ARM64. It is organized around three layers:

- `codespartan/infra/` for Terraform-managed VPS, DNS, and bootstrap
- `codespartan/platform/` for shared services like Traefik, Authelia, Kong, monitoring, Portainer, watchtower, and docker-socket-proxy
- `codespartan/apps/` for per-domain applications, each with its own `docker-compose.yml`

The target architecture is documented in `docs/02-architecture/ARCHITECTURE.md`. The operational deployment flow and runbooks live in `docs/03-operations/` and `docs/04-deployment/`.

For agent review and readiness checks, see `.github/agent-evaluation.md`.

## Commands

### Infrastructure

```bash
cd codespartan/infra/hetzner
terraform init
terraform plan
terraform apply
terraform destroy
```

### Local validation

```bash
cd codespartan/infra/hetzner
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Targeted checks

```bash
terraform fmt -check -recursive codespartan/infra/hetzner
yamllint .github/workflows/deploy-traefik.yml
yamllint codespartan/platform/traefik/docker-compose.yml
shellcheck codespartan/infra/hetzner/import-existing-resources.sh
```

### Compose inspection

```bash
cd codespartan/platform/traefik
docker compose config
docker compose up -d
docker compose pull
docker compose restart
```

### GitHub Actions deployment

```bash
gh workflow run deploy-infrastructure.yml
gh workflow run deploy-traefik.yml
gh workflow run deploy-monitoring.yml
gh workflow run deploy-backoffice.yml
gh workflow run deploy-mambo-cloud.yml
```

## High-level architecture

- Terraform provisions the VPS, firewall, and Hetzner DNS records.
- Traefik is the public edge router and terminates TLS with Let's Encrypt.
- `docker-socket-proxy` sits between Traefik and the Docker socket; do not route Traefik back to `/var/run/docker.sock` directly.
- Monitoring is a composed stack: VictoriaMetrics, vmagent, vmalert, Grafana, Loki, Promtail, Alertmanager, cAdvisor, and Node Exporter.
- Apps are deployed as separate domain folders and are usually attached to `web` plus one internal network.
- GitHub Actions is the primary deployment mechanism; path-based workflow triggers are part of the repo design.

## Conventions to preserve

- Use ARM64-compatible images.
- Give every container explicit `deploy.resources` limits and a healthcheck.
- Traefik-exposed services should include `traefik.enable=true`, `traefik.http.routers.*.entrypoints=websecure`, `traefik.http.routers.*.tls=true`, `traefik.http.routers.*.tls.certresolver=le`, and `traefik.docker.network=web`.
- Public services attach to the external `web` network; internal dependencies use a separate per-app network with `internal: true`.
- For app templates, keep the dual-network pattern and the Traefik label pattern from `codespartan/apps/_TEMPLATE/docker-compose.yml`.
- Preserve the initial deployment order: infrastructure, Traefik, monitoring, backoffice, then apps.
- Prefer editing the existing template or service-specific compose file instead of inventing a new layout.
