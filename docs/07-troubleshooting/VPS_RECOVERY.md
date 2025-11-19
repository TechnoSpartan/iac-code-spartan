# Estado de Recuperación del VPS

**Fecha:** 2025-11-11
**Estado:** 🚨 BLOQUEADO - Requiere acción manual

---

## Resumen Ejecutivo

El VPS fue recreado por Terraform (perdiendo todos los datos), y ahora tenemos **dos problemas bloqueantes críticos** que impiden cualquier despliegue automatizado:

1. ✅ **SSH funciona** (ya actualizaste el secret `VPS_SSH_KEY`)
2. 🚨 **Sudo requiere contraseña** → Workflows fallan
3. 🚨 **Red no alcanza repositorios AlmaLinux** → No se puede instalar Docker

---

## Problema 1: Sudo Sin Contraseña (CRÍTICO)

### Error Actual
```
sudo: a terminal is required to read the password
sudo: a password is required
Process exited with status 1
```

### Causa
El usuario `leonidas` requiere contraseña para ejecutar `sudo` en contexto no interactivo (GitHub Actions).

### Solución A: Crear Usuario de Servicio `github` (RECOMENDADO)

**Pasos a ejecutar manualmente en el VPS:**

```bash
# 1. SSH al VPS
ssh leonidas@91.98.137.217

# 2. Crear usuario github
sudo useradd -m -s /bin/bash github

# 3. Agregar a grupo docker (cuando esté instalado)
sudo usermod -aG docker github

# 4. Configurar sudo SIN contraseña para github
echo "github ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/github
sudo chmod 0440 /etc/sudoers.d/github

# 5. Verificar configuración
sudo visudo -c  # Debe decir "parsed OK"

# 6. Crear directorio SSH
sudo mkdir -p /home/github/.ssh
sudo chown github:github /home/github/.ssh
sudo chmod 700 /home/github/.ssh

# 7. Generar clave SSH para GitHub Actions
sudo su - github
ssh-keygen -t ed25519 -C "github-actions@codespartan" -f ~/.ssh/id_ed25519 -N ""

# 8. Autorizar la clave
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 9. MOSTRAR LA CLAVE PRIVADA (para copiarla al secret de GitHub)
cat ~/.ssh/id_ed25519
```

**Luego, actualizar secrets en GitHub:**
- `VPS_SSH_USER` → `github` (cambiar de `leonidas` a `github`)
- `VPS_SSH_KEY` → Pegar el contenido completo de `/home/github/.ssh/id_ed25519`

### Solución B: Permitir Sudo Sin Contraseña para `leonidas` (RÁPIDO PERO MENOS SEGURO)

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Configurar sudo sin contraseña
echo "leonidas ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/leonidas
sudo chmod 0440 /etc/sudoers.d/leonidas
sudo visudo -c  # Verificar
```

**No requiere cambiar secrets de GitHub.**

---

## Problema 2: Conectividad de Red (CRÍTICO)

### Error Actual
```
Curl error (28): Timeout was reached for
https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/repodata/repomd.xml
[Connection timed out after 30000 milliseconds]
```

### Diagnósticos Básicos

**Ejecuta estos comandos en el VPS para diagnosticar:**

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Verificar conectividad básica
ping -c 3 8.8.8.8          # ¿Hay conexión a internet?
ping -c 3 google.com        # ¿Funciona DNS?

# Verificar DNS específico de AlmaLinux
nslookup repo.almalinux.org
dig repo.almalinux.org

# Intentar curl directo
curl -I https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/ --max-time 10

# Verificar firewall local
sudo iptables -L -n
sudo firewall-cmd --list-all 2>/dev/null || echo "firewalld no activo"

# Verificar routing
ip route show
ip addr show
```

### Solución 1: Workaround - Instalar Docker sin DNF (RÁPIDO)

**He creado un workflow automatizado:** `.github/workflows/install-docker-workaround.yml`

Este workflow usa el script oficial de Docker (`get.docker.com`) que NO requiere repositorios de AlmaLinux.

**Para ejecutarlo:**
```bash
# En tu máquina local
cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan
gh workflow run install-docker-workaround.yml
```

**⚠️ IMPORTANTE:** Este workflow también requiere que el problema de sudo esté resuelto primero.

### Solución 2: Cambiar Mirrors de AlmaLinux

```bash
# Backup de configuración original
sudo cp /etc/yum.repos.d/almalinux.repo /etc/yum.repos.d/almalinux.repo.backup

# Usar mirror de CloudFlare
sudo sed -i 's|repo.almalinux.org|cloudflare.almalinux.org|g' /etc/yum.repos.d/almalinux*.repo

# O usar mirror europeo
sudo sed -i 's|repo.almalinux.org|mirrors.xtom.nl/almalinux|g' /etc/yum.repos.d/almalinux*.repo

# Limpiar cache y reintentar
sudo dnf clean all
sudo dnf makecache
```

### Solución 3: Deshabilitar IPv6 (Si Es el Culpable)

```bash
# Deshabilitar temporalmente
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Reintentar
sudo dnf makecache

# Si funciona, hacer permanente
sudo tee /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
```

### Solución 4: Verificar Firewall de Hetzner

**En Hetzner Cloud Panel:**
1. Ve a: https://console.hetzner.cloud/
2. Server → CodeSpartan-alma → Firewalls
3. Verifica reglas de **OUTBOUND** (salida)

**Reglas necesarias:**
- ✅ Outbound: Allow ALL (o al menos HTTP/HTTPS a cualquier destino)
- ✅ Inbound: SSH (22), HTTP (80), HTTPS (443)

**Verificar en Terraform:**
```bash
cd codespartan/infra/hetzner
terraform state show hcloud_firewall.basic
```

### Solución 5: Opción Nuclear - Cambiar a Ubuntu (ÚLTIMA OPCIÓN)

Si AlmaLinux ARM64 sigue sin funcionar, cambiar la imagen base:

**Editar `codespartan/infra/hetzner/terraform.tfvars`:**
```hcl
# Cambiar de:
image = "alma-9"

# A:
image = "ubuntu-22.04"  # Mejor soporte ARM64
```

**Recrear servidor:**
```bash
cd codespartan/infra/hetzner
terraform plan
terraform apply
```

**⚠️ CUIDADO:** Esto destruirá el servidor nuevamente.

---

## Workflows Disponibles

### 1. `bootstrap-vps.yml` (Bootstrap Completo)
- **Estado:** 🚨 Bloqueado por problema de sudo
- **Qué hace:** Crea estructura completa de directorios y verifica Docker
- **Ejecutar:** `gh workflow run bootstrap-vps.yml`

### 2. `install-docker-workaround.yml` (Instalar Docker)
- **Estado:** ✅ Listo para usar (pero bloqueado por sudo)
- **Qué hace:** Instala Docker usando script oficial (bypass de dnf)
- **Ejecutar:** `gh workflow run install-docker-workaround.yml`

### 3. `vps-diagnostics.yml` (Diagnósticos)
- **Estado:** 🚨 Bloqueado por problema de sudo
- **Qué hace:** Verifica estructura, contenedores, y configuración
- **Ejecutar:** `gh workflow run vps-diagnostics.yml`

---

## Plan de Acción Recomendado

### PASO 1: Resolver Sudo (OBLIGATORIO)
**Elige una opción:**
- [ ] **Opción A:** Crear usuario `github` (más seguro, requiere actualizar secrets)
- [ ] **Opción B:** Permitir sudo sin contraseña para `leonidas` (rápido)

**Una vez resuelto, actualiza secrets en GitHub (si usaste Opción A):**
```bash
# En tu máquina local
cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan

# Verificar secrets actuales
gh secret list

# Actualizar VPS_SSH_USER (solo si creaste usuario github)
gh secret set VPS_SSH_USER --body "github"

# Actualizar VPS_SSH_KEY (pegar contenido de /home/github/.ssh/id_ed25519)
# Esto lo haces desde GitHub UI:
# https://github.com/TechnoSpartan/iac-code-spartan/settings/secrets/actions
```

### PASO 2: Diagnosticar Red
```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Ejecutar diagnósticos básicos
ping -c 3 8.8.8.8
ping -c 3 google.com
curl -I https://repo.almalinux.org --max-time 10

# Si ping funciona pero curl falla → problema de firewall/MTU
# Si ping falla → problema de routing/configuración red
```

### PASO 3: Instalar Docker
**Opción A (Workflow Automatizado):**
```bash
gh workflow run install-docker-workaround.yml
gh run watch --interval 5
```

**Opción B (Manual en VPS):**
```bash
ssh leonidas@91.98.137.217
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
docker --version
```

### PASO 4: Bootstrap VPS
```bash
gh workflow run bootstrap-vps.yml
gh run watch --interval 5
```

### PASO 5: Desplegar Servicios
```bash
# 1. Traefik (reverse proxy)
gh workflow run deploy-traefik.yml

# 2. Monitoring (Grafana, VictoriaMetrics, etc.)
gh workflow run deploy-monitoring.yml

# 3. Aplicaciones
gh workflow run deploy-cyberdyne.yml
gh workflow run deploy-dental-io.yml
gh workflow run deploy-mambo-cloud.yml
```

---

## Archivos Importantes

| Archivo | Descripción |
|---------|-------------|
| [VPS Network Troubleshooting](VPS_NETWORK.md) | Guía completa de diagnóstico de red |
| [VPS Migration Plan](VPS_MIGRATION.md) | Plan de migración original |
| `.github/workflows/bootstrap-vps.yml` | Workflow de bootstrap |
| `.github/workflows/install-docker-workaround.yml` | Workflow para instalar Docker (nuevo) |
| `.github/workflows/vps-diagnostics.yml` | Workflow de diagnósticos |

---

## Estado de Workflows Recientes

### ✅ Exitosos
- `deploy-infrastructure.yml` - Terraform apply completado (81 recursos DNS)
- Servidor creado: `CodeSpartan-alma` (ID: 112744417)
- IP: `91.98.137.217`

### 🚨 Fallidos
- `bootstrap-vps.yml` - Error: sudo requiere contraseña
- Todos los workflows de despliegue están bloqueados

---

## Contactos y Referencias

- **Hetzner Cloud Console:** https://console.hetzner.cloud/
- **GitHub Actions Secrets:** https://github.com/TechnoSpartan/iac-code-spartan/settings/secrets/actions
- **Servidor VPS:** `ssh leonidas@91.98.137.217`
- **Documentación AlmaLinux ARM:** https://wiki.almalinux.org/development/ARM.html
- **Hetzner ARM64 Support:** https://docs.hetzner.com/cloud/servers/arm-support/

---

## Preguntas Frecuentes

**Q: ¿Por qué se perdieron todos los datos?**
A: Terraform recreó el servidor 3 veces debido a que los recursos no estaban importados en el state. Esto ya está solucionado con el script de importación.

**Q: ¿Puedo usar el servidor sin resolver el problema de red?**
A: Sí, si instalas Docker con el workaround (`get.docker.com`), puedes desplegar los servicios. Pero eventualmente querrás resolver el problema para poder instalar paquetes adicionales.

**Q: ¿Es seguro dar sudo sin contraseña?**
A: Sí, para un usuario de servicio dedicado (`github`) es práctica común en CI/CD. Para tu usuario personal (`leonidas`), es menos recomendable.

**Q: ¿Qué pasa si cambio a Ubuntu?**
A: Ubuntu tiene mejor soporte para ARM64 y probablemente no tendrás problemas de conectividad. Pero perderás compatibilidad RHEL si eso es importante.

---

**Última actualización:** 2025-11-11 20:08 UTC
**Siguiente revisión:** Después de resolver problema de sudo
