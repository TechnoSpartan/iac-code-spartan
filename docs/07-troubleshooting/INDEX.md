# Índice de Troubleshooting

Índice de problemas comunes y sus soluciones.

## Problemas por Categoría

### Traefik

- [Problemas con Traefik](TRAEFIK.md) - Troubleshooting específico de Traefik
- Container discovery no funciona
- Certificados SSL no se generan
- Routing incorrecto

### DNS

- [Problemas DNS](DNS.md) - Resolución de problemas DNS
- Subdominios no resuelven
- Propagación DNS lenta
- Nameservers incorrectos

### SSL

- [Problemas SSL](SSL.md) - Problemas con certificados SSL
- Certificados expirados
- Let's Encrypt rate limiting
- Renovación automática falla

### Aplicaciones

- [Problemas Comunes](COMMON_ISSUES.md) - Problemas frecuentes
- Contenedores no inician
- Health checks fallan
- Aplicaciones no accesibles

## Problemas por Síntoma

### "Service not accessible"

1. Verificar contenedor está corriendo: `docker ps | grep [service]`
2. Ver logs: `docker logs [service]`
3. Verificar Traefik routing: `docker logs traefik | grep [subdomain]`
4. Ver [TRAEFIK.md](TRAEFIK.md)

### "SSL certificate error"

1. Verificar certificados: `docker exec traefik ls -la /letsencrypt/`
2. Ver logs de Traefik: `docker logs traefik | grep -i acme`
3. Ver [SSL.md](SSL.md)

### "DNS not resolving"

1. Verificar DNS: `dig subdomain.mambo-cloud.com`
2. Verificar nameservers: `dig NS mambo-cloud.com`
3. Esperar propagación (2-5 minutos)
4. Ver [DNS.md](DNS.md)

### "Container unhealthy"

1. Verificar health check: `docker inspect [container] | grep -A 10 Health`
2. Ver logs: `docker logs [container]`
3. Probar health endpoint manualmente
4. Ver [COMMON_ISSUES.md](COMMON_ISSUES.md)

## Comandos Útiles

```bash
# Ver todos los contenedores
docker ps -a

# Ver logs de un servicio
docker logs [container-name] -f

# Verificar red Docker
docker network ls
docker network inspect web

# Verificar Traefik
docker logs traefik --tail 100

# Verificar DNS
dig subdomain.mambo-cloud.com
nslookup subdomain.mambo-cloud.com

# Verificar SSL
openssl s_client -connect subdomain.mambo-cloud.com:443 -servername subdomain.mambo-cloud.com
```

## Obtener Ayuda

Si no encuentras la solución:

1. Revisa los logs detallados del servicio
2. Consulta la documentación específica del componente
3. Verifica la [documentación de operaciones](../03-operations/)
4. Revisa el [Runbook](../03-operations/RUNBOOK.md)

