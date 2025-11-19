# Backups - Operaciones Diarias

Guía para gestionar backups diarios de la plataforma.

## Backup Automático Diario

### Configuración

**Schedule:** 3:00 AM diario (vía cron)

**Qué se respalda:**
- Volúmenes Docker: `victoria-data`, `loki-data`, `grafana-data`
- Configuraciones de plataforma: `/opt/codespartan/platform/`
- Certificados SSL: `/opt/codespartan/platform/traefik/letsencrypt/`

**Retención:**
- Local: 7 días (`/opt/codespartan/backups/`)
- Remoto: 30 días (si está configurado)

**Ubicación del backup:**
```bash
/opt/codespartan/backups/backup-YYYY-MM-DD_HH-MM-SS.tar.gz
```

## Backup Manual

```bash
# SSH al servidor
ssh leonidas@91.98.137.217

# Ejecutar script de backup manualmente
/opt/codespartan/scripts/backup.sh

# Verificar que se creó el backup
ls -lh /opt/codespartan/backups/
```

## Descargar Backup Localmente

```bash
# Descargar último backup
scp leonidas@91.98.137.217:/opt/codespartan/backups/backup-*.tar.gz ./
```

## Backups de Hetzner Cloud

Hetzner Cloud ofrece backups automatizados a nivel de servidor (snapshots completos del VPS).

### Características

- Snapshots completos del VPS (imagen completa del disco)
- Hasta 7 backups retenidos automáticamente
- Almacenados en infraestructura Hetzner (separado del VPS)
- Costo: 20% del precio del servidor (~€0.98/mes para cax11)
- Puede restaurar o crear nuevos servidores desde backups

### Habilitar Backups Automatizados

```bash
# Opción 1: Usando script (recomendado)
cd /ruta/al/repo
HCLOUD_TOKEN=tu-token ./codespartan/platform/scripts/enable-hetzner-backups.sh

# Opción 2: Vía Hetzner Console
# 1. Visita: https://console.hetzner.cloud
# 2. Ve a: Servers → codespartan-vps
# 3. Click: "Enable Backups" button
# 4. Confirma costo (~20% del precio del servidor)
```

### Ver Backups

```bash
# Vía Hetzner Console
# https://console.hetzner.cloud → Servers → codespartan-vps → Backups tab

# Vía API
curl -H "Authorization: Bearer $HCLOUD_TOKEN" \
  "https://api.hetzner.cloud/v1/servers/<server-id>/actions" | jq '.actions[] | select(.command == "create_image")'
```

### Crear Snapshot Manual

```bash
# Vía Hetzner Console
# 1. Servers → codespartan-vps
# 2. Click "Create Snapshot"
# 3. Introduce descripción (ej: "Before major update")
# 4. Espera ~5-10 minutos para creación del snapshot

# Vía API
curl -X POST \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description": "Manual snapshot before update"}' \
  "https://api.hetzner.cloud/v1/servers/<server-id>/actions/create_image"
```

## Verificar Backups

```bash
# Listar backups locales
ls -lh /opt/codespartan/backups/

# Verificar tamaño y fecha
du -sh /opt/codespartan/backups/*

# Verificar integridad del backup
tar -tzf /opt/codespartan/backups/backup-YYYY-MM-DD_HH-MM-SS.tar.gz | head -20
```

## Restaurar desde Backup

Para procedimientos completos de restauración, consulta el [Plan de Disaster Recovery](DISASTER_RECOVERY.md).

## Troubleshooting

### Backup falla

```bash
# Ver logs del script de backup
tail -f /var/log/backup.log

# Verificar espacio en disco
df -h /opt/codespartan/backups/

# Verificar permisos
ls -la /opt/codespartan/scripts/backup.sh
```

### Backup no se ejecuta automáticamente

```bash
# Verificar cron job
crontab -l | grep backup

# Verificar que el script existe y es ejecutable
ls -la /opt/codespartan/scripts/backup.sh
chmod +x /opt/codespartan/scripts/backup.sh
```

## Mejores Prácticas

1. **Verificar backups regularmente**: Comprueba que los backups se están creando correctamente
2. **Probar restauración**: Realiza pruebas de restauración periódicamente
3. **Backups remotos**: Configura backups remotos para mayor seguridad
4. **Documentar cambios**: Antes de cambios importantes, crea un snapshot manual
5. **Monitorear espacio**: Asegúrate de tener suficiente espacio para backups

## Siguiente Paso

Para procedimientos completos de recuperación ante desastres, consulta el [Plan de Disaster Recovery](DISASTER_RECOVERY.md).

