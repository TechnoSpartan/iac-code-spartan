# 🛡️ Verificar e Implementar Fail2ban

## 📋 Resumen

Fail2ban protege el servidor contra ataques de fuerza bruta en SSH y otros servicios. Esta guía explica cómo verificar si está instalado y cómo implementarlo si no lo está.

**Estado actual**: ⚠️ Script de instalación existe, pero no verificado si está instalado en VPS

---

## 🔍 Verificar Estado Actual

### Paso 1: Verificar si Fail2ban está Instalado

```bash
# Desde el VPS
ssh root@91.98.137.217

# Verificar si está instalado
which fail2ban-client || echo "Fail2ban no está instalado"

# Verificar si el servicio está corriendo
systemctl status fail2ban || echo "Servicio no encontrado"

# Verificar configuración
ls -la /etc/fail2ban/jail.local 2>/dev/null || echo "Configuración no existe"
```

### Paso 2: Verificar Estado de Jails

```bash
# Ver estado general
fail2ban-client status

# Ver estado de SSH jail
fail2ban-client status sshd

# Ver IPs baneadas
fail2ban-client get sshd banned
```

---

## ✅ Implementar Fail2ban (Si No Está Instalado)

### Opción A: Usar Script Existente

El repositorio ya tiene un script de instalación:

```bash
# Desde el VPS
cd /opt/codespartan/scripts
chmod +x install-fail2ban.sh
sudo ./install-fail2ban.sh
```

### Opción B: Workflow de GitHub Actions

Crear workflow para instalar/verificar Fail2ban:

```yaml
# .github/workflows/install-fail2ban.yml
name: Install/Verify Fail2ban

on:
  workflow_dispatch:

jobs:
  install:
    runs-on: ubuntu-latest
    steps:
      - name: Install/Verify Fail2ban
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            echo "════════════════════════════════════════════════════════════"
            echo "🛡️  INSTALLING/VERIFYING FAIL2BAN"
            echo "════════════════════════════════════════════════════════════"
            
            # Verificar si está instalado
            if command -v fail2ban-client &> /dev/null; then
              echo "✅ Fail2ban ya está instalado"
            else
              echo "📦 Instalando Fail2ban..."
              
              # Detectar distribución
              if [ -f /etc/redhat-release ]; then
                # AlmaLinux/RHEL/CentOS
                sudo dnf install -y fail2ban
              elif [ -f /etc/debian_version ]; then
                # Debian/Ubuntu
                sudo apt-get update
                sudo apt-get install -y fail2ban
              else
                echo "❌ Distribución no soportada"
                exit 1
              fi
            fi
            
            # Verificar configuración
            if [ ! -f /etc/fail2ban/jail.local ]; then
              echo "📝 Creando configuración..."
              
              sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
            [DEFAULT]
            # Ban hosts for 10 minutes
            bantime = 10m
            
            # A host is banned if it has generated "maxretry" during the last "findtime"
            findtime = 10m
            
            # Number of failures before a host gets banned
            maxretry = 5
            
            # Action to take when banning
            action = %(action_)s
            
            [sshd]
            enabled = true
            port = ssh
            logpath = %(sshd_log)s
            backend = %(sshd_backend)s
            maxretry = 5
            bantime = 10m
            findtime = 10m
            
            # Optional: Protect against SSH DDoS
            [sshd-ddos]
            enabled = true
            port = ssh
            logpath = %(sshd_log)s
            maxretry = 10
            findtime = 10m
            bantime = 10m
            EOF
            else
              echo "✅ Configuración ya existe"
            fi
            
            # Habilitar y reiniciar servicio
            echo "🔄 Habilitando servicio..."
            sudo systemctl enable fail2ban
            sudo systemctl restart fail2ban
            
            # Esperar a que inicie
            sleep 3
            
            # Verificar estado
            echo ""
            echo "📊 Estado de Fail2ban:"
            if systemctl is-active --quiet fail2ban; then
              echo "✅ Fail2ban está corriendo"
              echo ""
              echo "📋 Jails activos:"
              sudo fail2ban-client status
              echo ""
              echo "📋 SSH Jail:"
              sudo fail2ban-client status sshd || echo "SSH jail no activo aún"
            else
              echo "❌ Fail2ban no está corriendo"
              echo "Logs:"
              sudo journalctl -u fail2ban -n 20
              exit 1
            fi
```

---

## 🔧 Configuración Recomendada

### Configuración Básica (Actual)

```ini
[DEFAULT]
bantime = 10m      # Tiempo de ban
findtime = 10m     # Ventana de tiempo para contar intentos
maxretry = 5       # Intentos antes de ban

[sshd]
enabled = true
maxretry = 5
bantime = 10m
findtime = 10m
```

### Configuración Más Estricta (Recomendada para Producción)

```ini
[DEFAULT]
bantime = 1h      # Ban por 1 hora
findtime = 10m    # Ventana de 10 minutos
maxretry = 3      # Solo 3 intentos

[sshd]
enabled = true
maxretry = 3
bantime = 1h
findtime = 10m

# Protección adicional contra DDoS
[sshd-ddos]
enabled = true
maxretry = 10
findtime = 1m
bantime = 1h
```

### Configuración con Notificaciones por Email

```ini
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5

# Email notifications
destemail = admin@codespartan.es
sender = fail2ban@codespartan.es
action = %(action_mw)s  # Ban + Email

[sshd]
enabled = true
maxretry = 5
bantime = 10m
findtime = 10m
```

**Nota**: Requiere configuración SMTP en el servidor.

---

## 🧪 Testing Fail2ban

### Test 1: Verificar que Está Funcionando

```bash
# Ver estado
sudo fail2ban-client status

# Ver IPs baneadas
sudo fail2ban-client get sshd banned

# Ver estadísticas
sudo fail2ban-client status sshd
```

### Test 2: Simular Ataque (CUIDADO - Puede Banearte)

```bash
# Desde otra máquina (NO desde el VPS)
# Intentar login SSH con contraseña incorrecta 5 veces
for i in {1..5}; do
  ssh root@91.98.137.217
done

# Verificar que tu IP fue baneada
ssh root@91.98.137.217
# Debe fallar con "Connection refused"
```

### Test 3: Desbanear IP

```bash
# Desde el VPS
sudo fail2ban-client set sshd unbanip TU_IP_AQUI

# Verificar que ya no está baneada
sudo fail2ban-client get sshd banned
```

---

## 📊 Monitoreo de Fail2ban

### Ver Logs en Tiempo Real

```bash
# Logs de Fail2ban
sudo tail -f /var/log/fail2ban.log

# Logs del sistema
sudo journalctl -u fail2ban -f
```

### Integrar con Grafana (Opcional)

```yaml
# Agregar métricas de Fail2ban a Prometheus
# Requiere exporter: https://github.com/fail2ban/fail2ban-prometheus-exporter
```

---

## 🚨 Troubleshooting

### Fail2ban No Inicia

```bash
# Ver logs de error
sudo journalctl -u fail2ban -n 50

# Verificar configuración
sudo fail2ban-client -d

# Verificar permisos
ls -la /etc/fail2ban/jail.local
```

### No Banea IPs

**Causas posibles**:
1. Logs de SSH no están en la ubicación esperada
2. Backend incorrecto (systemd vs syslog)
3. Permisos de lectura de logs

**Solución**:
```bash
# Verificar ubicación de logs SSH
sudo ls -la /var/log/auth.log  # Debian/Ubuntu
sudo ls -la /var/log/secure     # RHEL/CentOS/AlmaLinux

# Verificar backend
sudo fail2ban-client -d | grep backend

# Test manual
sudo fail2ban-client -d -v
```

### Banea IPs Legítimas

**Solución**: Whitelist de IPs confiables

```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 TU_IP_CONFIABLE_AQUI

[sshd]
enabled = true
ignoreip = 127.0.0.1/8 ::1 TU_IP_CONFIABLE_AQUI
```

---

## ✅ Checklist de Verificación

- [ ] Fail2ban instalado
- [ ] Servicio corriendo (`systemctl status fail2ban`)
- [ ] Configuración existe (`/etc/fail2ban/jail.local`)
- [ ] SSH jail activo (`fail2ban-client status sshd`)
- [ ] Logs funcionando (`tail -f /var/log/fail2ban.log`)
- [ ] Test de ban funciona (simular 5 intentos fallidos)
- [ ] Documentado en README

---

## 📚 Referencias

- [Fail2ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fail2ban Configuration Examples](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8)
- [SSH Protection Best Practices](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8#sshd)

---

**Última actualización**: 2025-11-18  
**Estado**: ⚠️ Pendiente de verificación en VPS

