# 🚨 Fail2ban - Plan de Recuperación ante Desastre (DR)

## 📋 Escenario de Desastre

**Situación**: Has sido baneado por Fail2ban y **NO tienes acceso SSH** al VPS.

**Objetivo**: Recuperar el control del VPS manteniendo la seguridad como prioridad.

---

## 🎯 Estrategia: Múltiples Vías de Escape (Defense in Depth)

Este plan implementa **múltiples capas de recuperación**, ordenadas por prioridad y facilidad de uso. Cada capa es independiente, así que si una falla, puedes usar la siguiente.

---

## 🚨 FASE 1: Recuperación Inmediata (Sin Acceso SSH)

### Vía 1: GitHub Actions Workflow (Más Rápida) ⭐

**Cuándo usar**: No tienes acceso SSH, pero tienes acceso a GitHub.

**Ventajas**:
- ✅ No requiere acceso al VPS
- ✅ Funciona desde cualquier lugar
- ✅ Automatizado y seguro
- ✅ Logs visibles en GitHub

**Pasos**:

1. **Obtener tu IP pública**:
   ```bash
   # Desde tu máquina local
   curl https://api.ipify.org
   # O desde navegador: https://api.ipify.org
   ```

2. **Ejecutar workflow de emergencia**:
   - Ve a: https://github.com/TechnoSpartan/iac-code-spartan/actions
   - Selecciona: **Fail2ban Emergency Unban**
   - Haz clic en **Run workflow**
   - En el campo `ip_address`, ingresa:
     - Tu IP pública (ej: `185.123.45.67`)
     - O `all` para desbanear todas las IPs
   - Haz clic en **Run workflow**

3. **Verificar resultado**:
   - El workflow mostrará si se desbaneó correctamente
   - Espera 30-60 segundos
   - Intenta conectarte por SSH nuevamente

**Si falla**: Continúa con Vía 2.

---

### Vía 2: Consola de Hetzner (Rescue Console)

**Cuándo usar**: El workflow de GitHub falla o no tienes acceso a GitHub.

**Ventajas**:
- ✅ Acceso directo al servidor
- ✅ No depende de SSH
- ✅ Funciona incluso si el servidor está completamente bloqueado

**Pasos**:

1. **Acceder a Hetzner Cloud Console**:
   - Ve a: https://console.hetzner.cloud/
   - Inicia sesión con tus credenciales
   - Selecciona tu proyecto

2. **Abrir Rescue Console**:
   - Ve a: **Servers** → Selecciona tu VPS (`CodeSpartan-alma`)
   - Haz clic en **Rescue** (o **Console** en algunas versiones)
   - Se abrirá una consola web en el navegador

3. **Desbanear tu IP desde la consola**:
   ```bash
   # Ver IPs baneadas
   sudo fail2ban-client get sshd banned
   
   # Desbanear tu IP específica
   sudo fail2ban-client set sshd unbanip TU_IP_AQUI
   
   # O desbanear todas las IPs (más seguro en emergencias)
   sudo fail2ban-client set sshd unbanip all
   
   # Verificar que se desbaneó
   sudo fail2ban-client get sshd banned
   ```

4. **Agregar tu IP a la whitelist** (para evitar que vuelva a pasar):
   ```bash
   # Ver configuración actual
   sudo cat /etc/fail2ban/jail.local
   
   # Editar configuración
   sudo nano /etc/fail2ban/jail.local
   
   # Agregar tu IP en la línea ignoreip:
   # ignoreip = 127.0.0.1/8 ::1 TU_IP_AQUI
   
   # Reiniciar Fail2ban
   sudo systemctl restart fail2ban
   ```

5. **Verificar acceso SSH**:
   - Cierra la consola de Hetzner
   - Intenta conectarte por SSH desde tu máquina

**Si falla**: Continúa con Vía 3.

---

### Vía 3: Deshabilitar Fail2ban Temporalmente

**Cuándo usar**: Las vías anteriores fallan y necesitas acceso urgente.

**⚠️ ADVERTENCIA**: Esto desactiva la protección temporalmente. **Solo úsalo en emergencias**.

**Pasos**:

1. **Acceder por Consola de Hetzner** (ver Vía 2, pasos 1-2)

2. **Detener Fail2ban temporalmente**:
   ```bash
   # Detener el servicio
   sudo systemctl stop fail2ban
   
   # Verificar que está detenido
   sudo systemctl status fail2ban
   ```

3. **Limpiar IPs baneadas en iptables** (si es necesario):
   ```bash
   # Ver reglas de iptables relacionadas con Fail2ban
   sudo iptables -L -n | grep f2b
   
   # Eliminar reglas de Fail2ban (cuidado: esto elimina TODAS las reglas de Fail2ban)
   sudo iptables -D INPUT -j f2b-sshd 2>/dev/null || true
   sudo iptables -F f2b-sshd 2>/dev/null || true
   sudo iptables -X f2b-sshd 2>/dev/null || true
   ```

4. **Conectarte por SSH**:
   - Ahora deberías poder conectarte
   - **IMPORTANTE**: Una vez conectado, continúa con la Fase 2

**Si falla**: Continúa con Vía 4.

---

### Vía 4: Modificar Configuración de Fail2ban

**Cuándo usar**: Fail2ban está bloqueando todo y necesitas cambiar la configuración.

**Pasos**:

1. **Acceder por Consola de Hetzner** (ver Vía 2, pasos 1-2)

2. **Modificar configuración para ser más permisiva**:
   ```bash
   # Hacer backup
   sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup
   
   # Editar configuración
   sudo nano /etc/fail2ban/jail.local
   ```

3. **Cambiar configuración temporalmente**:
   ```ini
   [DEFAULT]
   # Aumentar maxretry para ser más permisivo
   maxretry = 20
   bantime = 1m  # Reducir tiempo de ban
   findtime = 30m
   
   [sshd]
   enabled = true
   maxretry = 20
   bantime = 1m
   findtime = 30m
   # Agregar tu IP a la whitelist
   ignoreip = 127.0.0.1/8 ::1 TU_IP_AQUI
   ```

4. **Reiniciar Fail2ban**:
   ```bash
   sudo systemctl restart fail2ban
   ```

5. **Intentar conexión SSH nuevamente**

---

## ✅ FASE 2: Una Vez Recuperado el Acceso

Una vez que tengas acceso SSH, **debes asegurarte de que esto no vuelva a pasar**.

### Paso 1: Verificar Estado Actual

```bash
# Ver estado de Fail2ban
sudo fail2ban-client status

# Ver IPs baneadas
sudo fail2ban-client get sshd banned

# Ver IPs en whitelist
sudo fail2ban-client get sshd ignoreip

# Ver tu IP actual
curl https://api.ipify.org
```

### Paso 2: Agregar Tu IP a la Whitelist Permanentemente

```bash
# Obtener tu IP
MY_IP=$(curl -s https://api.ipify.org)
echo "Tu IP: $MY_IP"

# Agregar a whitelist sin reiniciar (temporal)
sudo fail2ban-client set sshd addignoreip $MY_IP

# Agregar permanentemente a la configuración
sudo nano /etc/fail2ban/jail.local
# Agregar tu IP en la línea ignoreip de [DEFAULT] y [sshd]

# Reiniciar para aplicar cambios permanentes
sudo systemctl restart fail2ban

# Verificar
sudo fail2ban-client get sshd ignoreip
```

### Paso 3: Verificar Script de Emergencia Está Disponible

```bash
# Verificar que el script existe
ls -la /opt/codespartan/scripts/unban-ip.sh

# Si no existe, crearlo
sudo mkdir -p /opt/codespartan/scripts
sudo chmod +x /opt/codespartan/scripts/unban-ip.sh
# (El script debería estar en el repositorio)
```

### Paso 4: Configurar Acceso de Emergencia Adicional (Opcional)

Si tienes múltiples IPs o una VPN, agrégalas también:

```bash
# Agregar múltiples IPs a la whitelist
sudo fail2ban-client set sshd addignoreip IP1
sudo fail2ban-client set sshd addignoreip IP2
# etc.
```

---

## 🔒 FASE 3: Mejoras de Seguridad Post-Recuperación

Una vez recuperado el acceso, implementa estas mejoras para evitar futuros problemas:

### Mejora 1: Configurar Múltiples IPs en Whitelist

```bash
# Editar configuración
sudo nano /etc/fail2ban/jail.local

# Agregar todas tus IPs conocidas
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 TU_IP_CASA TU_IP_OFICINA TU_IP_VPN
```

### Mejora 2: Configurar Notificaciones por Email

Para saber cuándo alguien intenta atacar:

```bash
sudo nano /etc/fail2ban/jail.local

[DEFAULT]
destemail = tu-email@codespartan.es
sender = fail2ban@codespartan.es
action = %(action_mw)s  # Ban + Email
```

### Mejora 3: Monitoreo en Grafana

Verifica que el exporter de Fail2ban está funcionando:

```bash
# Verificar exporter
docker ps | grep fail2ban-exporter

# Ver métricas
curl http://localhost:9191/metrics | grep fail2ban
```

### Mejora 4: Backup de Configuración

```bash
# Crear backup automático
sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.$(date +%Y%m%d_%H%M%S)
```

---

## 📊 Matriz de Recuperación

| Vía | Método | Tiempo | Complejidad | Seguridad | Prioridad |
|-----|--------|--------|-------------|-----------|-----------|
| 1 | GitHub Actions | 1-2 min | ⭐ Baja | ✅ Alta | 🥇 Primera |
| 2 | Consola Hetzner | 2-5 min | ⭐⭐ Media | ✅ Alta | 🥈 Segunda |
| 3 | Detener Fail2ban | 1 min | ⭐ Baja | ⚠️ Baja | 🥉 Última |
| 4 | Modificar Config | 3-5 min | ⭐⭐⭐ Alta | ✅ Media | 🥉 Última |

---

## 🎯 Checklist de Recuperación

Cuando te banees, sigue este checklist en orden:

- [ ] **Paso 1**: Intentar GitHub Actions Workflow (Vía 1)
- [ ] **Paso 2**: Si falla, usar Consola de Hetzner (Vía 2)
- [ ] **Paso 3**: Si falla, deshabilitar Fail2ban temporalmente (Vía 3)
- [ ] **Paso 4**: Una vez recuperado acceso, agregar IP a whitelist
- [ ] **Paso 5**: Verificar script de emergencia está disponible
- [ ] **Paso 6**: Implementar mejoras de seguridad (Fase 3)
- [ ] **Paso 7**: Documentar qué pasó y por qué

---

## 🚨 Comandos de Emergencia Rápida

Guarda estos comandos en un lugar accesible:

```bash
# Desde Consola de Hetzner - Desbanear todas las IPs
sudo fail2ban-client set sshd unbanip all

# Desde Consola de Hetzner - Agregar IP a whitelist
sudo fail2ban-client set sshd addignoreip TU_IP

# Desde Consola de Hetzner - Detener Fail2ban (último recurso)
sudo systemctl stop fail2ban

# Desde SSH (una vez recuperado) - Ver estado completo
sudo fail2ban-client status sshd
```

---

## 📚 Referencias

- [Guía de Seguridad Fail2ban](FAIL2BAN_SAFETY.md) - Prevención de baneos
- [Documentación Fail2ban](FAIL2BAN.md) - Configuración completa
- [Disaster Recovery General](../03-operations/DISASTER_RECOVERY.md) - Plan general de DR
- [Script de Emergencia](../../codespartan/scripts/unban-ip.sh) - Script de desbaneo
- [Workflow de Emergencia](../../../.github/workflows/fail2ban-emergency-unban.yml) - Workflow de GitHub

---

## 🔄 Actualización del Plan

Este plan debe actualizarse cuando:
- Se agreguen nuevas vías de acceso
- Cambie la infraestructura (nuevo proveedor, etc.)
- Se implementen nuevas medidas de seguridad
- Se descubran nuevas vulnerabilidades

**Última actualización**: 2025-01-18  
**Próxima revisión**: 2025-04-18  
**Estado**: ✅ Plan completo implementado

