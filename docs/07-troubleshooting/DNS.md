# Troubleshooting DNS

Guía para resolver problemas relacionados con DNS.

## Problemas Comunes

### Subdominio no resuelve

**Síntomas:**
- `dig subdomain.mambo-cloud.com` no devuelve IP
- Navegador muestra "DNS_PROBE_FINISHED_NXDOMAIN"

**Solución:**
1. Verificar que el registro existe en Hetzner DNS
2. Verificar nameservers del dominio apuntan a Hetzner
3. Esperar propagación DNS (2-5 minutos)
4. Limpiar cache DNS local: `sudo dscacheutil -flushcache` (macOS)

### Propagación DNS lenta

**Síntomas:**
- DNS resuelve en algunos lugares pero no en otros
- Cambios DNS no se reflejan inmediatamente

**Solución:**
- Esperar 2-5 minutos para propagación normal
- Verificar TTL de los registros (recomendado: 300 segundos)
- Usar `dig @8.8.8.8 subdomain.mambo-cloud.com` para verificar con DNS público

### Nameservers incorrectos

**Síntomas:**
- Dominio no resuelve en absoluto
- `dig NS mambo-cloud.com` no muestra nameservers de Hetzner

**Solución:**
1. Verificar en el registrador del dominio
2. Configurar nameservers a:
   - `helium.ns.hetzner.de`
   - `hydrogen.ns.hetzner.de`
   - `oxygen.ns.hetzner.de`
3. Esperar propagación (puede tardar hasta 24 horas)

## Comandos de Diagnóstico

```bash
# Verificar resolución DNS
dig subdomain.mambo-cloud.com
dig A subdomain.mambo-cloud.com
dig AAAA subdomain.mambo-cloud.com

# Verificar nameservers
dig NS mambo-cloud.com

# Verificar con DNS público
dig @8.8.8.8 subdomain.mambo-cloud.com
dig @1.1.1.1 subdomain.mambo-cloud.com

# Verificar TTL
dig subdomain.mambo-cloud.com +noall +answer +ttlid
```

## Verificar en Hetzner DNS

1. Ve a: https://dns.hetzner.com
2. Selecciona tu zona DNS
3. Verifica que existe el registro A/AAAA para el subdominio
4. Verifica que la IP es correcta (91.98.137.217)

## Troubleshooting Avanzado

### Verificar propagación global

```bash
# Usar herramienta online
# https://dnschecker.org/#A/subdomain.mambo-cloud.com
```

### Limpiar cache DNS

```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

## Siguiente Paso

Si el problema persiste, consulta el [Índice de Troubleshooting](INDEX.md) o el [Runbook](../03-operations/RUNBOOK.md).

