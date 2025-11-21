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

Para monitorear Fail2ban en Grafana y recibir alertas cuando se banean IPs, necesitamos exponer las métricas de Fail2ban en formato Prometheus.

#### Opción 1: Fail2ban Prometheus Exporter (Recomendado)

##### Paso 1: Desplegar el Exporter

Crear un servicio en el stack de monitoreo:

```yaml
# codespartan/platform/stacks/monitoring/docker-compose.yml
# Agregar al final de la sección services:

  fail2ban-exporter:
    image: devops-workshop/fail2ban-prometheus-exporter:latest
    container_name: fail2ban-exporter
    command:
      - --fail2ban.socket=/var/run/fail2ban/fail2ban.sock
      - --web.listen-address=:9191
    volumes:
      - /var/run/fail2ban:/var/run/fail2ban:ro
    networks:
      - monitoring
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.1'
          memory: 64M
        reservations:
          cpus: '0.05'
          memory: 32M
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9191/metrics"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

##### Paso 2: Configurar Scrape en Prometheus

Agregar el job de scrape en `victoriametrics/prometheus.yml`:

```yaml
# codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml
# Agregar después de node-exporter:

  - job_name: 'fail2ban'
    static_configs:
      - targets: ['fail2ban-exporter:9191']
    scrape_interval: 30s
    scrape_timeout: 10s
```

##### Paso 3: Reiniciar Servicios

```bash
cd /opt/codespartan/platform/stacks/monitoring
docker compose up -d fail2ban-exporter
docker compose restart vmagent
```

##### Paso 4: Verificar Métricas

```bash
# Verificar que el exporter está funcionando
docker exec fail2ban-exporter wget -qO- http://localhost:9191/metrics | head -20

# Verificar que vmagent está scrapeando
docker logs vmagent | grep fail2ban

# Verificar métricas en VictoriaMetrics
curl http://localhost:8428/api/v1/query?query=fail2ban_banned_total
```

##### Métricas Disponibles:

- `fail2ban_banned_total` - Total de IPs baneadas por jail
- `fail2ban_failed_total` - Total de intentos fallidos por jail
- `fail2ban_jail_banned_total` - IPs baneadas por jail específico
- `fail2ban_jail_failed_total` - Intentos fallidos por jail específico
- `fail2ban_up` - Estado del exporter (1 = up, 0 = down)

#### Opción 2: Dashboard en Grafana

##### Crear Dashboard Manualmente:

1. Ir a Grafana: https://grafana.mambo-cloud.com
2. Dashboards → New Dashboard → Add visualization
3. Datasource: VictoriaMetrics
4. Queries sugeridas:

```promql
# Total de IPs baneadas (últimas 24h)
sum(increase(fail2ban_banned_total[24h])) by (jail)

# Intentos fallidos por hora
sum(rate(fail2ban_failed_total[5m])) by (jail)

# IPs actualmente baneadas
fail2ban_jail_banned_total

# Estado del exporter
fail2ban_up
```

##### Importar Dashboard Pre-configurado

1. Dashboard ID: `13639` (Fail2ban Prometheus Exporter)
2. O crear dashboard JSON personalizado (ver ejemplo abajo)

##### Ejemplo de Dashboard JSON

```json
{
  "dashboard": {
    "title": "Fail2ban Monitoring",
    "panels": [
      {
        "title": "IPs Baneadas (Últimas 24h)",
        "targets": [
          {
            "expr": "sum(increase(fail2ban_banned_total[24h])) by (jail)",
            "legendFormat": "{{jail}}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Intentos Fallidos por Minuto",
        "targets": [
          {
            "expr": "sum(rate(fail2ban_failed_total[5m])) by (jail)",
            "legendFormat": "{{jail}}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "IPs Actualmente Baneadas",
        "targets": [
          {
            "expr": "fail2ban_jail_banned_total",
            "legendFormat": "{{jail}}"
          }
        ],
        "type": "stat"
      }
    ]
  }
}
```

#### Opción 3: Alertas de Fail2ban

Agregar reglas de alerta en `alerts/rules.yml`:

```yaml
# codespartan/platform/stacks/monitoring/alerts/rules.yml
# Agregar nuevo grupo:

groups:
  - name: fail2ban
    interval: 30s
    rules:
      # Alerta si Fail2ban exporter está down
      - alert: Fail2banExporterDown
        expr: fail2ban_up == 0
        for: 2m
        labels:
          severity: warning
          component: fail2ban
        annotations:
          summary: "Fail2ban exporter está down"
          description: "El exporter de Fail2ban no está respondiendo desde hace {{ $for }}"

      # Alerta si hay muchas IPs baneadas en poco tiempo (posible ataque)
      - alert: Fail2banHighBanRate
        expr: rate(fail2ban_banned_total[5m]) > 10
        for: 5m
        labels:
          severity: warning
          component: fail2ban
        annotations:
          summary: "Alta tasa de baneos en Fail2ban"
          description: "Se están baneando {{ $value }} IPs por minuto en el jail {{ $labels.jail }}"

      # Alerta si hay muchos intentos fallidos (posible ataque)
      - alert: Fail2banHighFailureRate
        expr: rate(fail2ban_failed_total[5m]) > 50
        for: 5m
        labels:
          severity: warning
          component: fail2ban
        annotations:
          summary: "Alta tasa de intentos fallidos"
          description: "{{ $value }} intentos fallidos por minuto en el jail {{ $labels.jail }}"
```

Reiniciar vmalert para cargar nuevas reglas:

```bash
docker compose restart vmalert
```

#### Verificación Completa

```bash
# 1. Verificar exporter está corriendo
docker ps | grep fail2ban-exporter

# 2. Verificar métricas disponibles
curl http://localhost:9191/metrics | grep fail2ban

# 3. Verificar scrape en vmagent
docker logs vmagent | grep -i fail2ban

# 4. Verificar métricas en VictoriaMetrics
curl 'http://localhost:8428/api/v1/query?query=fail2ban_up'

# 5. Verificar dashboard en Grafana
# Ir a: https://grafana.mambo-cloud.com → Dashboards → Fail2ban Monitoring
```

#### Troubleshooting

**Exporter no puede conectar a Fail2ban socket**:

```bash
# Verificar que el socket existe
ls -la /var/run/fail2ban/fail2ban.sock

# Verificar permisos
sudo chmod 666 /var/run/fail2ban/fail2ban.sock  # Temporal para testing

# Verificar que Fail2ban está corriendo
systemctl status fail2ban
```

**Métricas no aparecen en Grafana**:

1. Verificar que vmagent está scrapeando:
   ```bash
   docker logs vmagent | grep fail2ban
   ```

2. Verificar que las métricas existen en VictoriaMetrics:
   ```bash
   curl 'http://localhost:8428/api/v1/label/__name__/values' | grep fail2ban
   ```

3. Verificar que el datasource en Grafana es correcto (VictoriaMetrics)

**Referencias**:
- [Fail2ban Prometheus Exporter](https://github.com/devops-workshop/fail2ban-prometheus-exporter)
- [Grafana Dashboard ID 13639](https://grafana.com/grafana/dashboards/13639)

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

