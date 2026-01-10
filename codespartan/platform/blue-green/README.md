# Blue/Green Deployments

Zero-downtime deployments using blue/green strategy with Traefik.

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│  app-blue   │     │  app-green  │
│  (Router)   │     │  (active)   │     │  (standby)  │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │  Deploy v2  │
                    └──────┬──────┘
                           ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Traefik   │     │  app-blue   │────▶│  app-green  │
│  (Router)   │────────────────────────▶│  (active)   │
└─────────────┘     │  (stopped)  │     └─────────────┘
                    └─────────────┘
```

1. **Blue** is running, serving traffic
2. Deploy new version to **Green**
3. Wait for Green to be healthy
4. Traefik automatically detects Green (same router name)
5. Stop Blue
6. Next deploy: Green → Blue

## Usage

### Basic Script
```bash
./deploy.sh <app-name> <image>

# Example
./deploy.sh cyberdyne-frontend ghcr.io/technospartan/ft-rc-bko-trackworks:latest
```

### Via Workflow
```bash
gh workflow run deploy-blue-green.yml \
  -f app=cyberdyne-frontend \
  -f image=ghcr.io/technospartan/ft-rc-bko-trackworks:latest \
  -f domain=www.cyberdyne-systems.es
```

## Rollback

If deployment fails, the script automatically rolls back:
1. New container fails health check
2. Script removes failed container
3. Old container continues serving traffic

Manual rollback:
```bash
# Check which slot is active
docker ps --filter "label=deployment.slot" --format "{{.Names}} - {{.Label \"deployment.slot\"}}"

# If green is active and you want to rollback to blue
docker rm -f app-green
# Re-deploy blue with previous image
./deploy.sh app <previous-image>
```

## Configuration

Environment variables in `deploy.sh`:
- `HEALTH_TIMEOUT=120` - Max seconds to wait for health check
- `HEALTH_INTERVAL=5` - Seconds between health checks

## Best Practices

1. Always use specific image tags (not `latest`) for production
2. Test in staging before production
3. Keep previous image available for quick rollback
4. Monitor health endpoint after deployment

## Supported Applications

| App | Domain | Status |
|-----|--------|--------|
| cyberdyne-frontend | www.cyberdyne-systems.es | Ready |
| trackworks-api | api.cyberdyne-systems.es | Ready |
