#!/usr/bin/env bash
set -euo pipefail

# Bootstrap para CodeSpartan Mambo Cloud - AlmaLinux 9 ARM64 en Hetzner
# - Instala Docker Engine y docker compose plugin
# - Crea red docker "web" usada por Traefik y apps
# - Ajusta configuraciones de seguridad y rendimiento
# - Configura logs y monitoreo básico

require_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "🚀 [CodeSpartan] Iniciando bootstrap del VPS ARM64..."
echo "📍 Hostname: $(hostname)"
echo "🔧 Arquitectura: $(uname -m)"
echo "💾 Memoria: $(free -h | awk '/^Mem:/ {print $2}')"

echo "[+] Actualizando paquetes del sistema"
if require_cmd dnf; then
  sudo dnf -y update
  sudo dnf -y install htop curl wget git nano vim firewalld fail2ban
else
  echo "❌ Este script asume DNF (AlmaLinux/RHEL). Adaptalo si usas otra distribución."
  exit 1
fi

if ! require_cmd docker; then
  echo "[+] Instalando Docker para ARM64"
  sudo dnf -y install yum-utils device-mapper-persistent-data lvm2
  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Configurar Docker daemon para ARM64
  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ]
}
EOF

  sudo systemctl enable --now docker
  sudo usermod -aG docker root

  echo "✅ Docker instalado correctamente"
else
  echo "✅ Docker ya está instalado"
fi

echo "[+] Configurando redes Docker"
sudo docker network create web --driver bridge || echo "Red 'web' ya existe"

echo "[+] Configuraciones de seguridad básicas"
# Configurar firewall básico (GitHub Actions lo gestionará después)
sudo systemctl enable --now firewalld || true
sudo firewall-cmd --permanent --add-service=ssh || true
sudo firewall-cmd --permanent --add-service=http || true
sudo firewall-cmd --permanent --add-service=https || true
sudo firewall-cmd --reload || true

# Configurar fail2ban para SSH
sudo systemctl enable --now fail2ban || true

echo "[+] Optimizaciones para ARM64"
# Ajustar límites del sistema para contenedores
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
echo 'fs.file-max=2097152' | sudo tee -a /etc/sysctl.conf
echo 'net.core.somaxconn=65535' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Crear estructura de directorios para CodeSpartan
echo "[+] Preparando estructura de directorios"
sudo mkdir -p /opt/codespartan/{platform,apps,backups,logs}
sudo mkdir -p /opt/codespartan/platform/{traefik,stacks}
sudo mkdir -p /opt/codespartan/platform/stacks/{monitoring,logging,backoffice}
sudo chmod -R 755 /opt/codespartan

# Crear script de diagnóstico
sudo tee /opt/codespartan/diagnostics.sh > /dev/null <<'EOF'
#!/bin/bash
echo "=== CodeSpartan Platform Diagnostics ==="
echo "Fecha: $(date)"
echo "Uptime: $(uptime)"
echo "Memoria: $(free -h)"
echo "Disco: $(df -h /)"
echo "Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo "Docker networks:"
docker network ls
echo "=== Fin Diagnósticos ==="
EOF
sudo chmod +x /opt/codespartan/diagnostics.sh

# Configurar rotación de logs
sudo tee /etc/logrotate.d/codespartan > /dev/null <<EOF
/opt/codespartan/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
}
EOF

echo "[+] Instalando utilidades adicionales"
# Instalar docker-ctop para monitoreo de contenedores
if ! require_cmd ctop; then
  sudo wget https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-arm64 -O /usr/local/bin/ctop
  sudo chmod +x /usr/local/bin/ctop
fi

echo "✅ Bootstrap completado exitosamente!"
echo ""
echo "🎯 Próximos pasos:"
echo "1. Ejecutar workflows de GitHub Actions:"
echo "   - Deploy Traefik"
echo "   - Deploy Monitoring Stack"
echo "   - Deploy Backoffice"
echo "   - Deploy Mambo Cloud App"
echo ""
echo "2. Verificar servicios:"
echo "   https://traefik.mambo-cloud.com"
echo "   https://grafana.mambo-cloud.com"
echo "   https://backoffice.mambo-cloud.com"
echo ""
echo "3. Comandos útiles:"
echo "   docker ps                    # Ver contenedores"
echo "   /opt/codespartan/diagnostics.sh  # Diagnósticos"
echo "   ctop                        # Monitor contenedores"
echo "   journalctl -u docker -f     # Logs Docker"
echo ""
echo "🚀 CodeSpartan Mambo Cloud Platform listo!"
