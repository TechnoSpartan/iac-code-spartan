# 🔄 Sistema de Backups Automáticos - CodeSpartan Mambo Cloud

## 📋 Descripción

Sistema completo de backups automáticos que protege todos los componentes críticos de la infraestructura:

- ✅ **Dashboards de Grafana** (via API)
- ✅ **Datasources de Grafana**
- ✅ **Datos de VictoriaMetrics** (snapshots)
- ✅ **Configuración de Loki**
- ✅ **Certificados SSL de Traefik** (acme.json)
- ✅ **Configuraciones completas** (docker-compose.yml, .env, etc.)
- ✅ **Volúmenes Docker críticos**

## 🏗️ Arquitectura

```
┌──────────────────────────────────────────────────────┐
│              Cron Job (Semanal)                      │
│            Domingos a las 2:00 AM                    │
└────────────────────┬─────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │    backup.sh         │
          │  Script Principal    │
          └──────────┬───────────┘
                     │
      ┌──────────────┼──────────────┐
      ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Grafana  │  │Victoria  │  │ Traefik  │
│Dashboard │  │ Metrics  │  │   SSL    │
└──────────┘  └──────────┘  └──────────┘
      │              │              │
      └──────────────┼──────────────┘
                     ▼
           ┌──────────────────┐
           │ /opt/backups/    │
           │  backup_*.tar.gz │
           └──────────────────┘
                     │
                     ▼
        ┌──────────────────────────┐
        │   Rotación Automática    │
        │  (Mantiene últimos 7)    │
        └──────────────────────────┘
```

## 🚀 Despliegue

### Opción 1: Automático con GitHub Actions

```bash
# Hacer push a la rama main
git add codespartan/platform/stacks/backups/
git commit -m "feat: setup backup system"
git push origin main

# O ejecutar manualmente el workflow
# GitHub Actions → Deploy Backup System → Run workflow
```

### Opción 2: Manual por SSH

```bash
# Conectar al VPS
ssh leonidas@91.98.137.217

# Copiar scripts
sudo mkdir -p /opt/codespartan/platform/stacks/backups
# (copiar archivos backup.sh, restore.sh, setup-cron.sh)

# Ejecutar setup
sudo /opt/codespartan/platform/stacks/backups/setup-cron.sh
```

## 📦 Componentes del Sistema

### 1. `backup.sh` - Script Principal

Realiza el backup completo de todos los componentes.

**Ubicación**: `/opt/codespartan/platform/stacks/backups/backup.sh`

**Características**:
- Backup de Grafana dashboards via API
- Snapshot de VictoriaMetrics
- Backup de certificados SSL
- Compresión automática (tar.gz)
- Rotación de backups (mantiene últimos 7)
- Logs detallados con colores
- Metadata del backup incluida

**Uso**:
```bash
# Backup automático (nombre generado)
sudo /opt/codespartan/platform/stacks/backups/backup.sh

# Backup con nombre personalizado
sudo /opt/codespartan/platform/stacks/backups/backup.sh "pre_migration_backup"
```

**Salida**:
```
/opt/backups/
├── backup_20251016_020000.tar.gz
├── backup_20251009_020000.tar.gz
└── backup_20251002_020000.tar.gz
```

### 2. `restore.sh` - Script de Restauración

Restaura componentes desde un backup.

**Ubicación**: `/opt/codespartan/platform/stacks/backups/restore.sh`

**Uso**:
```bash
# Listar backups disponibles
ssh leonidas@91.98.137.217 "ls -lh /opt/backups/"

# Restaurar todo
sudo /opt/codespartan/platform/stacks/backups/restore.sh /opt/backups/backup_20251016_020000.tar.gz

# Restaurar solo Grafana
sudo /opt/codespartan/platform/stacks/backups/restore.sh /opt/backups/backup_20251016_020000.tar.gz --component grafana

# Restaurar solo Traefik
sudo /opt/codespartan/platform/stacks/backups/restore.sh /opt/backups/backup_20251016_020000.tar.gz --component traefik
```

**Componentes restaurables**:
- `grafana` - Dashboards y datasources
- `traefik` - SSL certificates y configs
- `victoriametrics` - Datos de métricas
- `configs` - Configuraciones completas
- `volumes` - Volúmenes Docker
- `all` - Todo (default)

### 3. `setup-cron.sh` - Configuración Automática

Configura el cron job y permisos.

**Ubicación**: `/opt/codespartan/platform/stacks/backups/setup-cron.sh`

**Qué hace**:
- Crea directorio `/opt/backups`
- Da permisos de ejecución a scripts
- Configura logrotate
- Añade cron job semanal
- Opción de crear backup inicial

**Uso**:
```bash
sudo /opt/codespartan/platform/stacks/backups/setup-cron.sh
```

## ⏰ Programación de Backups

### Cron Job Actual

```cron
# Domingos a las 2:00 AM
0 2 * * 0 /opt/codespartan/platform/stacks/backups/backup.sh >> /var/log/codespartan-backup.log 2>&1
```

### Verificar Cron Job

```bash
# Ver cron jobs activos
crontab -l

# Ver logs de backups
tail -f /var/log/codespartan-backup.log
```

### Modificar Programación

```bash
# Editar crontab
crontab -e

# Ejemplos de programación:
# Diario a las 3 AM:    0 3 * * *
# Cada 12 horas:        0 */12 * * *
# Lunes a las 1 AM:     0 1 * * 1
# Primer día del mes:   0 2 1 * *
```

## 📊 Contenido del Backup

Cada backup incluye:

```
backup_YYYYMMDD_HHMMSS/
├── grafana/
│   ├── grafana_backup.db          # Base de datos SQLite
│   ├── dashboards/                # Dashboards individuales
│   │   ├── dashboard-001.json
│   │   └── dashboard-002.json
│   └── datasources.json           # Todas las datasources
│
├── victoriametrics/
│   └── snapshot_YYYYMMDD/         # Snapshot de datos
│
├── loki/
│   └── loki-config.yml            # Configuración
│
├── traefik/
│   ├── acme.json                  # Certificados SSL
│   ├── traefik.yml                # Config principal
│   └── dynamic-config.yml         # Config dinámica
│
├── configs/
│   └── opt/codespartan/           # Todas las configs
│       ├── apps/*/docker-compose.yml
│       ├── platform/*/docker-compose.yml
│       └── **/.env
│
├── volumes/
│   ├── grafana-data.tar.gz
│   └── loki-data.tar.gz
│
└── backup_metadata.txt            # Info del backup
```

## 🔍 Monitoring y Logs

### Ver Logs en Tiempo Real

```bash
# Logs de backups
tail -f /var/log/codespartan-backup.log

# Últimos 100 líneas
tail -100 /var/log/codespartan-backup.log

# Buscar errores
grep -i error /var/log/codespartan-backup.log
```

### Verificar Estado

```bash
# Listar backups
ls -lh /opt/backups/

# Ver tamaño total
du -sh /opt/backups/

# Contar backups
ls -1 /opt/backups/backup_*.tar.gz | wc -l

# Ver metadata del último backup
tar -xzOf /opt/backups/backup_$(ls -t /opt/backups/backup_*.tar.gz | head -1) \
    */backup_metadata.txt | head -20
```

## 🚨 Troubleshooting

### Backup Falla

**Síntoma**: El script termina con error

**Solución**:
```bash
# Ver logs detallados
tail -100 /var/log/codespartan-backup.log

# Verificar permisos
ls -la /opt/codespartan/platform/stacks/backups/
sudo chmod +x /opt/codespartan/platform/stacks/backups/backup.sh

# Verificar espacio en disco
df -h /opt/backups

# Ejecutar manualmente con sudo
sudo /opt/codespartan/platform/stacks/backups/backup.sh
```

### Cron No Ejecuta

**Síntoma**: No se crean backups automáticos

**Solución**:
```bash
# Verificar que cron está corriendo
systemctl status cron

# Ver cron jobs
crontab -l

# Verificar logs de cron
grep CRON /var/log/syslog | tail -20

# Re-configurar cron
sudo /opt/codespartan/platform/stacks/backups/setup-cron.sh
```

### Espacio en Disco Lleno

**Síntoma**: Backups fallan por falta de espacio

**Solución**:
```bash
# Ver uso de disco
df -h

# Ver tamaño de backups
du -sh /opt/backups/*

# Limpiar backups viejos manualmente
cd /opt/backups
ls -t backup_*.tar.gz | tail -n +5 | xargs rm -f

# Reducir retención en backup.sh
# Editar RETENTION_COUNT en backup.sh
```

### Restauración Falla

**Síntoma**: restore.sh da errores

**Solución**:
```bash
# Verificar integridad del backup
tar -tzf /opt/backups/backup_YYYYMMDD_HHMMSS.tar.gz | head

# Extraer manualmente
mkdir /tmp/test_restore
tar -xzf /opt/backups/backup_YYYYMMDD_HHMMSS.tar.gz -C /tmp/test_restore

# Restaurar componente específico
sudo /opt/codespartan/platform/stacks/backups/restore.sh \
    /opt/backups/backup_YYYYMMDD_HHMMSS.tar.gz \
    --component grafana
```

## 🔐 Seguridad

### Permisos

```bash
# Scripts de backup (solo root puede ejecutar)
chmod 700 /opt/codespartan/platform/stacks/backups/*.sh

# Directorio de backups (solo root puede leer)
chmod 700 /opt/backups

# Certificados SSL en backup
chmod 600 /opt/backups/backup_*/traefik/acme.json
```

### Backups Offsite (Recomendado)

Para mayor seguridad, copia backups fuera del VPS:

```bash
# Opción 1: SCP a otro servidor
scp /opt/backups/backup_*.tar.gz user@backup-server:/backups/mambo-cloud/

# Opción 2: S3-compatible storage
apt install -y rclone
rclone copy /opt/backups/ remote:mambo-cloud-backups/

# Opción 3: Rsync
rsync -avz /opt/backups/ backup-server:/backups/mambo-cloud/
```

## 📚 Comandos Útiles

```bash
# Backup manual
sudo /opt/codespartan/platform/stacks/backups/backup.sh

# Backup con nombre personalizado
sudo /opt/codespartan/platform/stacks/backups/backup.sh "pre_update_$(date +%Y%m%d)"

# Listar todos los backups
ls -lht /opt/backups/

# Ver tamaño de backups
du -sh /opt/backups/*

# Restaurar todo desde el último backup
LATEST=$(ls -t /opt/backups/backup_*.tar.gz | head -1)
sudo /opt/codespartan/platform/stacks/backups/restore.sh "$LATEST"

# Restaurar solo Grafana
sudo /opt/codespartan/platform/stacks/backups/restore.sh "$LATEST" --component grafana

# Ver logs
tail -f /var/log/codespartan-backup.log

# Limpiar backups viejos (mantener últimos 3)
cd /opt/backups && ls -t backup_*.tar.gz | tail -n +4 | xargs rm -f
```

## 🎯 Mejoras Futuras

- [ ] Backup remoto automático (S3/Backblaze)
- [ ] Notificaciones por email/Slack en caso de fallo
- [ ] Cifrado de backups
- [ ] Verificación de integridad post-backup
- [ ] Dashboard de backups en Grafana
- [ ] Backup incremental para VictoriaMetrics

## 📞 Soporte

- **Logs**: `/var/log/codespartan-backup.log`
- **Documentación**: `codespartan/platform/stacks/backups/README.md`
- **Runbook**: `codespartan/docs/RUNBOOK.md`

---

**Mantenido por**: CodeSpartan Team
**Última actualización**: 2025-10-16
