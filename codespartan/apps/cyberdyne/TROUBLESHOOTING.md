# 🔍 Diagnóstico y Solución - HTTP 404 en Cyberdyne Systems

## 📋 Resumen del Problema

El sitio `www.cyberdyne-systems.es` devuelve HTTP 404 después del despliegue, a pesar de que el contenedor Docker está corriendo y healthy.

## 🎯 Causa Raíz Identificada

El workflow de deploy **NO estaba copiando el `docker-compose.yml`** del proyecto IaC al servidor. Esto causaba que:

1. El contenedor se construía sin los labels correctos de Traefik
2. Traefik no podía enrutar el tráfico al contenedor
3. El resultado era un HTTP 404

## ✅ Solución Implementada

He actualizado el workflow `.github/workflows/deploy-cyberdyne.yml` para:

1. **Hacer checkout de ambos repositorios**:
   - Repositorio de la aplicación (`ft-r-bko-dummy`)
   - Repositorio de IaC (para obtener el `docker-compose.yml` correcto)

2. **Copiar el docker-compose.yml actualizado**:
   - Se copia desde `iac/codespartan/apps/cyberdyne/docker-compose.yml` al VPS
   - Esto asegura que siempre se use la configuración correcta con labels de Traefik

3. **Validación antes del build**:
   - Verifica que el archivo existe antes de construir
   - Muestra error claro si falta

## 🚀 Pasos para Aplicar la Solución

### 1. Commit y Push del Workflow Corregido

```bash
cd /Users/krbaio3/Worker/@CodeSpartan/iac-code-spartan

git add .github/workflows/deploy-cyberdyne.yml
git add codespartan/scripts/diagnose-cyberdyne.sh
git commit -m "fix: ensure docker-compose.yml is copied during deploy + add diagnostic script"
git push
```

### 2. Ejecutar Diagnóstico en el VPS (Opcional pero Recomendado)

Antes de redesplegar, verifica el estado actual:

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Copiar el script de diagnóstico
cat > /tmp/diagnose-cyberdyne.sh << 'EOF'
[contenido del script]
EOF

# Ejecutar diagnóstico
bash /tmp/diagnose-cyberdyne.sh
```

Este script verificará:
- ✅ Estado del contenedor
- ✅ Health check
- ✅ Red Docker 'web'
- ✅ Labels de Traefik
- ✅ Estado de Traefik
- ✅ Conectividad interna
- ✅ Respuesta externa HTTP
- ✅ DNS

### 3. Redesplegar desde el Proyecto ft-r-bko-dummy

Ejecuta el workflow de deploy desde el otro proyecto. Esta vez:
- ✅ Se copiará el `docker-compose.yml` correcto
- ✅ El contenedor tendrá los labels de Traefik
- ✅ Traefik podrá enrutar correctamente el tráfico

## 🔧 Verificación Post-Deploy

Después del despliegue, verifica:

```bash
# 1. Contenedor corriendo y healthy
ssh leonidas@91.98.137.217 "docker ps | grep cyberdyne-frontend"
ssh leonidas@91.98.137.217 "docker inspect --format='{{.State.Health.Status}}' cyberdyne-frontend"

# 2. Labels de Traefik presentes
ssh leonidas@91.98.137.217 "docker inspect cyberdyne-frontend | grep traefik.enable"

# 3. Test HTTP
curl -I https://www.cyberdyne-systems.es
```

## 📊 Configuración Correcta Verificada

### ✅ DNS (terraform.tfvars)
```hcl
domains    = ["mambo-cloud.com", "cyberdyne-systems.es"]
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "api"]
manual_ipv4_address = "91.98.137.217"
```

### ✅ Docker Compose (codespartan/apps/cyberdyne/docker-compose.yml)
```yaml
services:
  frontend:
    container_name: cyberdyne-frontend
    labels:
      - traefik.enable=true
      - traefik.http.routers.cyberdyne-www.rule=Host(`www.cyberdyne-systems.es`)
      - traefik.http.routers.cyberdyne-www.entrypoints=websecure
      - traefik.http.routers.cyberdyne-www.tls=true
      - traefik.http.routers.cyberdyne-www.tls.certresolver=le
      - traefik.docker.network=web
      - traefik.http.services.cyberdyne-frontend.loadbalancer.server.port=80
    networks:
      - web
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
```

### ✅ Workflow Actualizado
```yaml
- name: Checkout application repo
  uses: actions/checkout@v4
  with:
    repository: ${{ secrets.CYBERDYNE_APP_REPO }}
    token: ${{ secrets.GH_PAT }}
    path: app

- name: Checkout IaC repo for docker-compose
  uses: actions/checkout@v4
  with:
    path: iac

- name: Copy docker-compose from IaC repo
  uses: appleboy/scp-action@v0.1.7
  with:
    host: ${{ secrets.VPS_SSH_HOST }}
    username: ${{ secrets.VPS_SSH_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    source: "iac/codespartan/apps/cyberdyne/docker-compose.yml"
    target: "/opt/codespartan/apps/cyberdyne/"
    strip_components: 4
```

## 🐛 Problemas Comunes y Soluciones

### Problema 1: Contenedor sin labels de Traefik
**Síntoma**: HTTP 404, contenedor corriendo
**Causa**: docker-compose.yml sin labels o desactualizado
**Solución**: Usar el workflow actualizado que copia el docker-compose.yml del IaC

### Problema 2: Contenedor no en la red 'web'
**Síntoma**: HTTP 404, Traefik no ve el contenedor
**Causa**: docker-compose.yml sin configuración de red
**Solución**: 
```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/cyberdyne
docker compose down
docker compose up -d
```

### Problema 3: SSL no funciona
**Síntoma**: ERR_SSL_PROTOCOL_ERROR
**Causa**: Traefik no puede generar certificados
**Solución**: Verificar logs de Traefik y que el puerto 80 esté accesible

### Problema 4: Health check fallando
**Síntoma**: Contenedor en estado "unhealthy"
**Causa**: Aplicación no responde en localhost:80
**Solución**: Verificar logs del contenedor y que Nginx esté sirviendo archivos

## 🔍 Comandos de Troubleshooting

```bash
# Ver estado completo
ssh leonidas@91.98.137.217 "docker ps"

# Ver health status
ssh leonidas@91.98.137.217 "docker inspect cyberdyne-frontend --format='{{json .State.Health}}' | jq"

# Ver logs del contenedor
ssh leonidas@91.98.137.217 "docker logs cyberdyne-frontend --tail 50"

# Ver logs de Traefik
ssh leonidas@91.98.137.217 "docker logs traefik --tail 100 | grep cyberdyne"

# Test interno del contenedor
ssh leonidas@91.98.137.217 "docker exec cyberdyne-frontend wget -O- http://localhost/"

# Verificar archivos
ssh leonidas@91.98.137.217 "docker exec cyberdyne-frontend ls -lh /usr/share/nginx/html"

# Rebuild forzado
ssh leonidas@91.98.137.217 "cd /opt/codespartan/apps/cyberdyne && docker compose up -d --force-recreate --build"
```

## 📈 Próximos Pasos

1. ✅ **Inmediato**: Hacer commit y push del workflow corregido
2. ✅ **Inmediato**: Redesplegar desde ft-r-bko-dummy
3. ⏳ **Si aún falla**: Ejecutar script de diagnóstico en el VPS
4. ⏳ **Si necesario**: Rebuild manual del contenedor
5. 📊 **Después**: Añadir monitoreo en Grafana para detectar estos problemas

## 🎓 Lecciones Aprendidas

1. **El docker-compose.yml es parte de la infraestructura**, no de la aplicación
2. **Siempre copiar la configuración de IaC** durante el deploy
3. **Los labels de Traefik son críticos** para el enrutamiento
4. **Health checks nativos de Docker** son mejores que scripts externos
5. **Scripts de diagnóstico** ahorran tiempo en troubleshooting

## ✅ Checklist de Deploy Exitoso

- [ ] Workflow actualizado y pusheado
- [ ] Deploy ejecutado desde ft-r-bko-dummy
- [ ] Contenedor corriendo: `docker ps | grep cyberdyne-frontend`
- [ ] Health check OK: `docker inspect cyberdyne-frontend | grep healthy`
- [ ] Labels presentes: `docker inspect cyberdyne-frontend | grep traefik.enable`
- [ ] HTTP 200: `curl -I https://www.cyberdyne-systems.es`
- [ ] SSL funcionando: Candado verde en el navegador
- [ ] Subdominios funcionando: staging, lab

---

**Última actualización**: 2025-10-12  
**Estado**: Solución implementada, pendiente de aplicar en producción

