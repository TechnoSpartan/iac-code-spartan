# Troubleshooting SSL

Guía para resolver problemas con certificados SSL.

## Problemas Comunes

### Certificado SSL no se genera

**Síntomas:**
- Navegador muestra "ERR_SSL_VERSION_OR_CIPHER_MISMATCH"
- Traefik logs muestran errores de ACME

**Solución:**
1. Verificar que el dominio resuelve correctamente
2. Verificar que el puerto 80 está abierto (necesario para HTTP-01 challenge)
3. Verificar logs de Traefik: `docker logs traefik | grep -i acme`
4. Esperar 1-2 minutos para generación inicial

### Certificado expirado

**Síntomas:**
- Navegador muestra "ERR_CERT_DATE_INVALID"
- Certificado muestra fecha de expiración pasada

**Solución:**
```bash
# Verificar certificado
docker exec traefik ls -la /letsencrypt/

# Regenerar certificado (CAUTION: elimina certificados existentes)
docker exec traefik rm -f /letsencrypt/acme.json
docker restart traefik
```

### Let's Encrypt rate limiting

**Síntomas:**
- Traefik logs muestran "too many certificates already issued"

**Solución:**
- Esperar 1 semana (rate limit de Let's Encrypt)
- Usar certificados existentes si están disponibles
- Considerar usar staging environment para testing

## Comandos de Diagnóstico

```bash
# Verificar certificado SSL
openssl s_client -connect subdomain.mambo-cloud.com:443 -servername subdomain.mambo-cloud.com

# Ver certificados en Traefik
docker exec traefik ls -la /letsencrypt/

# Ver logs de ACME
docker logs traefik | grep -i acme

# Verificar fecha de expiración
echo | openssl s_client -connect subdomain.mambo-cloud.com:443 -servername subdomain.mambo-cloud.com 2>/dev/null | openssl x509 -noout -dates
```

## Verificar Renovación Automática

```bash
# Verificar que Traefik está configurado para renovación
docker logs traefik | grep -i "certificate.*renew"

# Verificar certificados próximos a expirar
# (Traefik renueva automáticamente cuando quedan < 30 días)
```

## Troubleshooting Avanzado

### Verificar HTTP-01 Challenge

```bash
# Verificar que el puerto 80 responde
curl -I http://subdomain.mambo-cloud.com/.well-known/acme-challenge/test

# Verificar que Traefik puede servir el challenge
docker exec traefik wget -q -O - http://localhost:80/.well-known/acme-challenge/test
```

### Problemas con Wildcard

Si usas certificados wildcard, necesitas DNS-01 challenge en lugar de HTTP-01:
- Requiere configuración adicional en Traefik
- Requiere acceso a API de DNS (Hetzner DNS)

## Siguiente Paso

Si el problema persiste, consulta el [Índice de Troubleshooting](INDEX.md) o los logs de Traefik.

