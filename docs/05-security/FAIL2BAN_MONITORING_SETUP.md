# 📊 Fail2ban - Plan de Configuración de Monitoreo

## 📋 Objetivo

Configurar el monitoreo completo de Fail2ban en Grafana para:
- Ver IPs baneadas en tiempo real
- Recibir alertas cuando hay ataques
- Analizar patrones de ataque
- Monitorear el estado del exporter

---

## 🎯 Plan de Implementación

### Fase 1: Desplegar Fail2ban Exporter (5-10 min)

#### Paso 1.1: Verificar que el exporter está en docker-compose.yml

El exporter ya está configurado en:
```
codespartan/platform/stacks/monitoring/docker-compose.yml
```

**Verificar configuración:**
```bash
# Desde tu máquina local
cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan
grep -A 20 "fail2ban-exporter" codespartan/platform/stacks/monitoring/docker-compose.yml
```

**Deberías ver:**
```yaml
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
  # ... resto de configuración
```

#### Paso 1.2: Desplegar el exporter

**Opción A: Desde GitHub Actions (Recomendado)**

1. Ve a: https://github.com/TechnoSpartan/iac-code-spartan/actions
2. Selecciona: **Deploy Monitoring Stack**
3. Haz clic en **Run workflow**
4. Espera a que complete (~2-3 minutos)

**Opción B: Manualmente desde SSH**

```bash
# Conectarte al VPS
ssh leonidas@91.98.137.217

# Ir al directorio de monitoring
cd /opt/codespartan/platform/stacks/monitoring

# Desplegar solo el exporter (sin afectar otros servicios)
docker compose up -d fail2ban-exporter

# Verificar que está corriendo
docker ps | grep fail2ban-exporter
```

#### Paso 1.3: Verificar que el exporter funciona

```bash
# Verificar contenedor está corriendo
docker ps | grep fail2ban-exporter

# Verificar que expone métricas
curl http://localhost:9191/metrics | head -20

# Verificar logs
docker logs fail2ban-exporter
```

**Resultado esperado:**
- Contenedor en estado "Up"
- Métricas disponibles en `/metrics`
- Sin errores en los logs

---

### Fase 2: Configurar Scrape en Prometheus (Ya hecho ✅)

#### Paso 2.1: Verificar configuración

El job de scrape ya está configurado en:
```
codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml
```

**Verificar:**
```bash
# Desde tu máquina local
grep -A 5 "fail2ban" codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml
```

**Deberías ver:**
```yaml
- job_name: 'fail2ban'
  static_configs:
    - targets: ['fail2ban-exporter:9191']
  scrape_interval: 30s
  scrape_timeout: 10s
```

#### Paso 2.2: Reiniciar vmagent (si es necesario)

Si el exporter ya estaba desplegado antes de agregar el job, reinicia vmagent:

```bash
# Desde el VPS
cd /opt/codespartan/platform/stacks/monitoring
docker compose restart vmagent

# Verificar que está scrapeando
docker logs vmagent | grep -i fail2ban
```

**Resultado esperado:**
- Logs muestran intentos de scrape a `fail2ban-exporter:9191`
- Sin errores de conexión

---

### Fase 3: Verificar Métricas en VictoriaMetrics (2-3 min)

#### Paso 3.1: Verificar que las métricas están disponibles

```bash
# Desde el VPS
# Esperar 1-2 minutos para que se scrapeen las primeras métricas

# Verificar métricas disponibles
curl 'http://localhost:8428/api/v1/label/__name__/values' | grep fail2ban

# Verificar métrica específica
curl 'http://localhost:8428/api/v1/query?query=fail2ban_up'
```

**Resultado esperado:**
- Lista de métricas con prefijo `fail2ban_`
- `fail2ban_up` con valor `1` (exporter funcionando)

#### Paso 3.2: Ver métricas disponibles

```bash
# Ver todas las métricas de Fail2ban
curl 'http://localhost:8428/api/v1/label/__name__/values' | jq '.data[] | select(. | startswith("fail2ban"))'

# Ver IPs baneadas actualmente
curl 'http://localhost:8428/api/v1/query?query=fail2ban_jail_banned_total'

# Ver intentos fallidos
curl 'http://localhost:8428/api/v1/query?query=fail2ban_failed_total'
```

**Métricas disponibles:**
- `fail2ban_up` - Estado del exporter (1 = up, 0 = down)
- `fail2ban_banned_total` - Total de IPs baneadas por jail
- `fail2ban_failed_total` - Total de intentos fallidos por jail
- `fail2ban_jail_banned_total` - IPs baneadas por jail específico
- `fail2ban_jail_failed_total` - Intentos fallidos por jail específico

---

### Fase 4: Configurar Dashboard en Grafana (10-15 min)

#### Paso 4.1: Acceder a Grafana

1. Ve a: https://grafana.mambo-cloud.com
2. Inicia sesión:
   - Usuario: `admin`
   - Password: `codespartan123`

#### Paso 4.2: Importar Dashboard Pre-configurado (Opción A - Recomendado)

1. En Grafana, ve a: **Dashboards** → **Import**
2. Ingresa el ID: `13639`
3. Selecciona el datasource: **VictoriaMetrics**
4. Haz clic en **Import**

**Dashboard ID:** `13639` (Fail2ban Prometheus Exporter)

#### Paso 4.3: Crear Dashboard Manual (Opción B - Personalizado)

Si prefieres crear tu propio dashboard:

1. **Dashboards** → **New Dashboard** → **Add visualization**

2. **Panel 1: IPs Baneadas (Últimas 24h)**
   - Query:
     ```promql
     sum(increase(fail2ban_banned_total[24h])) by (jail)
     ```
   - Visualization: **Time series**
   - Title: "IPs Baneadas (Últimas 24h)"

3. **Panel 2: Intentos Fallidos por Minuto**
   - Query:
     ```promql
     sum(rate(fail2ban_failed_total[5m])) by (jail)
     ```
   - Visualization: **Time series**
   - Title: "Intentos Fallidos por Minuto"

4. **Panel 3: IPs Actualmente Baneadas**
   - Query:
     ```promql
     fail2ban_jail_banned_total
     ```
   - Visualization: **Stat**
   - Title: "IPs Actualmente Baneadas"

5. **Panel 4: Estado del Exporter**
   - Query:
     ```promql
     fail2ban_up
     ```
   - Visualization: **Stat**
   - Title: "Estado del Exporter"
   - Thresholds:
     - Red: `0`
     - Green: `1`

6. **Panel 5: Tasa de Baneos por Hora**
   - Query:
     ```promql
     rate(fail2ban_banned_total[1h])
     ```
   - Visualization: **Time series**
   - Title: "Tasa de Baneos por Hora"

7. **Guardar Dashboard:**
   - Nombre: "Fail2ban Monitoring"
   - Folder: "Security" (crear si no existe)

---

### Fase 5: Verificar Alertas (Ya configuradas ✅)

#### Paso 5.1: Verificar que las alertas están activas

Las alertas ya están configuradas en:
```
codespartan/platform/stacks/monitoring/alerts/rules.yml
```

**Verificar desde el VPS:**
```bash
# Ver reglas de alerta activas
curl http://localhost:8880/api/v1/rules | jq '.data.groups[] | select(.name == "fail2ban_alerts")'

# Ver alertas activas
curl http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.component == "fail2ban")'
```

**Alertas configuradas:**
1. **Fail2banExporterDown** - Exporter no responde
2. **Fail2banHighBanRate** - Alta tasa de baneos (>10 IPs/min)
3. **Fail2banHighFailureRate** - Alta tasa de intentos fallidos (>50/min)

#### Paso 5.2: Probar una alerta (Opcional)

```bash
# Detener el exporter temporalmente
docker stop fail2ban-exporter

# Esperar 2-3 minutos
# Verificar que se dispara la alerta
curl http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.alertname == "Fail2banExporterDown")'

# Reiniciar el exporter
docker start fail2ban-exporter
```

---

### Fase 6: Monitoreo Continuo (Ongoing)

#### Paso 6.1: Configurar Monitoreo de Logs

```bash
# Ver logs en tiempo real
sudo tail -f /var/log/fail2ban.log

# Ver logs del exporter
docker logs -f fail2ban-exporter

# Ver logs de vmagent (scraping)
docker logs -f vmagent | grep fail2ban
```

#### Paso 6.2: Revisar Dashboard Regularmente

- **Frecuencia recomendada**: Una vez por semana
- **Qué revisar**:
  - IPs baneadas recientemente
  - Patrones de ataque
  - Estado del exporter
  - Alertas activas

#### Paso 6.3: Mantenimiento

**Mensual:**
- Revisar configuración de Fail2ban
- Verificar que el exporter está actualizado
- Revisar alertas y ajustar umbrales si es necesario

**Trimestral:**
- Revisar dashboard y agregar nuevas métricas si es necesario
- Optimizar queries de Prometheus si hay problemas de performance

---

## ✅ Checklist de Verificación

Usa este checklist para verificar que todo está funcionando:

- [ ] **Fase 1**: Exporter desplegado y funcionando
  - [ ] Contenedor `fail2ban-exporter` está corriendo
  - [ ] Métricas disponibles en `http://localhost:9191/metrics`
  - [ ] Sin errores en logs

- [ ] **Fase 2**: Scrape configurado
  - [ ] Job `fail2ban` en `prometheus.yml`
  - [ ] `vmagent` está scrapeando (ver logs)

- [ ] **Fase 3**: Métricas en VictoriaMetrics
  - [ ] Métricas disponibles: `curl 'http://localhost:8428/api/v1/query?query=fail2ban_up'`
  - [ ] Valor de `fail2ban_up` es `1`

- [ ] **Fase 4**: Dashboard en Grafana
  - [ ] Dashboard importado o creado
  - [ ] Paneles muestran datos
  - [ ] Datasource correcto (VictoriaMetrics)

- [ ] **Fase 5**: Alertas configuradas
  - [ ] Reglas de alerta cargadas en vmalert
  - [ ] Alertas visibles en Alertmanager (si hay problemas)

- [ ] **Fase 6**: Monitoreo continuo
  - [ ] Logs accesibles
  - [ ] Dashboard revisado regularmente

---

## 🚨 Troubleshooting

### Exporter no puede conectar a Fail2ban socket

**Síntoma:**
```
Error: Cannot connect to Fail2ban socket
```

**Solución:**
```bash
# Verificar que el socket existe
ls -la /var/run/fail2ban/fail2ban.sock

# Verificar permisos
sudo chmod 666 /var/run/fail2ban/fail2ban.sock

# Verificar que Fail2ban está corriendo
systemctl status fail2ban

# Reiniciar exporter
docker restart fail2ban-exporter
```

### Métricas no aparecen en Grafana

**Síntoma:**
- Dashboard vacío o sin datos

**Solución:**
1. Verificar que el exporter está scrapeando:
   ```bash
   docker logs vmagent | grep fail2ban
   ```

2. Verificar que las métricas existen en VictoriaMetrics:
   ```bash
   curl 'http://localhost:8428/api/v1/label/__name__/values' | grep fail2ban
   ```

3. Verificar datasource en Grafana:
   - Datasource debe ser **VictoriaMetrics**
   - URL debe ser: `http://victoriametrics:8428`

### Alertas no se disparan

**Síntoma:**
- Alertas configuradas pero no se activan

**Solución:**
1. Verificar que vmalert tiene las reglas:
   ```bash
   curl http://localhost:8880/api/v1/rules | jq '.data.groups[] | select(.name == "fail2ban_alerts")'
   ```

2. Verificar que las métricas existen:
   ```bash
   curl 'http://localhost:8428/api/v1/query?query=fail2ban_up'
   ```

3. Reiniciar vmalert:
   ```bash
   docker restart vmalert
   ```

---

## 📚 Referencias

- [Documentación Fail2ban](FAIL2BAN.md)
- [Plan de Recuperación](FAIL2BAN_DISASTER_RECOVERY.md)
- [Dashboard ID 13639](https://grafana.com/grafana/dashboards/13639)
- [Fail2ban Prometheus Exporter](https://github.com/devops-workshop/fail2ban-prometheus-exporter)

---

## 🎯 Resumen del Plan

| Fase | Tarea | Tiempo | Prioridad |
|------|-------|--------|-----------|
| 1 | Desplegar exporter | 5-10 min | 🔴 Alta |
| 2 | Configurar scrape | ✅ Ya hecho | - |
| 3 | Verificar métricas | 2-3 min | 🟡 Media |
| 4 | Dashboard Grafana | 10-15 min | 🟡 Media |
| 5 | Verificar alertas | ✅ Ya hecho | - |
| 6 | Monitoreo continuo | Ongoing | 🟢 Baja |

**Tiempo total estimado:** 20-30 minutos

---

**Última actualización**: 2025-01-18  
**Estado**: ✅ Plan completo listo para ejecutar

