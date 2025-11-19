# El Error del Firewall que me Costó 3 Horas: Hetzner Cloud Bloquea Salida por Defecto

**Estado:** 📝 Idea / Outline  
**Prioridad:** 🔴 Alta  
**Tiempo estimado:** 2-3 horas  
**Fuente:** `docs/07-troubleshooting/FIREWALL_FIX.md`

---

## Estructura del Post

### TL;DR
- Problema: VPS no podía descargar paquetes (timeout en repositorios)
- Diagnóstico: Ping OK, DNS OK, pero HTTP/HTTPS bloqueado
- Causa: Hetzner Cloud bloquea tráfico saliente por defecto
- Solución: Agregar reglas outbound en Terraform
- Lección: Siempre verificar firewall outbound, no solo inbound

### 1. El Problema
- VPS recién creado no puede instalar paquetes
- `dnf makecache` falla con timeout
- Error: "Connection timed out after 30000 milliseconds"

### 2. Diagnóstico Paso a Paso
- ✅ Ping funciona (ICMP permitido)
- ✅ DNS resuelve correctamente
- ❌ HTTP/HTTPS bloqueado (timeout)
- Conclusión: Firewall bloquea TCP saliente

### 3. La Causa Raíz
- Hetzner Cloud bloquea TODO el tráfico saliente por defecto
- A diferencia de AWS/GCP que permiten salida por defecto
- Solo ICMP estaba permitido en nuestro firewall

### 4. La Solución
- Agregar reglas outbound en Terraform:
  - TCP/80 (HTTP)
  - TCP/443 (HTTPS)
  - TCP/UDP/53 (DNS)
  - UDP/123 (NTP)
- Código de ejemplo

### 5. Lecciones Aprendidas
- Siempre verificar firewall outbound
- ICMP != conectividad completa
- Terraform debe incluir reglas esenciales desde el inicio
- Diagnóstico metódico es clave

### 6. Código y Recursos
- Link a commit en GitHub
- Terraform configuration
- Documentación Hetzner Cloud

---

## Puntos Clave a Destacar

- **Problema real** que puede pasar a cualquiera
- **Diagnóstico sistemático** (metodología útil)
- **Solución simple** pero no obvia
- **Lección aplicable** a otros proveedores cloud

## Target Audience

- DevOps engineers
- Desarrolladores que usan Hetzner Cloud
- Personas que configuran firewalls por primera vez

## Call to Action

- ¿Te ha pasado algo similar?
- Comparte tu experiencia con otros proveedores cloud
- Revisa tu configuración de firewall

