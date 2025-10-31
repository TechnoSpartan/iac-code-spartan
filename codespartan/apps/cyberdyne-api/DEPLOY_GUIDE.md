# 🚀 Guía de Despliegue - Cyberdyne API

## 📋 Resumen

Esta guía te ayudará a desplegar la API de Cyberdyne Systems en `api.cyberdyne-systems.es`.

## 🎯 Requisitos Previos

### 1. GitHub Secrets

Asegúrate de que tu repositorio de IaC (`iac-code-spartan`) tenga estos secrets configurados:

- `VPS_SSH_HOST`: 91.98.137.217
- `VPS_SSH_USER`: leonidas
- `VPS_SSH_KEY`: Tu clave privada SSH
- `GH_PAT`: GitHub Personal Access Token con permisos para leer el repo de la API

### 2. Repositorio de la API

El repositorio `ms-nd-bko-trackworks` debe tener:

- ✅ Un `Dockerfile` en la raíz que construya la imagen de la API
- ✅ Un endpoint `/health` que responda con status 200 OK
- ✅ La API debe escuchar en el puerto `3000` (o ajustar el docker-compose.yml)

## 🏗️ Estructura Creada

Se ha creado la siguiente estructura en el proyecto IaC:

```
codespartan/apps/cyberdyne-api/
├── docker-compose.yml      # Configuración de Docker con Traefik
├── .env.example           # Variables de entorno de ejemplo
├── .gitignore            # Archivos a ignorar
└── README.md             # Documentación

.github/workflows/
└── deploy-cyberdyne-api.yml  # Workflow de GitHub Actions
```

## 🔧 Configuración

### Docker Compose

El archivo `docker-compose.yml` está configurado para:

- ✅ Usar la imagen de GitHub Container Registry
- ✅ Health check en `/health` cada 10 segundos
- ✅ Configuración de CORS para permitir peticiones desde los subdominios de Cyberdyne
- ✅ Labels de Traefik para enrutamiento automático a `api.cyberdyne-systems.es`
- ✅ SSL automático con Let's Encrypt

### Variables de Entorno

Por defecto, la API se configura con:
- `NODE_ENV=production`
- `PORT=3000`

Para añadir más variables, edita el archivo `.env.example` y luego crea un `.env` real o añade las variables en el `docker-compose.yml`.

## 🚀 Proceso de Despliegue

### Opción 1: Despliegue Manual (Primera vez)

1. **Commit y push** los cambios del proyecto IaC:
   ```bash
   cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan
   git add codespartan/apps/cyberdyne-api/
   git add .github/workflows/deploy-cyberdyne-api.yml
   git commit -m "feat: add Cyberdyne API configuration"
   git push
   ```

2. **Ejecuta el workflow manualmente** desde GitHub:
   - Ve a Actions → "Deploy Cyberdyne API"
   - Click en "Run workflow"
   - Selecciona la rama `main`
   - Click en "Run workflow"

3. **Monitorea el despliegue**:
   - El workflow mostrará el progreso en tiempo real
   - Tarda aproximadamente 2-3 minutos

### Opción 2: Despliegue Automático

El despliegue se ejecutará automáticamente cuando:
- Hagas push a la configuración en `codespartan/apps/cyberdyne-api/**`

## 🔍 Verificación

Después del despliegue, verifica que todo funcione:

### 1. Health Check
```bash
curl https://api.cyberdyne-systems.es/health
```

### 2. Verificar contenedor
```bash
ssh leonidas@91.98.137.217 "docker ps | grep cyberdyne-api"
```

### 3. Ver logs
```bash
ssh leonidas@91.98.137.217 "docker logs cyberdyne-api -f"
```

### 4. Estado del health check
```bash
ssh leonidas@91.98.137.217 "docker inspect cyberdyne-api --format='{{.State.Health.Status}}'"
```

## 🐛 Troubleshooting

### El contenedor no arranca

1. Verifica los logs:
   ```bash
   ssh leonidas@91.98.137.217 "docker logs cyberdyne-api --tail 100"
   ```

2. Verifica que la imagen se haya construido correctamente en GitHub Actions

3. Verifica que el puerto 3000 esté correcto

### Health check falla

1. Verifica que tu API tenga un endpoint `/health`:
   ```javascript
   // Ejemplo para Express
   app.get('/health', (req, res) => {
     res.status(200).json({ status: 'ok' });
   });
   ```

2. Verifica que la API esté escuchando en el puerto 3000:
   ```javascript
   app.listen(3000, '0.0.0.0', () => {
     console.log('API listening on port 3000');
   });
   ```

### CORS issues

Si tienes problemas de CORS, ajusta las origins en el `docker-compose.yml`:

```yaml
- traefik.http.middlewares.cyberdyne-api-cors.headers.accesscontrolalloworiginlist=https://www.cyberdyne-systems.es,https://staging.cyberdyne-systems.es
```

### SSL no funciona

1. Verifica que Traefik esté corriendo:
   ```bash
   ssh leonidas@91.98.137.217 "docker ps | grep traefik"
   ```

2. Verifica los certificados:
   ```bash
   ssh leonidas@91.98.137.217 "docker exec traefik ls -la /letsencrypt/acme.json"
   ```

## 📊 Métricas

El workflow registra métricas en `/tmp/deploy_metrics.txt`:
- `DEPLOY_TIME`: Tiempo total de despliegue
- `DEPLOY_STATUS`: success, health_check_failed, o container_failed

## 🔄 Actualizar la API

Para desplegar una nueva versión de la API:

1. Haz cambios en el repositorio `ms-nd-bko-trackworks`
2. Ejecuta el workflow "Deploy Cyberdyne API" manualmente desde GitHub Actions
3. El workflow:
   - Construirá la nueva imagen Docker
   - La subirá a GitHub Container Registry
   - La desplegará en el VPS
   - Ejecutará health checks
   - Limpiará imágenes antiguas

## 🔐 Seguridad

- ✅ Tráfico HTTPS con Let's Encrypt
- ✅ CORS configurado
- ✅ Variables de entorno seguras
- ✅ Imágenes privadas en GHCR
- ⚠️ Considera añadir rate limiting en Traefik
- ⚠️ Considera añadir autenticación/API keys

## 📚 Próximos Pasos

1. [ ] Añadir variables de entorno específicas de tu API
2. [ ] Configurar base de datos si es necesario
3. [ ] Añadir monitoreo en Grafana
4. [ ] Configurar alertas
5. [ ] Añadir tests automatizados
6. [ ] Documentar los endpoints de la API

## 🆘 Soporte

Si tienes problemas:
1. Revisa los logs del workflow en GitHub Actions
2. Revisa los logs del contenedor con `docker logs`
3. Verifica que todos los secrets estén configurados correctamente
4. Verifica que el repositorio de la API tenga un Dockerfile válido

---

**Última actualización**: 2025-10-12
r 