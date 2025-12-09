# 🔄 Secret Rotation Procedures

**Última actualización**: 2025-12-09
**Estado**: Procedimientos documentados para rotación de secretos

---

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Política de Rotación](#política-de-rotación)
3. [Procedimientos por Tipo de Secret](#procedimientos-por-tipo-de-secret)
4. [Rotación de Emergencia](#rotación-de-emergencia)
5. [Checklist de Verificación](#checklist-de-verificación)
6. [Troubleshooting](#troubleshooting)

---

## Introducción

Este documento describe los procedimientos para rotar secretos de forma segura sin causar downtime en los servicios.

### Principios

1. **Zero Downtime**: La rotación no debe causar interrupciones
2. **Verificación**: Siempre verificar antes de eliminar secrets antiguos
3. **Rollback**: Mantener secrets antiguos hasta confirmar funcionamiento
4. **Documentación**: Registrar todas las rotaciones en changelog

---

## Política de Rotación

### Frecuencia Recomendada

| Tipo de Secret | Frecuencia | Razón |
|----------------|------------|-------|
| **SMTP Passwords** | 6 meses | Baja rotación (servicio externo) |
| **MongoDB Passwords** | 3 meses | Media rotación (acceso a datos) |
| **JWT Secrets** | 12 meses | Alta complejidad (rompe sesiones) |
| **Session Secrets** | 6 meses | Media rotación (invalida sesiones) |
| **Encryption Keys** | 12 meses | Alta complejidad (re-encriptación) |

### Rotación de Emergencia

Rotar **inmediatamente** si:
- ❗ Secret expuesto en logs o commit público
- ❗ Sospecha de compromiso de seguridad
- ❗ Empleado con acceso deja la organización
- ❗ Detección de acceso no autorizado

---

## Procedimientos por Tipo de Secret

### 1. Authelia SMTP Password

**Complejidad**: ⭐ Baja
**Downtime esperado**: Ninguno
**Rollback**: Fácil

#### Pasos

1. **Generar nuevo password en Hostinger**:
   ```bash
   # Acceder a panel Hostinger
   # Crear nuevo password para iam@codespartan.es
   # Copiar el nuevo password
   ```

2. **Actualizar GitHub Secret**:
   ```bash
   # Via GitHub UI
   # Settings → Secrets → Actions → AUTHELIA_SMTP_PASSWORD
   # Click "Update" → Pegar nuevo password → Save
   ```

3. **Redeploy Authelia**:
   ```bash
   gh workflow run deploy-authelia.yml
   ```

4. **Verificar**:
   ```bash
   # Check que Authelia inició correctamente
   curl -s https://auth.mambo-cloud.com/api/health

   # Verificar logs
   ssh leonidas@91.98.137.217 "docker logs authelia --tail 50 | grep -i smtp"
   ```

5. **Test funcional** (Opcional):
   - Ir a https://auth.mambo-cloud.com
   - Intentar "Forgot password"
   - Verificar que email llega

6. **Eliminar password antiguo**:
   - Eliminar password antiguo del panel de Hostinger

#### Rollback

Si falla:
```bash
# Revertir GitHub Secret al valor anterior
# Settings → Secrets → AUTHELIA_SMTP_PASSWORD → Update

# Redeploy
gh workflow run deploy-authelia.yml
```

---

### 2. MongoDB Password (TrackWorks)

**Complejidad**: ⭐⭐ Media
**Downtime esperado**: ~30 segundos
**Rollback**: Requiere recrear contenedor

#### Pasos

1. **Generar nuevo password**:
   ```bash
   # Generar password seguro de 32 caracteres
   openssl rand -base64 24
   ```

2. **Actualizar GitHub Secret**:
   ```bash
   # Via GitHub UI
   # Settings → Secrets → TRACKWORKS_MONGODB_PASSWORD
   # Update con nuevo password
   ```

3. **Preparar para downtime**:
   ```bash
   # Avisar a usuarios (si es producción)
   # Programar ventana de mantenimiento si es necesario
   ```

4. **Actualizar password en MongoDB**:
   ```bash
   ssh leonidas@91.98.137.217
   cd /opt/codespartan/apps/cyberdyne-systems-es/api

   # Detener API (para evitar errores de conexión)
   docker compose stop api

   # Conectar a MongoDB con password actual
   docker exec -it trackworks-mongodb mongosh \
     -u truckworks \
     -p 'CURRENT_PASSWORD' \
     --authenticationDatabase admin

   # Dentro de mongosh:
   use admin
   db.changeUserPassword("truckworks", "NEW_PASSWORD")
   exit
   ```

5. **Redeploy con nuevo password**:
   ```bash
   # Desde tu máquina local
   gh workflow run deploy-cyberdyne-api.yml

   # El workflow creará .env con el nuevo password y recreará contenedores
   ```

6. **Verificar**:
   ```bash
   # Check API health
   curl -s https://api.cyberdyne-systems.es/api/v1/health

   # Check logs de API
   ssh leonidas@91.98.137.217 "docker logs trackworks-api --tail 30"

   # No debe haber errores de autenticación MongoDB
   ```

#### Rollback

Si falla:
```bash
# 1. Revertir password en MongoDB
ssh leonidas@91.98.137.217
docker exec -it trackworks-mongodb mongosh -u truckworks -p 'NEW_PASSWORD' --authenticationDatabase admin
use admin
db.changeUserPassword("truckworks", "OLD_PASSWORD")
exit

# 2. Revertir GitHub Secret
# Settings → Secrets → TRACKWORKS_MONGODB_PASSWORD → Update con old password

# 3. Redeploy
gh workflow run deploy-cyberdyne-api.yml
```

---

### 3. Authelia JWT Secret

**Complejidad**: ⭐⭐⭐ Alta
**Downtime esperado**: Ninguno (pero invalida tokens activos)
**Impacto**: Usuarios deben volver a autenticarse

#### Pasos

1. **Generar nuevo secret**:
   ```bash
   openssl rand -base64 32
   ```

2. **Actualizar GitHub Secret**:
   ```bash
   # Via GitHub UI
   # Settings → Secrets → AUTHELIA_JWT_SECRET
   ```

3. **Redeploy Authelia**:
   ```bash
   gh workflow run deploy-authelia.yml
   ```

4. **Impacto esperado**:
   - ⚠️ Todos los tokens JWT activos quedan invalidados
   - ⚠️ Usuarios con password reset en proceso deben reiniciar
   - ✅ No afecta sesiones activas (usan SESSION_SECRET diferente)

5. **Comunicación**:
   - Avisar a usuarios que password reset tokens fueron invalidados
   - Solicitar nuevamente si tenían proceso en marcha

#### Rollback

Mismo procedimiento inverso que actualización.

---

### 4. Authelia Session Secret

**Complejidad**: ⭐⭐⭐ Alta
**Downtime esperado**: Ninguno
**Impacto**: **Cierra todas las sesiones activas**

#### Pasos

1. **Generar nuevo secret**:
   ```bash
   openssl rand -hex 32
   ```

2. **Planificación**:
   - ⚠️ **IMPORTANTE**: Rotar fuera de horas pico
   - ⚠️ Avisar a usuarios que serán deslogueados
   - ⚠️ Programar para horario de baja actividad

3. **Actualizar GitHub Secret**:
   ```bash
   # Settings → Secrets → AUTHELIA_SESSION_SECRET
   ```

4. **Redeploy Authelia**:
   ```bash
   gh workflow run deploy-authelia.yml
   ```

5. **Impacto esperado**:
   - ❌ **Todas las sesiones activas se invalidan**
   - ❌ Usuarios deben volver a autenticarse
   - ✅ Redis se limpia automáticamente

6. **Comunicación**:
   ```
   Subject: Mantenimiento programado - Authelia

   Estimados usuarios,

   El [FECHA] a las [HORA] realizaremos mantenimiento de seguridad
   en el sistema de autenticación.

   Impacto:
   - Duración: < 1 minuto
   - Deberán volver a iniciar sesión
   - No hay pérdida de datos

   Gracias,
   Equipo de Infraestructura
   ```

---

### 5. Authelia Encryption Key

**Complejidad**: ⭐⭐⭐⭐⭐ Muy Alta
**Downtime esperado**: Variable
**Impacto**: **Requiere re-encriptación de datos**

#### ⚠️ ADVERTENCIA

Rotar este secret requiere:
1. Backup completo de base de datos
2. Re-encriptación de todos los datos
3. Procedimiento de migración complejo
4. Posible pérdida de datos si falla

#### Recomendación

**NO rotar a menos que sea absolutamente necesario** (compromiso confirmado).

Si es necesario, contactar con el equipo de soporte de Authelia:
- https://www.authelia.com/
- https://github.com/authelia/authelia/discussions

#### Procedimiento Básico (Solo emergencia)

1. **Backup completo**:
   ```bash
   ssh leonidas@91.98.137.217
   /opt/codespartan/scripts/backup.sh
   ```

2. **Detener Authelia**:
   ```bash
   docker compose -f /opt/codespartan/platform/authelia/docker-compose.yml down
   ```

3. **Consultar documentación oficial**:
   - https://www.authelia.com/configuration/storage/introduction/

4. **Considerar recrear base de datos**:
   - Opción más simple: Eliminar DB y recrear
   - Impacto: Pierde 2FA configuraciones de usuarios
   - Usuarios deben reconfigurar 2FA

---

## Rotación de Emergencia

### Procedimiento de Emergencia (Secret Comprometido)

**Tiempo objetivo**: < 15 minutos

1. **Confirmar compromiso**:
   ```bash
   # Revisar logs de acceso
   ssh leonidas@91.98.137.217 "journalctl -u fail2ban --since '1 hour ago'"

   # Revisar commits públicos
   git log --all --full-history --pretty=format:'%H %s' | grep -i password
   ```

2. **Acción inmediata**:
   ```bash
   # Si está en commit público
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch PATH/TO/SECRET" \
     --prune-empty --tag-name-filter cat -- --all

   # Force push (PELIGROSO - solo si es necesario)
   git push origin --force --all
   ```

3. **Rotar secrets comprometidos**:
   - Seguir procedimientos específicos arriba
   - Priorizar por orden de criticidad:
     1. MongoDB passwords (acceso a datos)
     2. Session secrets (acceso a cuentas)
     3. SMTP passwords (envío de emails)
     4. JWT secrets (tokens)

4. **Verificar no hay accesos no autorizados**:
   ```bash
   # Revisar logs de Authelia
   docker logs authelia | grep -i "authentication\|login" | tail -100

   # Revisar MongoDB logs
   docker logs trackworks-mongodb | grep -i "auth" | tail -50
   ```

5. **Documentar incidente**:
   - Crear issue en GitHub (privado)
   - Registrar en changelog de seguridad
   - Notificar a stakeholders si es necesario

---

## Checklist de Verificación

### Pre-Rotación

- [ ] Backup reciente existe (< 24 horas)
- [ ] Ventana de mantenimiento programada (si aplica)
- [ ] Usuarios notificados (si aplica)
- [ ] Nuevo secret generado con suficiente entropía
- [ ] Secret antiguo anotado para rollback

### Durante Rotación

- [ ] GitHub Secret actualizado
- [ ] Workflow ejecutado exitosamente
- [ ] Contenedores reiniciados correctamente
- [ ] Logs no muestran errores

### Post-Rotación

- [ ] Endpoints públicos verificados (200 OK)
- [ ] Health checks passing
- [ ] Funcionalidad probada (login, API calls, etc.)
- [ ] Secret antiguo eliminado (después de 48h de estabilidad)
- [ ] Rotación documentada en changelog

---

## Troubleshooting

### Problema: Workflow falla al actualizar secret

**Síntoma**: GitHub Actions falla con error de variable no definida

**Solución**:
```bash
# Verificar que secret existe
gh secret list

# Verificar workflow tiene acceso
# .github/workflows/deploy-*.yml debe referenciar el secret correctamente
```

### Problema: Servicio no inicia después de rotación

**Síntoma**: Container en estado "Restarting"

**Diagnóstico**:
```bash
ssh leonidas@91.98.137.217
docker logs [CONTAINER_NAME] --tail 50
```

**Solución**:
```bash
# Rollback inmediato
# Revertir GitHub Secret
# Redeploy

# O verificar formato del secret (sin espacios, caracteres especiales escapados, etc.)
```

### Problema: MongoDB rechaza nueva contraseña

**Síntoma**: "Authentication failed" en logs de API

**Solución**:
```bash
# Verificar que el password se cambió correctamente en MongoDB
docker exec -it trackworks-mongodb mongosh -u truckworks -p 'NEW_PASSWORD' --authenticationDatabase admin

# Si falla, el password no se actualizó
# Volver a ejecutar changeUserPassword
```

---

## Registro de Rotaciones

### Changelog

Mantener registro de todas las rotaciones:

```markdown
| Fecha | Secret Rotado | Razón | Ejecutado por | Incidentes |
|-------|---------------|-------|---------------|------------|
| 2025-12-09 | Todos (migración inicial) | Migración a GitHub Secrets | Claude Code | Ninguno |
| YYYY-MM-DD | SMTP Password | Rotación programada 6 meses | [Nombre] | - |
```

---

## Referencias

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Authelia Configuration](https://www.authelia.com/configuration/prologue/introduction/)
- [MongoDB User Management](https://www.mongodb.com/docs/manual/tutorial/manage-users-and-roles/)
- [OpenSSL Random](https://www.openssl.org/docs/man1.1.1/man1/rand.html)

---

**Última revisión**: 2025-12-09
**Próxima revisión**: 2026-03-09 (3 meses)
