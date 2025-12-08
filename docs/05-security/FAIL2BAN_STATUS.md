# 🛡️ Fail2ban Status Report

**Fecha de verificación**: 2025-12-08
**Verificado por**: Claude Code
**Servidor**: 91.98.137.217 (leonidas@mambo-cloud.com)

---

## 📊 Resumen Ejecutivo

| Componente | Estado | Notas |
|------------|--------|-------|
| **Fail2ban Service** | ✅ RUNNING | Activo desde 2025-11-23, uptime: 2+ semanas |
| **Versión** | ✅ 1.1.0-6.el9 | Instalación completa con múltiples módulos |
| **Configuración** | ✅ CONFIGURADO | jail.local con reglas personalizadas |
| **FirewallD** | ⚠️ INACTIVO → ✅ ACTIVADO | **Fix aplicado vía workflow** |
| **SSH Jail** | ✅ ACTIVO | Protección sshd + sshd-ddos |
| **fail2ban-exporter** | ⚠️ ERROR → ✅ CORREGIDO | Reiniciado después de activar FirewallD |
| **Actividad Reciente** | ✅ SIN ATAQUES | 0 bans en últimos 7 días |

**Estado General**: ✅ **FUNCIONAL** (después del fix)

---

## 🔍 Hallazgos Principales

### ✅ Lo que está BIEN

1. **Fail2ban instalado correctamente**
   - Versión: 1.1.0-6.el9.noarch
   - Paquetes instalados:
     - fail2ban (principal)
     - fail2ban-server
     - fail2ban-firewalld (integración)
     - fail2ban-systemd (backend logs)
     - fail2ban-sendmail (notificaciones)
     - fail2ban-selinux (políticas SELinux)

2. **Servicio activo y estable**
   - Estado: active (running)
   - Inicio: 2025-11-23 13:05:31 UTC
   - Uptime: 2 semanas sin interrupciones
   - Uso memoria: 34.5MB (pico: 64.3MB)
   - Uso CPU: 56 minutos acumulados

3. **Configuración personalizada**
   - Archivo: `/etc/fail2ban/jail.local`
   - Bantime: 10 minutos
   - Findtime: 10 minutos
   - Maxretry: 5 intentos
   - IPs whitelisted: 127.0.0.1/8, ::1, 13.83.233.97

4. **Jails configurados**
   - `[sshd]`: Protección SSH estándar
   - `[sshd-ddos]`: Protección contra DDoS SSH (10 intentos)
   - Ambos jails activos y funcionando

5. **Sin actividad maliciosa**
   - 0 intentos SSH fallidos en últimos 7 días
   - 0 IPs baneadas en el período
   - Sin logs de intrusión

6. **Exportador de métricas desplegado**
   - Contenedor: `fail2ban-exporter`
   - Imagen: ghcr.io/mivek/fail2ban_exporter:latest
   - Puerto: 9921
   - Montaje: `/var/run/fail2ban` (socket access)

### ⚠️ Problemas Encontrados (RESUELTOS)

1. **FirewallD inactivo** ❌ → ✅
   - **Problema**: FirewallD estaba habilitado pero no corriendo
   - **Impacto**: Fail2ban no podía ejecutar bans (banaction=firewallcmd-rich-rules)
   - **Síntoma**: `firewall-cmd --list-rich-rules` devolvía "FirewallD is not running"
   - **Solución**: Workflow `fix-fail2ban-firewalld.yml` ejecutado
   - **Estado**: ✅ RESUELTO

2. **fail2ban-exporter con errores** ❌ → ✅
   - **Problema**: IndexError en get_jail_state()
   - **Causa raíz**: FirewallD inactivo causaba que jails no tuvieran estado válido
   - **Logs de error**:
     ```
     IndexError: string index out of range
     at jail_state[0][1][0][1]
     ```
   - **Solución**: Reinicio del contenedor después de activar FirewallD
   - **Estado**: ✅ RESUELTO

---

## 🔧 Acciones Realizadas

### 1. Verificación Completa

```bash
# Verificaciones ejecutadas:
✅ systemctl status fail2ban           # Service running
✅ rpm -qa | grep fail2ban              # Packages installed
✅ cat /etc/fail2ban/jail.local         # Configuration OK
✅ cat /etc/fail2ban/jail.d/*.conf      # Backend configs OK
✅ docker ps | grep fail2ban-exporter   # Container running
✅ journalctl -u fail2ban               # No recent bans
✅ journalctl -u sshd                   # 0 failed attempts
```

### 2. Fix Aplicado

**Workflow creado**: `.github/workflows/fix-fail2ban-firewalld.yml`

Acciones del workflow:
1. ✅ Activar FirewallD (`systemctl start firewalld`)
2. ✅ Habilitar FirewallD permanentemente (`systemctl enable firewalld`)
3. ✅ Configurar reglas básicas (SSH, HTTP, HTTPS, DNS, ICMP)
4. ✅ Reiniciar Fail2ban (`systemctl restart fail2ban`)
5. ✅ Reiniciar fail2ban-exporter (`docker restart fail2ban-exporter`)
6. ✅ Verificar estado de todos los servicios

**Estado del workflow**: ✅ EJECUTADO

### 3. Script de Verificación Creado

**Archivo**: `codespartan/scripts/verify-fail2ban.sh`

Verificaciones incluidas (10 checks):
1. ✅ Instalación de Fail2ban
2. ✅ Estado del servicio
3. ✅ Estado de FirewallD
4. ✅ Archivos de configuración
5. ✅ Jails activos
6. ✅ Estadísticas SSH jail
7. ✅ SSH DDoS jail
8. ✅ Actividad reciente (24h)
9. ✅ fail2ban-exporter container
10. ✅ Reglas de firewall

**Uso**:
```bash
ssh leonidas@91.98.137.217
sudo /opt/codespartan/scripts/verify-fail2ban.sh
```

---

## 📋 Configuración Actual

### jail.local

```ini
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1 13.83.233.97
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 5
bantime = 10m
findtime = 10m
ignoreip = 127.0.0.1/8 ::1 13.83.233.97

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 10
findtime = 10m
bantime = 10m
ignoreip = 127.0.0.1/8 ::1 13.83.233.97
```

### Backend Configuration

```ini
# /etc/fail2ban/jail.d/00-firewalld.conf
[DEFAULT]
banaction = firewallcmd-rich-rules
banaction_allports = firewallcmd-rich-rules

# /etc/fail2ban/jail.d/00-systemd.conf
[DEFAULT]
backend = systemd
```

### fail2ban-exporter Container

```yaml
fail2ban-exporter:
  image: ghcr.io/mivek/fail2ban_exporter:latest
  container_name: fail2ban-exporter
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
```

---

## 📊 Estadísticas

### Actividad SSH (Últimos 7 días)

| Métrica | Valor |
|---------|-------|
| Intentos SSH fallidos | 0 |
| IPs baneadas | 0 |
| Unbans ejecutados | 0 |
| Ataques DDoS detectados | 0 |

**Interpretación**: ✅ **Excelente**
- Sin actividad maliciosa
- SSH con autenticación por clave (no password)
- Sin brute force attacks

### Uso de Recursos

| Componente | CPU | Memoria | Uptime |
|------------|-----|---------|--------|
| fail2ban service | 56min (acum.) | 34.5MB | 15 días |
| fail2ban-exporter | <0.1 CPU | 64MB (limit) | 5 días |

---

## 🧪 Tests de Funcionamiento

### Test 1: Verificar Jails Activos

```bash
sudo fail2ban-client status
# Output esperado:
# Status
# |- Number of jail:   2
# `- Jail list:   sshd, sshd-ddos
```

### Test 2: Verificar SSH Jail

```bash
sudo fail2ban-client status sshd
# Output esperado:
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed:  0
# |  |- Total failed:      0
# |  `- File list:         /var/log/secure
# `- Actions
#    |- Currently banned:  0
#    |- Total banned:      0
#    `- Banned IP list:
```

### Test 3: Verificar FirewallD

```bash
sudo systemctl status firewalld
# Output esperado: active (running)

sudo firewall-cmd --list-rich-rules
# Output esperado: (vacío si no hay bans activos)
```

### Test 4: Verificar Exporter

```bash
docker ps | grep fail2ban-exporter
# Output esperado: Container running (healthy)

docker exec fail2ban-exporter wget -q -O- http://localhost:9921/metrics | head -20
# Output esperado: Métricas Prometheus
```

### Test 5: Simular Intento Fallido (OPCIONAL)

⚠️ **Solo para testing en entorno controlado**

```bash
# Desde otra máquina (NO desde IP whitelisted)
ssh invalid_user@91.98.137.217
# Repetir 5 veces con contraseña incorrecta

# Verificar ban
sudo fail2ban-client status sshd
# Debería mostrar IP baneada

# Desbanear
sudo fail2ban-client set sshd unbanip <IP>
```

---

## 🔍 Monitoreo en Producción

### Métricas en VictoriaMetrics/Grafana

El fail2ban-exporter expone métricas en formato Prometheus:

```
fail2ban_up{jail="sshd"} 1
fail2ban_banned_ips{jail="sshd"} 0
fail2ban_failed_ips{jail="sshd"} 0
fail2ban_banned_total{jail="sshd"} 0
fail2ban_failed_total{jail="sshd"} 0
```

**Scrape config en vmagent**:
```yaml
- job_name: 'fail2ban'
  static_configs:
    - targets: ['fail2ban-exporter:9921']
```

### Alertas Configuradas

**NO** hay alertas específicas de Fail2ban aún. Considerar añadir:

```yaml
# codespartan/platform/stacks/monitoring/alerts/fail2ban.yml
groups:
  - name: fail2ban
    rules:
      - alert: Fail2banDown
        expr: up{job="fail2ban"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Fail2ban exporter is down"

      - alert: HighFailedSSHAttempts
        expr: increase(fail2ban_failed_total{jail="sshd"}[1h]) > 20
        labels:
          severity: warning
        annotations:
          summary: "High number of SSH failed attempts detected"

      - alert: SSHBruteForceAttack
        expr: rate(fail2ban_banned_total{jail="sshd"}[5m]) > 2
        labels:
          severity: critical
        annotations:
          summary: "SSH brute force attack detected - multiple IPs banned"
```

---

## 📚 Comandos Útiles

### Gestión de Fail2ban

```bash
# Ver estado general
sudo fail2ban-client status

# Ver jail específico
sudo fail2ban-client status sshd

# Ver IPs baneadas
sudo fail2ban-client get sshd banned

# Desbanear IP
sudo fail2ban-client set sshd unbanip <IP>

# Desbanear todas las IPs
sudo fail2ban-client unban --all

# Ver logs
sudo journalctl -u fail2ban -f
sudo tail -f /var/log/fail2ban.log

# Reiniciar servicio
sudo systemctl restart fail2ban

# Recargar configuración
sudo fail2ban-client reload
```

### Gestión de FirewallD

```bash
# Ver estado
sudo systemctl status firewalld

# Ver reglas activas
sudo firewall-cmd --list-all
sudo firewall-cmd --list-rich-rules

# Ver zonas
sudo firewall-cmd --get-active-zones

# Recargar firewall
sudo firewall-cmd --reload
```

### Verificación de fail2ban-exporter

```bash
# Ver logs
docker logs fail2ban-exporter -f

# Ver métricas
docker exec fail2ban-exporter wget -q -O- http://localhost:9921/metrics

# Reiniciar contenedor
docker restart fail2ban-exporter

# Ver estado
docker ps | grep fail2ban-exporter
```

---

## 🚨 Troubleshooting

### Problema: Fail2ban no banea IPs

**Síntomas**:
- Intentos SSH fallidos detectados
- Pero IPs no son baneadas

**Diagnóstico**:
```bash
sudo systemctl status firewalld
# Si: inactive (dead) → Problema encontrado
```

**Solución**:
```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo systemctl restart fail2ban
```

**O ejecutar workflow**:
```bash
gh workflow run fix-fail2ban-firewalld.yml
```

### Problema: fail2ban-exporter con errores

**Síntomas**:
- Container running pero unhealthy
- Logs muestran: `IndexError: string index out of range`

**Causa**:
- FirewallD inactivo
- Jails sin estado válido

**Solución**:
```bash
# Activar FirewallD primero
sudo systemctl start firewalld
sudo systemctl restart fail2ban

# Luego reiniciar exporter
docker restart fail2ban-exporter

# Verificar
docker logs fail2ban-exporter --tail 20
```

### Problema: Me baneé a mí mismo

**Solución de emergencia**:

**Método 1**: Via otro servidor con acceso
```bash
ssh leonidas@91.98.137.217
sudo fail2ban-client set sshd unbanip <YOUR_IP>
```

**Método 2**: Via GitHub Actions
```bash
gh workflow run fail2ban-emergency-unban.yml
```

**Método 3**: Via Hetzner Cloud Console
1. Acceder a la consola web de Hetzner
2. Abrir VNC console del VPS
3. Login como root
4. Ejecutar: `fail2ban-client unban --all`

---

## ✅ Checklist de Verificación

Use este checklist después de cualquier cambio:

- [ ] Fail2ban service running: `sudo systemctl status fail2ban`
- [ ] FirewallD service running: `sudo systemctl status firewalld`
- [ ] Jails activos: `sudo fail2ban-client status` (debe mostrar: sshd, sshd-ddos)
- [ ] SSH jail funcional: `sudo fail2ban-client status sshd` (Currently failed: 0)
- [ ] fail2ban-exporter healthy: `docker ps | grep fail2ban-exporter`
- [ ] Métricas accesibles: `docker exec fail2ban-exporter wget -O- http://localhost:9921/metrics`
- [ ] Sin errores en logs: `sudo journalctl -u fail2ban --since "10 minutes ago"`
- [ ] IP propia en whitelist: Verificar en `/etc/fail2ban/jail.local`

---

## 📅 Próximos Pasos

### Mejoras Recomendadas

1. **Alertas de Fail2ban** (Prioridad: Media)
   - Añadir reglas de alerta en VictoriaMetrics
   - Notificaciones vía ntfy.sh cuando se detecten ataques

2. **Protección adicional** (Prioridad: Baja)
   - Fail2ban para Traefik (HTTP brute force)
   - Fail2ban para Grafana (login attempts)

3. **Ban permanente** (Prioridad: Baja)
   - Configurar `bantime = -1` para ataques persistentes
   - Lista negra de IPs conocidas

4. **Notificaciones por email** (Prioridad: Baja)
   - Configurar sendmail/postfix
   - action = %(action_mw)s en jail.local

### Mantenimiento Regular

**Semanal**:
```bash
# Verificar estado
ssh leonidas@91.98.137.217
sudo /opt/codespartan/scripts/verify-fail2ban.sh
```

**Mensual**:
```bash
# Revisar estadísticas
sudo fail2ban-client status sshd
sudo journalctl -u fail2ban --since "30 days ago" | grep "Ban "

# Actualizar Fail2ban
sudo dnf update fail2ban
```

---

## 📖 Referencias

- **Documentación oficial**: https://www.fail2ban.org/
- **Fail2ban GitHub**: https://github.com/fail2ban/fail2ban
- **Exporter GitHub**: https://github.com/mivek/fail2ban_exporter
- **FirewallD docs**: https://firewalld.org/documentation/

---

## 📝 Changelog

| Fecha | Acción | Resultado |
|-------|--------|-----------|
| 2025-11-23 | Instalación inicial | ✅ Fail2ban instalado |
| 2025-12-03 | Deploy fail2ban-exporter | ✅ Container desplegado |
| 2025-12-08 | Verificación completa | ⚠️ FirewallD inactivo detectado |
| 2025-12-08 | Fix aplicado | ✅ FirewallD activado |
| 2025-12-08 | Exporter reiniciado | ✅ Métricas funcionando |

---

**Reporte generado por**: Claude Code
**Última actualización**: 2025-12-08 13:00 UTC
**Estado**: ✅ **OPERATIONAL**
