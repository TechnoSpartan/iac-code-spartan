# Watchtower - Automatic Container Updates

Watchtower monitors running containers and automatically updates them when new images are available.

## Configuration

- **Poll interval**: 5 minutes (300s)
- **Cleanup**: Removes old images after update
- **Label-based**: Only updates containers with explicit opt-in label
- **Notifications**: Sends alerts to ntfy.sh when containers are updated

## Enabling Auto-Updates for a Container

Add this label to any container you want Watchtower to auto-update:

```yaml
services:
  myapp:
    image: ghcr.io/myorg/myapp:latest
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

## Notifications

Updates are sent to: https://ntfy.sh/codespartan-watchtower

Subscribe via:
- **Mobile**: Install ntfy app, subscribe to `codespartan-watchtower`
- **Web**: https://ntfy.sh/codespartan-watchtower
- **CLI**: `curl -s ntfy.sh/codespartan-watchtower/json`

## Commands

```bash
# Check Watchtower logs
docker logs watchtower -f

# Force check for updates now
docker exec watchtower /watchtower --run-once

# List monitored containers
docker ps --filter "label=com.centurylinklabs.watchtower.enable=true"
```

## Excluded Containers

These containers are NOT auto-updated (critical infrastructure):
- traefik
- watchtower itself
- databases (mongodb, redis, postgres)
- authelia

## Best Practices

1. Only enable auto-updates for stateless applications
2. Use `:latest` tag for containers you want auto-updated
3. Test updates in staging first before enabling in production
4. Monitor ntfy notifications for update alerts
