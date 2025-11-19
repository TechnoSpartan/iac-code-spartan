# 📧 Configurar SMTP para Authelia

## 📋 Resumen

Esta guía explica cómo configurar Authelia para enviar correos electrónicos de forma segura usando GitHub Secrets en lugar de hardcodear contraseñas.

**Estado actual**: ❌ SMTP deshabilitado (comentado en configuración)  
**Objetivo**: ✅ Habilitar SMTP usando secretos seguros

---

## 🔒 Problema Actual

La configuración actual tiene la contraseña SMTP hardcodeada en el workflow:

```yaml
# .github/workflows/configure-smtp.yml (línea 169)
password: Codespartan$2  # ❌ HARDCODEADO - INSEGURO
```

**Riesgo**: Si el workflow se hace público o se expone, la contraseña queda visible.

---

## ✅ Solución: Usar GitHub Secrets

### Paso 1: Crear GitHub Secrets

1. Ve a **Settings → Secrets and variables → Actions**
2. Click en **New repository secret**
3. Crear los siguientes secrets:

| Secret Name | Descripción | Ejemplo |
|-------------|-------------|---------|
| `AUTHELIA_SMTP_HOST` | Servidor SMTP | `smtp.hostinger.com` |
| `AUTHELIA_SMTP_PORT` | Puerto SMTP | `465` |
| `AUTHELIA_SMTP_USERNAME` | Usuario SMTP | `iam@codespartan.es` |
| `AUTHELIA_SMTP_PASSWORD` | Contraseña SMTP | `tu_contraseña_segura` |
| `AUTHELIA_SMTP_SENDER` | Email remitente | `noreply@codespartan.es` |

### Paso 2: Crear Template de Configuración

Crear `configuration.yml.template` que será usado por el workflow:

```yaml
# codespartan/platform/authelia/configuration.yml.template
notifier:
  disable_startup_check: false

  filesystem:
    filename: /data/notifications.txt

  smtp:
    host: ${SMTP_HOST}
    port: ${SMTP_PORT}
    timeout: 5s
    username: ${SMTP_USERNAME}
    password: ${SMTP_PASSWORD}
    sender: "${SMTP_SENDER}"
    identifier: mambo-cloud.com
    subject: "[Mambo Cloud] {title}"
    startup_check_address: ${SMTP_USERNAME}
    disable_require_tls: false
    disable_html_emails: false
    tls:
      server_name: ${SMTP_HOST}
      skip_verify: false
```

### Paso 3: Actualizar Workflow de Deploy

```yaml
# .github/workflows/deploy-authelia.yml
name: Deploy Authelia

on:
  workflow_dispatch:
  push:
    paths:
      - 'codespartan/platform/authelia/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare configuration with secrets
        env:
          SMTP_HOST: ${{ secrets.AUTHELIA_SMTP_HOST }}
          SMTP_PORT: ${{ secrets.AUTHELIA_SMTP_PORT }}
          SMTP_USERNAME: ${{ secrets.AUTHELIA_SMTP_USERNAME }}
          SMTP_PASSWORD: ${{ secrets.AUTHELIA_SMTP_PASSWORD }}
          SMTP_SENDER: ${{ secrets.AUTHELIA_SMTP_SENDER }}
        run: |
          # Instalar envsubst si no está disponible
          sudo apt-get update && sudo apt-get install -y gettext-base || true
          
          # Reemplazar variables en template
          envsubst < codespartan/platform/authelia/configuration.yml.template > codespartan/platform/authelia/configuration.yml
          
          # Verificar que no hay placeholders sin reemplazar
          if grep -q '\${' codespartan/platform/authelia/configuration.yml; then
            echo "❌ ERROR: Hay variables sin reemplazar en configuration.yml"
            exit 1
          fi

      - name: Copy files to VPS
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          source: "codespartan/platform/authelia/*"
          target: "/opt/codespartan/platform/authelia"
          strip_components: 3

      - name: Deploy Authelia
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_SSH_HOST }}
          username: ${{ secrets.VPS_SSH_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /opt/codespartan/platform/authelia
            docker compose up -d
            sleep 10
            docker logs authelia --tail 20
```

### Paso 4: Verificar Configuración

```bash
# Verificar que SMTP está configurado
docker exec authelia cat /config/configuration.yml | grep -A 10 "smtp:"

# Verificar que Authelia puede enviar emails
docker logs authelia | grep -i "smtp\|email\|notification"

# Test manual (desde dentro del contenedor)
docker exec authelia authelia crypto hash generate argon2 --password 'test'
```

---

## 🧪 Testing SMTP

### Test 1: Verificar Conexión SMTP

```bash
# Desde el VPS
docker exec authelia wget -qO- http://localhost:9091/api/health

# Verificar logs de startup
docker logs authelia | grep -i "smtp\|startup"
```

### Test 2: Trigger Password Reset (envía email)

1. Ir a `https://auth.mambo-cloud.com`
2. Click en "Reset Password"
3. Ingresar email: `iam@codespartan.es`
4. Verificar que llega el email

### Test 3: Verificar Notificaciones

```bash
# Verificar archivo de notificaciones (fallback)
docker exec authelia cat /data/notifications.txt

# Verificar logs
docker logs authelia | grep -i "notification\|email"
```

---

## 🔧 Configuración SMTP por Proveedor

### Hostinger (Actual)

```yaml
smtp:
  host: smtp.hostinger.com
  port: 465
  username: iam@codespartan.es
  password: ${AUTHELIA_SMTP_PASSWORD}
  tls:
    server_name: smtp.hostinger.com
    skip_verify: false
```

### Gmail

```yaml
smtp:
  host: smtp.gmail.com
  port: 587
  username: tu-email@gmail.com
  password: ${AUTHELIA_SMTP_PASSWORD}  # App Password, no contraseña normal
  tls:
    server_name: smtp.gmail.com
    skip_verify: false
```

**Nota**: Gmail requiere "App Password", no la contraseña normal.

### SendGrid

```yaml
smtp:
  host: smtp.sendgrid.net
  port: 587
  username: apikey
  password: ${SENDGRID_API_KEY}
  tls:
    server_name: smtp.sendgrid.net
    skip_verify: false
```

### Mailgun

```yaml
smtp:
  host: smtp.mailgun.org
  port: 587
  username: postmaster@tu-dominio.mailgun.org
  password: ${MAILGUN_SMTP_PASSWORD}
  tls:
    server_name: smtp.mailgun.org
    skip_verify: false
```

---

## 🚨 Troubleshooting

### Error: "SMTP connection failed"

**Causas posibles**:
1. Firewall bloqueando puerto 465/587
2. Credenciales incorrectas
3. TLS/SSL mal configurado

**Solución**:
```bash
# Verificar conectividad desde VPS
telnet smtp.hostinger.com 465

# Verificar logs de Authelia
docker logs authelia | grep -i smtp

# Test manual de SMTP
docker run --rm -it alpine sh
apk add --no-cache openssl
openssl s_client -connect smtp.hostinger.com:465
```

### Error: "Startup check failed"

**Causa**: Authelia no puede enviar email de prueba al iniciar.

**Solución**:
```yaml
# Deshabilitar startup check temporalmente
notifier:
  disable_startup_check: true  # Solo para debugging
```

**Luego verificar manualmente** y volver a habilitar.

### Email no llega

**Verificar**:
1. Spam folder
2. Logs de Authelia: `docker logs authelia`
3. Archivo de notificaciones: `docker exec authelia cat /data/notifications.txt`
4. Configuración SMTP: `docker exec authelia cat /config/configuration.yml | grep -A 15 smtp`

---

## ✅ Checklist de Implementación

- [ ] Crear GitHub Secrets para SMTP
- [ ] Crear `configuration.yml.template`
- [ ] Actualizar workflow `deploy-authelia.yml`
- [ ] Eliminar contraseña hardcodeada del workflow `configure-smtp.yml`
- [ ] Probar deploy con nuevos secrets
- [ ] Verificar que Authelia inicia correctamente
- [ ] Test de envío de email (password reset)
- [ ] Verificar que emails llegan correctamente
- [ ] Documentar en README

---

## 📚 Referencias

- [Authelia SMTP Documentation](https://www.authelia.com/configuration/notifier/smtp/)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Hostinger SMTP Settings](https://www.hostinger.com/tutorials/how-to-use-free-email-smtp-server)

---

**Última actualización**: 2025-11-18  
**Estado**: ⚠️ Pendiente de implementación

