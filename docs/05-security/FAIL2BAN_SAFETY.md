# 🛡️ Fail2ban - Guía de Seguridad y Prevención de Baneos Accidentales

## ⚠️ Importante: Protección Contra Baneos Accidentales

Esta guía te ayuda a evitar que Fail2ban te banees a ti mismo y cómo recuperar el acceso si ocurre.

---

## ✅ Protecciones Implementadas

### 1. Whitelist Automática

Cuando instalas Fail2ban, el script **automáticamente detecta tu IP actual** y la agrega a la whitelist. Esto significa que:

- ✅ Tu IP **NUNCA será baneada** por Fail2ban
- ✅ Puedes hacer múltiples intentos de conexión sin riesgo
- ✅ Incluso si escribes mal la contraseña varias veces, no te baneará

### 2. Script de Emergencia

Existe un script de emergencia en el VPS:

```bash
/opt/codespartan/scripts/unban-ip.sh
```

**Uso:**
```bash
# Desbanear una IP específica
sudo /opt/codespartan/scripts/unban-ip.sh <TU_IP>

# Desbanear TODAS las IPs (útil en emergencias)
sudo /opt/codespartan/scripts/unban-ip.sh all
```

### 3. Workflow de Emergencia en GitHub Actions

Si te baneas y no puedes acceder por SSH, puedes usar el workflow de GitHub Actions:

1. Ve a **Actions** → **Fail2ban Emergency Unban**
2. Haz clic en **Run workflow**
3. Ingresa tu IP o `all` para desbanear todas
4. El workflow se conectará al VPS y te desbaneará

---

## 🚨 ¿Qué Hacer Si Te Baneas?

### Opción 1: Workflow de GitHub Actions (Recomendado)

**Si no puedes acceder por SSH:**

1. Ve a: https://github.com/TechnoSpartan/iac-code-spartan/actions
2. Selecciona: **Fail2ban Emergency Unban**
3. Haz clic en **Run workflow**
4. Ingresa tu IP pública (o `all` para desbanear todas)
5. Ejecuta el workflow

**Para obtener tu IP pública:**
```bash
curl https://api.ipify.org
```

### Opción 2: Desde el VPS (Si Tienes Acceso)

Si tienes acceso al VPS por otro medio (consola de Hetzner, otra IP, etc.):

```bash
# Desbanear tu IP
sudo /opt/codespartan/scripts/unban-ip.sh <TU_IP>

# O desbanear todas
sudo /opt/codespartan/scripts/unban-ip.sh all
```

### Opción 3: Comando Directo de Fail2ban

```bash
# Ver IPs baneadas
sudo fail2ban-client get sshd banned

# Desbanear IP específica
sudo fail2ban-client set sshd unbanip <TU_IP>

# Desbanear de todos los jails
for jail in $(sudo fail2ban-client status | grep "Jail list:" | sed 's/.*:\s*//' | tr ',' ' '); do
  sudo fail2ban-client set $jail unbanip <TU_IP>
done
```

---

## 🔒 Agregar IPs a la Whitelist

### Método 1: Editar Configuración Manualmente

```bash
sudo nano /etc/fail2ban/jail.local
```

Agrega tu IP en la sección `[DEFAULT]`:

```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 TU_IP_AQUI OTRA_IP_AQUI
```

Luego reinicia Fail2ban:

```bash
sudo systemctl restart fail2ban
```

### Método 2: Agregar IP Temporalmente (Sin Reiniciar)

```bash
# Agregar IP a la whitelist del jail sshd
sudo fail2ban-client set sshd addignoreip <TU_IP>

# Verificar
sudo fail2ban-client get sshd ignoreip
```

---

## 📋 Verificar Tu IP Está en la Whitelist

```bash
# Ver IPs en whitelist (DEFAULT)
sudo fail2ban-client get DEFAULT ignoreip

# Ver IPs en whitelist del jail sshd
sudo fail2ban-client get sshd ignoreip
```

---

## ⚙️ Configuración Actual

- **Max retries**: 5 intentos fallidos
- **Find time**: 10 minutos (ventana de tiempo)
- **Ban time**: 10 minutos (duración del ban)
- **Whitelist**: Tu IP actual + localhost

---

## 🧪 Test de Seguridad (Opcional)

Si quieres verificar que tu IP está protegida:

```bash
# Desde tu máquina local, intenta conectarte con contraseña incorrecta
# (solo si tienes autenticación por contraseña habilitada)
# Esto NO debería banearte si tu IP está en la whitelist

# Verificar que no te baneó
ssh usuario@vps
# Si te conectas, significa que no te baneó (correcto)
```

**⚠️ ADVERTENCIA**: Solo haz este test si estás seguro de que tu IP está en la whitelist.

---

## 📚 Comandos Útiles

```bash
# Ver estado general
sudo fail2ban-client status

# Ver estado del jail SSH
sudo fail2ban-client status sshd

# Ver IPs baneadas
sudo fail2ban-client get sshd banned

# Ver IPs en whitelist
sudo fail2ban-client get sshd ignoreip

# Ver logs en tiempo real
sudo tail -f /var/log/fail2ban.log

# Ver estadísticas
sudo fail2ban-client status sshd
```

---

## 🎯 Mejores Prácticas

1. **Siempre usa claves SSH**: Evita autenticación por contraseña
2. **Mantén tu IP en whitelist**: Especialmente si cambias de IP frecuentemente
3. **Usa el workflow de emergencia**: Si te baneas, es la forma más rápida de recuperar acceso
4. **Monitorea los logs**: Revisa periódicamente `/var/log/fail2ban.log`
5. **Ten un plan B**: Guarda el script de emergencia en un lugar accesible

---

## 🔗 Referencias

- [Documentación principal de Fail2ban](FAIL2BAN.md)
- [Script de instalación](../../codespartan/scripts/install-fail2ban.sh)
- [Script de emergencia](../../codespartan/scripts/unban-ip.sh)
- [Workflow de emergencia](../../../.github/workflows/fail2ban-emergency-unban.yml)

---

**Última actualización**: 2025-01-18  
**Estado**: ✅ Protecciones implementadas

