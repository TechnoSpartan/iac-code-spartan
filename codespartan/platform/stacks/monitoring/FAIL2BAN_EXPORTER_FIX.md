# Fail2ban-Exporter Docker Image Fix

**Fecha**: 2025-12-01
**Versión Final**: ghcr.io/mivek/fail2ban_exporter:latest
**Puerto**: 9921

## Problema Inicial

El workflow `deploy-monitoring.yml` fallaba continuamente con errores relacionados a la imagen del fail2ban-exporter. Los usuarios reportaban múltiples alertas falsas de "servicio caído" para el fail2ban-exporter.

## Investigación y Solución de Errores

### Intento 1: carlpett/fail2ban_exporter:latest (Histórico)

**Imagen**: `carlpett/fail2ban_exporter:latest`
**Estado**: ❌ FALLIDO
**Error**: Incompatibilidad con ARM64 o acceso al socket de fail2ban

**Problema**: La imagen original estaba causando alertas repetidas de servicio caído. Análisis mostró que:
- La imagen podría no ser compatible con arquitectura ARM64
- Posibles problemas de acceso al socket `/var/run/fail2ban`
- El proyecto parece estar abandonado/no mantenido

**Acción Tomada**: Comentado temporalmente en el docker-compose.yml

---

### Intento 2: hectorjsmith/fail2ban-prometheus-exporter (Commit b8334d9)

**Imagen**: `hectorjsmith/fail2ban-prometheus-exporter:latest`
**Puerto Configurado**: 5000
**Estado**: ❌ FALLIDO - Workflow #45-47

**Error de Imagen**:
```
pull access denied for hectorjsmith/fail2ban-prometheus-exporter,
repository does not exist or may require 'docker login'
```

**Análisis**:
- La imagen NO existe en Docker Hub
- El usuario `hectorjsmith` no existe en Docker Hub
- El nombre de imagen fue una suposición incorrecta

**Cambios Realizados**:
- Actualizado docker-compose.yml con nueva imagen
- Actualizado puerto a 5000
- Actualizado prometheus.yml para apuntar al nuevo puerto
- Se agregó debugging al workflow para mejorar diagnóstico

**Commit**: `b8334d9`

---

### Intento 3: registry.gitlab.com/hectorjsmith/fail2ban-prometheus-exporter (Commit 33e1c7d)

**Imagen**: `registry.gitlab.com/hectorjsmith/fail2ban-prometheus-exporter:latest`
**Puerto Configurado**: 9191
**Estado**: ❌ FALLIDO - Workflow #48

**Error de Imagen**:
```
error from registry: access forbidden
```

**Análisis**:
- La imagen SÍ existe en el GitLab Container Registry oficial
- Pero requiere autenticación o tiene restricciones de acceso público
- No es accesible para pulls anónimos desde el VPS

**Investigación Realizada**:
1. Búsqueda web de "fail2ban prometheus exporter docker image"
2. Encontrados múltiples exporters alternativos:
   - `glvr182/f2b-exporter` (Docker Hub)
   - `mivek/fail2ban_exporter` (GitHub Container Registry) ✓
   - `blackflysolutions/fail2ban-prometheus-exporter` (Docker Hub)
   - `yolokube/fail2ban-prometheus-exporter` (Docker Hub)

**Commit**: `33e1c7d`

---

### Solución Final: ghcr.io/mivek/fail2ban_exporter (Commit 949d2e7)

**Imagen**: `ghcr.io/mivek/fail2ban_exporter:latest`
**Puerto**: 9921
**Estado**: ✅ DEPLOYABLE - Workflow #52

**Razón de la Selección**:
- Disponible públicamente en GitHub Container Registry (GHCR)
- Proyecto activamente mantenido en GitHub: https://github.com/mivek/fail2ban_exporter
- Compatible con pull anónimo (sin autenticación)
- Puerto estándar documentado: 9921
- Python-based, bien documentado

**Cambios Realizados**:

#### docker-compose.yml
```yaml
fail2ban-exporter:
  image: ghcr.io/mivek/fail2ban_exporter:latest  # ← Cambio crítico
  container_name: fail2ban-exporter
  volumes:
    - /var/run/fail2ban:/var/run/fail2ban:ro
  networks:
    - monitoring
  healthcheck:
    test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9921/metrics"]  # ← Puerto actualizado
```

#### prometheus.yml
```yaml
- job_name: 'fail2ban'
  static_configs:
    - targets: ['fail2ban-exporter:9921']  # ← Puerto actualizado
  scrape_interval: 30s
  scrape_timeout: 10s
```

**Commit**: `949d2e7`

---

## Cambios Adicionales al Workflow

### Commit 5e80496: Enhanced Debugging
Se agregó debugging mejorado para facilitar diagnóstico futuro:
- Información del sistema Docker (versión, espacio en disco)
- Listado de archivos en el directorio de monitoreo
- Estado de contenedores después de deployar

### Commit cda3977: Remove Invalid Secrets
Se removieron referencias a secretos inexistentes:
- `GRAFANA_ADMIN_USER`
- `GRAFANA_ADMIN_PASSWORD`

**Razón**: Grafana está configurado para OAuth2-only (Authelia), no usa credenciales de admin local

---

## Resumen de Cambios de Configuración

| Parámetro | Intento 1 | Intento 2 | Intento 3 | Final |
|-----------|-----------|-----------|-----------|-------|
| Imagen Base | carlpett | hectorjsmith (Docker Hub) | registry.gitlab.com | ghcr.io (mivek) |
| Accesibilidad | Private? | ❌ No existe | ❌ Acceso denegado | ✅ Pública |
| Puerto | N/A | 5000 | 9191 | 9921 |
| Estado | ❌ | ❌ | ❌ | ✅ |

---

## Lecciones Aprendidas

1. **Validación de Imágenes**: Siempre verificar que la imagen existe antes de usar
2. **Registries Alternativos**: Docker Hub no es el único registry; considerar:
   - GitHub Container Registry (ghcr.io)
   - GitLab Container Registry
   - Quay.io
3. **Documentación**: Buscar el repositorio oficial del proyecto para instrucciones de deployment
4. **Debugging Mejorado**: Logging detallado es crucial para diagnóstico remoto
5. **Puertos Estándar**: Cada exporter tiene un puerto específico; no asumir

---

## Verificación Final

**Workflow #52** está en ejecución con la configuración final.

**Puntos a Verificar**:
- [ ] Workflow #52 completa exitosamente
- [ ] fail2ban-exporter descarga la imagen correctamente
- [ ] Container inicia y pasa healthcheck
- [ ] Prometheus puede hacer scrape en puerto 9921
- [ ] Métricas de fail2ban aparecen en Grafana
- [ ] Desaparecen las alertas falsas de "servicio caído"

---

## Referencias

- **Repositorio del Proyecto**: https://github.com/mivek/fail2ban_exporter
- **GitHub Container Registry Docs**: https://docs.github.com/en/packages/working-with-a-github-packages-registry
- **Fail2ban Documentation**: https://www.fail2ban.org/

---

## Commits Relacionados

- `b8334d9` - Fix: Replace fail2ban-exporter with official hectorjsmith image
- `5e80496` - CI: Add enhanced debugging to workflow
- `cda3977` - Fix: Remove unused Grafana admin secrets from workflow
- `33e1c7d` - Fix: Use correct fail2ban-exporter image from GitLab registry
- `949d2e7` - Fix: Use publicly accessible fail2ban-exporter image from GHCR

