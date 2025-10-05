# 🗺️ Roadmap - CodeSpartan Mambo Cloud Platform

Plan de trabajo para completar la infraestructura production-ready antes de desplegar aplicaciones en contenedores.

---

## 📊 Estado Actual

**Completado:**
- ✅ VPS Hetzner ARM64 con Terraform
- ✅ Traefik con SSL automático (Let's Encrypt)
- ✅ Stack de monitoreo: VictoriaMetrics + Grafana + Loki + Promtail + cAdvisor + Node Exporter
- ✅ CI/CD con GitHub Actions
- ✅ Documentación completa actualizada
- ✅ **FASE 1 COMPLETA:** Verificación y Limpieza
  - ✅ Servidor limpio (solo 8 contenedores esperados)
  - ✅ Prometheus y Dozzle ya eliminados
  - ✅ Grafana: datasource legacy eliminado, VictoriaMetrics por defecto
  - ✅ 5 dashboards community importados
  - ✅ Documentación de dashboards creada

---

## ✅ Fase 1: Verificación y Limpieza (COMPLETADA)

**Objetivo:** Asegurar que la base está limpia y funcional.

- [x] **Limpiar servidor** - 10 min
  - [x] SSH al servidor
  - [x] Verificar Prometheus y Dozzle ya eliminados
  - [x] Verificar solo 8 contenedores corriendo: traefik, victoriametrics, vmagent, loki, promtail, grafana, cadvisor, node-exporter
  - [x] `docker system prune -f` (limpiar imágenes huérfanas) - 0B reclaimed

- [x] **Limpiar Grafana** - 15 min
  - [x] Eliminar datasource "Prometheus" legacy
  - [x] Configurar VictoriaMetrics como datasource por defecto
  - [x] Verificar solo quedan: VictoriaMetrics + Loki

- [x] **Testing completo** - 20 min
  - [x] Traefik: https://traefik.mambo-cloud.com ✓
  - [x] Grafana: https://grafana.mambo-cloud.com ✓
  - [x] Verificar métricas en Grafana (query `up`)
  - [x] Verificar logs en Loki disponibles

- [x] **Dashboards Grafana** - 30 min
  - [x] Importar Node Exporter Full (ID: 1860)
  - [x] Importar Traefik Official Standalone (ID: 17346)
  - [x] Importar Docker Monitoring (ID: 193)
  - [x] Importar VictoriaMetrics Cluster (ID: 11176)
  - [x] Importar Loki Logs/App (ID: 13639)
  - [x] Crear DASHBOARDS.md con guía de uso

**Entregable:** ✅ Infraestructura limpia, monitoreada y verificada.

**Nota:** Backoffice pendiente de despliegue (no está en el servidor aún).

---

## 🔔 Fase 2: Observabilidad Completa (PRIORIDAD ALTA)

**Objetivo:** Recibir alertas proactivas de problemas.

- [ ] **Sistema de alertas** - 1-2h
  - [ ] Decidir: AlertManager vs ntfy.sh vs webhook simple
  - [ ] Configurar alertas para:
    - [ ] CPU > 80% por 5 minutos
    - [ ] RAM > 90% por 3 minutos
    - [ ] Disk > 85%
    - [ ] Servicio caído > 2 minutos
    - [ ] Certificado SSL expira en < 7 días
    - [ ] HTTP 5xx errors > 10 en 1 minuto
  - [ ] Probar alertas manualmente
  - [ ] Documentar en docs/MONITORING.md

- [ ] **Dashboards custom** - 1h
  - [ ] Dashboard "Platform Health" con:
    - [ ] Estado de todos los servicios (up/down)
    - [ ] Uso de recursos (CPU, RAM, Disk)
    - [ ] Request rate de Traefik
    - [ ] Errores HTTP por servicio
  - [ ] Dashboard "Application Metrics" template
  - [ ] Dashboard "Costs & Resources"

- [ ] **Healthchecks** - 30 min
  - [ ] Añadir healthcheck a Traefik
  - [ ] Añadir healthcheck a Grafana
  - [ ] Añadir healthcheck a VictoriaMetrics
  - [ ] Template de healthcheck para apps

**Entregable:** Sistema de alertas funcionando + Dashboards útiles.

---

## 💾 Fase 3: Backups y Recuperación (PRIORIDAD ALTA)

**Objetivo:** Proteger datos críticos contra pérdida.

- [ ] **Sistema de backups** - 2-3h
  - [ ] Crear script `/opt/codespartan/scripts/backup.sh`:
    - [ ] Backup volúmenes: victoria-data, loki-data, grafana-data
    - [ ] Backup configs: `/opt/codespartan/`
    - [ ] Backup SSL certs: `traefik/letsencrypt/`
    - [ ] Comprimir con fecha: `backup-YYYY-MM-DD.tar.gz`
  - [ ] Configurar destino:
    - [ ] Opción A: Hetzner Storage Box
    - [ ] Opción B: S3-compatible (Backblaze B2, Wasabi)
    - [ ] Opción C: Rsync a servidor remoto
  - [ ] Cron job diario: `0 3 * * * /opt/codespartan/scripts/backup.sh`
  - [ ] Retención: 7 días locales, 30 días remotos

- [ ] **Restore testing** - 1h
  - [ ] Documentar procedimiento de restore en docs/DISASTER_RECOVERY.md
  - [ ] Probar restore en entorno local con Docker
  - [ ] Verificar integridad de backups semanalmente

- [ ] **Snapshots VPS** - 15 min
  - [ ] Configurar snapshot semanal automático en Hetzner Cloud
  - [ ] Documentar cómo restaurar desde snapshot

**Entregable:** Backups automáticos funcionando + Plan de recuperación documentado.

---

## 🛠️ Fase 4: DevOps Tooling (PRIORIDAD MEDIA)

**Objetivo:** Acelerar despliegue de nuevas aplicaciones.

- [ ] **Template de aplicación** - 1-2h
  - [ ] Crear `codespartan/apps/_TEMPLATE/`:
    - [ ] `docker-compose.yml` con Traefik labels
    - [ ] `README.md` con instrucciones
    - [ ] `.env.example` con variables típicas
    - [ ] `healthcheck.sh` script
  - [ ] Crear `.github/workflows/_template-deploy.yml`
  - [ ] Documentar en docs/ADDING_APPS.md:
    - [ ] Cómo crear una nueva app desde template
    - [ ] Cómo añadir subdominio en Terraform
    - [ ] Cómo configurar CI/CD

- [ ] **Scripts de mantenimiento** - 1h
  - [ ] `/opt/codespartan/scripts/cleanup.sh`:
    - [ ] `docker system prune -af --volumes` (con confirmación)
    - [ ] Limpiar logs antiguos
    - [ ] Limpiar backups locales > 7 días
  - [ ] `/opt/codespartan/scripts/health-check.sh`:
    - [ ] Verificar todos los servicios están up
    - [ ] Verificar disk space
    - [ ] Verificar certificados SSL válidos
  - [ ] `/opt/codespartan/scripts/update-containers.sh`:
    - [ ] Pull latest images
    - [ ] Recrear contenedores
    - [ ] Verificar todo funciona

- [ ] **Registry privado** (Opcional) - 2h
  - [ ] Decidir: Harbor vs Docker Registry simple
  - [ ] Configurar en `registry.mambo-cloud.com`
  - [ ] Configurar autenticación
  - [ ] Actualizar workflows para usar registry privado

**Entregable:** Templates + Scripts reutilizables para gestión.

---

## 🔒 Fase 5: Seguridad y Hardening (PRIORIDAD MEDIA)

**Objetivo:** Proteger la infraestructura contra amenazas.

- [ ] **Fail2ban** - 30 min
  - [ ] Instalar fail2ban en VPS
  - [ ] Configurar jail para SSH (5 intentos, ban 10 min)
  - [ ] Verificar funciona con intento fallido
  - [ ] Añadir a cloud-init en Terraform

- [ ] **Renovación SSL** - 15 min
  - [ ] Verificar auto-renovación funciona
  - [ ] Forzar renovación manual como test
  - [ ] Configurar alerta 7 días antes de expiración

- [ ] **Secrets management** - 1-2h (Opcional)
  - [ ] Evaluar: HashiCorp Vault vs Doppler vs Git-crypt
  - [ ] Migrar secrets de .env a solución elegida
  - [ ] Actualizar workflows para usar secrets manager

- [ ] **Network policies** - 1h
  - [ ] Crear redes Docker separadas por función:
    - [ ] `web` - Solo Traefik y apps públicas
    - [ ] `monitoring` - Stack de monitoreo
    - [ ] `backend` - Apps internas
  - [ ] Actualizar docker-compose con redes apropiadas

- [ ] **Rate limiting** - 30 min
  - [ ] Configurar rate limit en Traefik:
    - [ ] Global: 100 req/s por IP
    - [ ] Por servicio: ajustable
  - [ ] Configurar middlewares específicos
  - [ ] Probar con herramienta de carga (ab, wrk)

**Entregable:** Infraestructura hardened y protegida.

---

## 📚 Fase 6: Documentación Final (PRIORIDAD BAJA)

**Objetivo:** Conocimiento transferible y mantenible.

- [ ] **Runbook de aplicaciones** - 1h
  - [ ] Crear docs/APPLICATIONS.md:
    - [ ] Cómo añadir nueva aplicación
    - [ ] Cómo actualizar aplicación existente
    - [ ] Cómo borrar aplicación
    - [ ] Cómo hacer rollback
    - [ ] Cómo debuggear problemas comunes

- [ ] **Troubleshooting extendido** - 1h
  - [ ] Añadir casos reales a docs/TROUBLESHOOTING.md:
    - [ ] "App no accesible desde internet"
    - [ ] "SSL certificate invalid"
    - [ ] "Contenedor en restart loop"
    - [ ] "Disk full"
    - [ ] "Alta latencia en requests"
    - [ ] "Logs no aparecen en Grafana"

- [ ] **Architecture Decision Records** - 1h
  - [ ] Crear docs/ADRs/:
    - [ ] Por qué VictoriaMetrics vs Prometheus
    - [ ] Por qué Traefik vs Nginx/Caddy
    - [ ] Por qué Hetzner vs AWS/GCP/Azure
    - [ ] Por qué ARM64 vs x86_64

- [ ] **Disaster Recovery Plan** - 1h
  - [ ] Crear docs/DISASTER_RECOVERY.md:
    - [ ] Escenario 1: VPS borrado accidentalmente
    - [ ] Escenario 2: Certificados SSL corruptos
    - [ ] Escenario 3: Volumen de datos corrupto
    - [ ] Escenario 4: GitHub repo borrado
    - [ ] RTO (Recovery Time Objective)
    - [ ] RPO (Recovery Point Objective)

**Entregable:** Documentación completa y casos de uso reales.

---

## 🎁 Fase 7: Nice-to-Have (OPCIONAL)

**Objetivo:** Features avanzadas no críticas.

- [ ] **Multi-environment** - 3-4h
  - [ ] Crear VPS staging separado
  - [ ] Configurar subdominio `*.staging.mambo-cloud.com`
  - [ ] Workflow para deploy a staging antes de prod
  - [ ] Smoke tests automáticos en staging

- [ ] **Blue/Green deployments** - 2-3h
  - [ ] Configurar 2 instancias de cada app
  - [ ] Script para switch entre blue/green
  - [ ] Zero-downtime deploys

- [ ] **Watchtower** - 30 min
  - [ ] Configurar Watchtower para auto-update
  - [ ] Solo para apps no críticas
  - [ ] Notificaciones cuando actualiza

- [ ] **Portainer** - 30 min
  - [ ] Desplegar Portainer en `portainer.mambo-cloud.com`
  - [ ] UI web para gestionar Docker
  - [ ] Alternativa a línea de comandos

- [ ] **Uptime monitoring externo** - 15 min
  - [ ] Configurar UptimeRobot o Pingdom
  - [ ] Monitorear desde fuera del servidor:
    - [ ] https://grafana.mambo-cloud.com
    - [ ] https://traefik.mambo-cloud.com
    - [ ] Apps principales
  - [ ] Alertas por email/Telegram

**Entregable:** Features avanzadas para operación profesional.

---

## 📅 Plan de Ejecución Propuesto

### **Esta semana (4-8 horas)**
1. ✅ Fase 1: Verificación y Limpieza (1h)
2. 🔔 Fase 2: Observabilidad - Alertas básicas (1h)
3. 🔔 Fase 2: Observabilidad - Dashboards (1h)
4. 💾 Fase 3: Sistema de backups (2-3h)

### **Próxima semana (4-6 horas)**
5. 🛠️ Fase 4: Template de aplicación (1-2h)
6. 🛠️ Fase 4: Scripts de mantenimiento (1h)
7. 🔒 Fase 5: Fail2ban (30 min)
8. 🔒 Fase 5: Rate limiting (30 min)

### **Cuando tengas tiempo**
9. 📚 Fase 6: Documentación final (3-4h)
10. 🎁 Fase 7: Nice-to-have (según necesidad)

---

## 🎯 Próximos Pasos Inmediatos

**Empezar ahora con Fase 1:**

1. Conectar al servidor y limpiar Prometheus/Dozzle
2. Verificar que Backoffice funciona
3. Importar dashboards útiles a Grafana
4. Configurar alertas básicas

**Comando para comenzar:**
```bash
ssh leonidas@91.98.137.217
```

---

**Última actualización:** 2025-10-04
**Estado:** ✅ Fase 1 Completada | ⏭️ Siguiente: Fase 2 - Observabilidad (Alertas)
