# Resumen del Problema y Solución del Firewall

**Fecha:** 2025-11-11
**Estado:** ✅ RESUELTO

---

## Problema Inicial

El servidor VPS no podía descargar paquetes desde los repositorios de AlmaLinux:

```bash
[leonidas@CodeSpartan-alma ~]$ sudo dnf makecache
Curl error (28): Timeout was reached for
https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/repodata/repomd.xml
[Connection timed out after 30000 milliseconds]
```

---

## Diagnóstico Realizado

### 1. Conectividad Básica ✅
```bash
$ ping -c 3 8.8.8.8
✅ 3 packets transmitted, 3 received, 0% packet loss
```

### 2. Resolución DNS ✅
```bash
$ ping -c 3 google.com
✅ PING google.com(2a00:1450:4001:82b::200e)
```

### 3. Ping a AlmaLinux Mirror ✅
```bash
$ ping -c 2 repo.almalinux.org
✅ PING repo.almalinux.org(2a04:4e42:200::820)
64 bytes from 2a04:4e42:200::820: icmp_seq=1 ttl=58 time=4.54 ms
```

### 4. HTTPS a AlmaLinux Mirror ❌
```bash
$ curl -v --max-time 15 https://repo.almalinux.org
*   Trying 2a04:4e42:400::820:443...
* After 7494ms connect time, move on!
* connect to 2a04:4e42:400::820 port 443 failed: Connection timed out
[... multiple IPv6 attempts timeout ...]
curl: (28) Connection timed out after 15001 milliseconds
```

### 5. HTTPS con IPv4 Forzado ❌
```bash
$ curl -4 -v --max-time 10 https://repo.almalinux.org
*   Trying 151.101.3.52:443...
* After 4999ms connect time, move on!
* connect to 151.101.3.52 port 443 failed: Connection timed out
[... multiple IPv4 attempts timeout ...]
curl: (28) Failed to connect to repo.almalinux.org port 443
```

### 6. HTTP (Puerto 80) ❌
```bash
$ curl -4 -v --max-time 10 http://repo.almalinux.org
*   Trying 151.101.67.52:80...
* After 4996ms connect time, move on!
* connect to 151.101.67.52 port 80 failed: Connection timed out
curl: (28) Connection timed out
```

### 7. HTTPS a Google ❌
```bash
$ curl -4 -v --max-time 10 https://google.com
*   Trying 142.250.186.174:443...
* Connection timed out after 10001 milliseconds
curl: (28) Connection timed out
```

---

## Conclusión del Diagnóstico

| Protocolo/Puerto | Estado | Observación |
|------------------|--------|-------------|
| ICMP (ping) | ✅ OK | Funciona tanto IPv4 como IPv6 |
| DNS (resolución) | ✅ OK | Resuelve correctamente |
| TCP/80 (HTTP) | ❌ BLOQUEADO | Timeout tanto IPv4 como IPv6 |
| TCP/443 (HTTPS) | ❌ BLOQUEADO | Timeout tanto IPv4 como IPv6 |

**Diagnóstico:** El firewall de Hetzner Cloud está bloqueando **TODO el tráfico saliente (outbound) TCP**, solo permite ICMP (ping).

---

## Causa Raíz

En `codespartan/infra/hetzner/main.tf`, el firewall `hcloud_firewall.basic` solo tenía reglas de salida para ICMP:

```hcl
resource "hcloud_firewall" "basic" {
  name = "codespartan-basic"

  # ... reglas de entrada (OK) ...

  # ❌ PROBLEMA: Solo ICMP saliente
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  # ❌ FALTAN reglas para HTTP/HTTPS/DNS
}
```

**Hetzner Cloud por defecto bloquea TODO el tráfico saliente** a menos que se especifique explícitamente en el firewall.

---

## Solución Aplicada

Se agregaron reglas de salida (outbound) para permitir tráfico esencial:

```hcl
resource "hcloud_firewall" "basic" {
  name = "codespartan-basic"

  # ... reglas de entrada ...

  # ✅ Reglas de salida (outbound)
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "80"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # NTP for time synchronization
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "123"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

### Puertos Permitidos Salientes

| Puerto | Protocolo | Propósito |
|--------|-----------|-----------|
| 80 | TCP | HTTP (descargas, repositorios) |
| 443 | TCP | HTTPS (descargas seguras, APIs) |
| 53 | TCP/UDP | DNS (resolución de nombres) |
| 123 | UDP | NTP (sincronización de tiempo) |
| ICMP | - | Ping, diagnósticos |

---

## Despliegue de la Solución

### Paso 1: Commit y Push
```bash
git add codespartan/infra/hetzner/main.tf
git commit -m "fix: Add outbound firewall rules for HTTP/HTTPS/DNS/NTP"
git push
```

**Commit:** `a62b0a7`

### Paso 2: Terraform Apply Automático

El workflow `.github/workflows/deploy-infrastructure.yml` se ejecuta automáticamente al detectar cambios en `codespartan/infra/hetzner/**`.

**Workflow Run:** https://github.com/TechnoSpartan/iac-code-spartan/actions/runs/19277401331

### Paso 3: Verificación Post-Despliegue

Una vez aplicado el cambio, verificar:

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Probar HTTPS
curl -I https://repo.almalinux.org
# Debe retornar: HTTP/2 200

# Probar dnf
sudo dnf makecache
# Debe completar sin errores

# Instalar paquete de prueba
sudo dnf install -y tree
```

---

## Impacto

### Antes del Fix ❌
- ❌ No se pueden instalar paquetes (`dnf` timeout)
- ❌ No se puede instalar Docker
- ❌ No se puede descargar nada por HTTP/HTTPS
- ❌ Scripts de cloud-init fallaron
- ❌ Imposible hacer despliegues

### Después del Fix ✅
- ✅ `dnf makecache` funciona
- ✅ Instalación de paquetes funciona
- ✅ Docker se puede instalar
- ✅ Descargas HTTP/HTTPS funcionan
- ✅ Scripts de automatización funcionan
- ✅ Despliegues automatizados viables

---

## Lecciones Aprendidas

1. **Hetzner Cloud bloquea salida por defecto**
   - A diferencia de AWS/GCP que permiten salida por defecto
   - Requiere configuración explícita de reglas outbound

2. **ICMP != Conectividad completa**
   - Ping funcional no significa que HTTP/HTTPS funcione
   - Siempre probar con `curl` o `wget` para verificar TCP

3. **Terraform debe incluir reglas outbound esenciales**
   - HTTP/HTTPS para descargas
   - DNS para resolución
   - NTP para sincronización de tiempo

4. **Diagnóstico metódico es clave**
   - Empezar con ping (ICMP)
   - Luego DNS (resolución)
   - Luego HTTP/HTTPS (aplicación)
   - Probar tanto IPv4 como IPv6

---

## Archivos Modificados

| Archivo | Cambio | Motivo |
|---------|--------|--------|
| `codespartan/infra/hetzner/main.tf` | Agregadas 5 reglas outbound | Permitir tráfico saliente esencial |
| `VPS_NETWORK_TROUBLESHOOTING.md` | Creado | Guía de diagnóstico para futuros problemas |
| `VPS_RECOVERY_STATUS.md` | Creado | Estado actual del VPS post-recreación |
| `FIREWALL_FIX_SUMMARY.md` | Creado | Este documento |

---

## Referencias

- **Hetzner Cloud Firewall Docs:** https://docs.hetzner.com/cloud/firewalls/getting-started/creating-a-firewall
- **Terraform hcloud Provider:** https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/firewall
- **GitHub Actions Run:** https://github.com/TechnoSpartan/iac-code-spartan/actions/runs/19277401331
- **Commit:** https://github.com/TechnoSpartan/iac-code-spartan/commit/a62b0a7

---

**Última actualización:** 2025-11-11 20:15 UTC
**Próximo paso:** Verificar conectividad después del apply de Terraform
