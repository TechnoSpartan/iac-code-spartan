# VPS Network Troubleshooting - AlmaLinux ARM64

**Problema:** El servidor no puede conectarse a los mirrors de AlmaLinux
**Error:** `Connection timed out after 30000 milliseconds`
**Arquitectura:** aarch64 (ARM64)

---

## Diagnósticos Básicos

Ejecuta estos comandos en el VPS para diagnosticar:

```bash
# 1. Verificar conectividad básica
ping -c 3 8.8.8.8
ping -c 3 google.com

# 2. Verificar DNS
nslookup repo.almalinux.org
dig repo.almalinux.org

# 3. Verificar conectividad HTTP/HTTPS
curl -I https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/
curl -v --max-time 10 https://repo.almalinux.org

# 4. Verificar firewall local
sudo iptables -L -n
sudo firewall-cmd --list-all 2>/dev/null || echo "firewalld no activo"

# 5. Verificar routing
ip route show
ip addr show

# 6. Ver estado de la red
sudo systemctl status NetworkManager
```

---

## Posibles Causas y Soluciones

### Causa 1: Firewall de Hetzner bloqueando tráfico

**Verificar en Hetzner Cloud Panel:**
1. Ve a: https://console.hetzner.cloud/
2. Server → CodeSpartan-alma → Firewalls
3. Verifica reglas de salida (OUTBOUND)

**Reglas necesarias:**
- ✅ Outbound: Allow ALL (o al menos HTTP/HTTPS)
- ✅ Inbound: SSH (22), HTTP (80), HTTPS (443)

### Causa 2: Repositorios ARM64 no disponibles/lentos

**Solución: Cambiar a mirrors más rápidos**

```bash
# Backup de la config original
sudo cp /etc/yum.repos.d/almalinux.repo /etc/yum.repos.d/almalinux.repo.backup

# Ver mirrors disponibles
sudo dnf repolist -v | grep -i mirror

# Usar mirror específico (ej: CloudFlare)
sudo sed -i 's|repo.almalinux.org|cloudflare.almalinux.org|g' /etc/yum.repos.d/almalinux*.repo

# O usar mirrors europeos
sudo sed -i 's|repo.almalinux.org|mirrors.xtom.nl/almalinux|g' /etc/yum.repos.d/almalinux*.repo

# Limpiar cache y reintenta
sudo dnf clean all
sudo dnf makecache
```

### Causa 3: IPv6 causando problemas

```bash
# Deshabilitar IPv6 temporalmente
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Reintentar
sudo dnf makecache

# Si funciona, hacer permanente:
sudo tee /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
```

### Causa 4: MTU incorrecto

```bash
# Ver MTU actual
ip link show

# Reducir MTU (a veces Hetzner requiere MTU más bajo)
sudo ip link set dev eth0 mtu 1450

# Reintentar
sudo dnf makecache

# Si funciona, hacer permanente en NetworkManager
sudo nmcli connection modify "System eth0" 802-3-ethernet.mtu 1450
sudo nmcli connection up "System eth0"
```

### Causa 5: DNS incorrecto

```bash
# Ver DNS actual
cat /etc/resolv.conf

# Cambiar a DNS de Google/Cloudflare
sudo tee /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
EOF

# Hacer permanente en NetworkManager
sudo nmcli connection modify "System eth0" ipv4.dns "8.8.8.8 1.1.1.1"
sudo nmcli connection up "System eth0"
```

---

## Solución Drástica: Usar Rocky Linux o CentOS Stream

Si AlmaLinux ARM64 sigue sin funcionar, considera cambiar la imagen base:

**En Terraform (`codespartan/infra/hetzner/terraform.tfvars`):**

```hcl
# Cambiar de:
image = "alma-9"

# A una de estas opciones:
image = "rocky-9"           # Rocky Linux 9 (similar a AlmaLinux)
image = "centos-stream-9"   # CentOS Stream 9
image = "ubuntu-22.04"      # Ubuntu 22.04 LTS (más stable para ARM)
```

**Luego recrear el servidor:**
```bash
cd codespartan/infra/hetzner
terraform plan
terraform apply
```

---

## Workaround Temporal: Usar Docker sin dnf

Si solo necesitas Docker temporalmente:

```bash
# Instalar Docker con script oficial (no requiere repos dnf)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verificar
docker --version

# Habilitar Docker
sudo systemctl enable --now docker

# Añadir usuario a grupo docker
sudo usermod -aG docker $USER
sudo usermod -aG docker github  # si ya creaste el usuario github

# Crear red web
docker network create web
```

---

## Recomendación Final

**Opción A (Rápida):** Usar el workaround de Docker con script oficial
**Opción B (Correcta):** Investigar firewall/red de Hetzner
**Opción C (Nuclear):** Cambiar a Ubuntu 22.04 que tiene mejor soporte ARM64

---

## Para revisar

1. **¿Terraform creó correctamente el firewall?**
   ```bash
   # En tu máquina local
   cd codespartan/infra/hetzner
   terraform state show hcloud_firewall.basic
   ```

2. **¿El servidor tiene IP pública correcta?**
   ```bash
   terraform state show hcloud_server.vps | grep ipv4
   ```

3. **¿Hetzner tiene problemas conocidos con ARM64?**
   - Revisa: https://docs.hetzner.com/cloud/servers/arm-support/
