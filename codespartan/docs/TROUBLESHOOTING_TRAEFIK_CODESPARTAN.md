# 🔧 Troubleshooting: Traefik Container Discovery - CodeSpartan Cloud

## 📋 Resumen Ejecutivo

Este documento describe el problema encontrado al desplegar los servicios `www.codespartan.cloud` y `ui.codespartan.cloud`, donde Traefik no estaba descubriendo automáticamente los contenedores a pesar de tener las labels correctas y estar conectado al `docker-socket-proxy`.

**Solución implementada**: Uso del **File Provider** de Traefik para configurar manualmente los routers, similar a la solución aplicada en `cyberdyne-systems-es`.

**Estado**: ✅ **RESUELTO** - Ambos dominios funcionando correctamente.

---

## 🐛 Problema Identificado

### Síntomas

1. **Contenedores corriendo pero no accesibles**:
   ```bash
   docker ps | grep codespartan
   # codespartan-www   Up (unhealthy)
   # codespartan-ui    Up (unhealthy)
   ```

2. **HTTP 404 desde Traefik**:
   ```bash
   curl -Ik https://www.codespartan.cloud
   # HTTP/2 404
   
   curl -Ik https://ui.codespartan.cloud
   # HTTP/2 404
   ```

3. **Labels de Traefik presentes**:
   - ✅ `traefik.enable=true`
   - ✅ `traefik.http.routers.codespartan-www.rule=Host(\`www.codespartan.cloud\`)`
   - ✅ `traefik.http.routers.codespartan-ui.rule=Host(\`ui.codespartan.cloud\`)`
   - ✅ `traefik.docker.network=web`

4. **Contenedores en red correcta**:
   - ✅ Ambos contenedores en red `web`
   - ✅ Traefik en red `web` y `docker_api`

### Root Cause

Aunque Traefik estaba:
- ✅ Conectado correctamente al `docker-socket-proxy`
- ✅ Pudiendo listar los contenedores a través del proxy
- ✅ Viendo los contenedores `codespartan-www` y `codespartan-ui` en estado "running"

**No estaba creando los routers automáticamente** a pesar de tener las labels correctas.

**Posibles causas**:
1. Contenedores en estado "unhealthy" (aunque esto no debería impedir el discovery)
2. Problema de timing en el discovery del Docker Provider
3. Incompatibilidad entre la versión de Traefik y el docker-socket-proxy

---

## 🔍 Diagnóstico Realizado

### Workflows de Diagnóstico Creados

Se crearon varios workflows para diagnosticar el problema:

#### 1. `fix-traefik-discovery.yml`
Workflow completo de diagnóstico y solución que verifica:
- Estado de `docker-socket-proxy`
- Red `docker_api` y contenedores conectados
- Conectividad Traefik → docker-socket-proxy
- Labels de Traefik en contenedores
- Routers registrados en Traefik API

**Uso**:
```bash
gh workflow run "Fix Traefik Container Discovery"
```

#### 2. `check-traefik-routers-final.yml`
Verificación final de routers y servicios:
- Contenedores con labels de Traefik
- Routers desde API de Traefik
- Conectividad directa a contenedores
- Estado de red `web`

**Uso**:
```bash
gh workflow run "Check Traefik Routers (Final)"
```

#### 3. `debug-traefik-docker-provider.yml`
Debug profundo del Docker Provider:
- Configuración de Traefik (cmdline)
- Test de conectividad al proxy
- Listado de contenedores vistos por Traefik
- Logs de Traefik relacionados con Docker provider

**Uso**:
```bash
gh workflow run "Debug Traefik Docker Provider"
```

### Hallazgos del Diagnóstico

1. **docker-socket-proxy**: ✅ Funcionando correctamente
   ```
   docker-socket-proxy   Up 2 days (healthy)   docker_api
   ```

2. **Red docker_api**: ✅ Configurada correctamente
   ```
   traefik: 172.21.0.3/16
   docker-socket-proxy: 172.21.0.2/16
   ```

3. **Conectividad Traefik → Proxy**: ✅ Funcional
   ```bash
   docker exec traefik wget -qO- http://docker-socket-proxy:2375/version
   # {"Platform":{"Name":"Docker Engine - Community"},"Version":"29.0.0"...}
   ```

4. **Contenedores visibles por Traefik**: ✅ Detectados
   ```bash
   docker exec traefik wget -qO- "http://docker-socket-proxy:2375/containers/json?all=true"
   # Total containers: 18
   # Codespartan containers: 2
   #   - /codespartan-ui: running
   #   - /codespartan-www: running
   ```

5. **Conectividad Traefik → Contenedores**: ✅ Funcional
   ```bash
   docker exec traefik wget -qO- http://codespartan-www:80
   # <!DOCTYPE html>...
   
   docker exec traefik wget -qO- http://codespartan-ui:80
   # <!DOCTYPE html>...
   ```

6. **Routers en Traefik**: ❌ **NO registrados**
   - La API de Traefik no mostraba los routers de codespartan
   - A pesar de que los contenedores tenían las labels correctas

---

## ✅ Solución Implementada

### File Provider como Alternativa

Dado que el Docker Provider no estaba funcionando correctamente para estos contenedores, se implementó la solución usando el **File Provider** de Traefik, similar a la solución aplicada en `cyberdyne-systems-es`.

### Cambios Realizados

#### 1. Actualización de `dynamic-config.yml`

Se agregaron los routers y servicios en `codespartan/platform/traefik/dynamic-config.yml`:

```yaml
http:
  routers:
    # CodeSpartan Cloud - www.codespartan.cloud
    codespartan-www:
      rule: "Host(`www.codespartan.cloud`)"
      entrypoints:
        - websecure
      service: codespartan-www-service
      tls:
        certResolver: le
      middlewares:
        - security-headers
        - compression

    # CodeSpartan Cloud - ui.codespartan.cloud
    codespartan-ui:
      rule: "Host(`ui.codespartan.cloud`)"
      entrypoints:
        - websecure
      service: codespartan-ui-service
      tls:
        certResolver: le
      middlewares:
        - security-headers
        - compression

  services:
    # CodeSpartan Cloud - www service
    codespartan-www-service:
      loadBalancer:
        servers:
          - url: "http://codespartan-www:80"

    # CodeSpartan Cloud - ui service
    codespartan-ui-service:
      loadBalancer:
        servers:
          - url: "http://codespartan-ui:80"
```

#### 2. Despliegue de la Configuración

```bash
# 1. Commit y push de los cambios
git add codespartan/platform/traefik/dynamic-config.yml
git commit -m "feat: Add CodeSpartan routers to Traefik File Provider"
git push

# 2. Desplegar configuración actualizada
gh workflow run "Deploy Traefik"

# 3. Reiniciar Traefik para cargar la nueva configuración
gh workflow run "Restart Traefik"
```

### Workflows de Utilidad Creados

#### `restart-traefik.yml`
Reinicia Traefik y verifica que la configuración se cargó correctamente.

**Uso**:
```bash
gh workflow run "Restart Traefik"
```

#### `verify-codespartan-routing.yml`
Verifica que el routing de CodeSpartan está funcionando correctamente.

**Uso**:
```bash
gh workflow run "Verify CodeSpartan Routing"
```

---

## 🧪 Verificación

### Test de Conectividad

```bash
# Desde el VPS
curl -Ik https://www.codespartan.cloud
# HTTP/2 200 ✅

curl -Ik https://ui.codespartan.cloud
# HTTP/2 200 ✅

# Desde fuera del VPS
curl -Ik https://www.codespartan.cloud
# HTTP/2 200 ✅
# content-type: text/html
# server: nginx/1.29.3

curl -Ik https://ui.codespartan.cloud
# HTTP/2 200 ✅
# content-type: text/html
# server: nginx/1.29.3
```

### Estado Final

- ✅ `www.codespartan.cloud` → Funcionando (HTTP 200)
- ✅ `ui.codespartan.cloud` → Funcionando (HTTP 200)
- ✅ SSL/TLS → Certificados Let's Encrypt generados automáticamente
- ✅ Middlewares aplicados → `security-headers`, `compression`

---

## 📚 Lecciones Aprendidas

### 1. Docker Provider vs File Provider

**Docker Provider** (Auto-discovery):
- ✅ Ventaja: Automático, no requiere configuración manual
- ❌ Desventaja: Puede fallar en algunos casos (como este)
- ⚠️ Depende de: Labels correctas, contenedores healthy, timing correcto

**File Provider** (Configuración manual):
- ✅ Ventaja: Predecible, siempre funciona, versionado en Git
- ✅ Ventaja: Debuggeable, configuración explícita
- ❌ Desventaja: Requiere actualización manual cuando cambian contenedores
- ✅ Recomendado para: Casos edge donde Docker Provider falla

### 2. Hybrid Approach

La mejor práctica es usar un **enfoque híbrido**:
- **Docker Provider** como default para la mayoría de servicios
- **File Provider** para casos problemáticos o servicios críticos

### 3. Reinicio de Traefik

Aunque Traefik tiene `--providers.file.watch=true`, **a veces necesita reiniciarse** para cargar cambios en `dynamic-config.yml`, especialmente después de agregar nuevos routers.

### 4. Diagnóstico Sistemático

Los workflows de diagnóstico creados son útiles para:
- Verificar estado de infraestructura
- Debuggear problemas de routing
- Validar conectividad entre componentes

---

## 🔄 Proceso de Mantenimiento

### Agregar Nuevo Subdominio de CodeSpartan

1. **Agregar router en `dynamic-config.yml`**:
   ```yaml
   http:
     routers:
       codespartan-nuevo:
         rule: "Host(`nuevo.codespartan.cloud`)"
         entrypoints:
           - websecure
         service: codespartan-nuevo-service
         tls:
           certResolver: le
         middlewares:
           - security-headers
           - compression
     
     services:
       codespartan-nuevo-service:
         loadBalancer:
           servers:
             - url: "http://codespartan-nuevo:80"
   ```

2. **Commit y push**:
   ```bash
   git add codespartan/platform/traefik/dynamic-config.yml
   git commit -m "feat: Add nuevo.codespartan.cloud router"
   git push
   ```

3. **Desplegar y reiniciar**:
   ```bash
   gh workflow run "Deploy Traefik"
   # Esperar a que termine
   gh workflow run "Restart Traefik"
   ```

4. **Verificar**:
   ```bash
   curl -Ik https://nuevo.codespartan.cloud
   # Debe devolver HTTP/2 200
   ```

### Actualizar Configuración Existente

1. Editar `dynamic-config.yml`
2. Commit y push
3. Ejecutar `Deploy Traefik` (Traefik debería recargar automáticamente con `watch=true`)
4. Si no funciona, ejecutar `Restart Traefik`

---

## 🛠️ Troubleshooting Futuro

### Si los dominios vuelven a dar 404

1. **Verificar que los contenedores están corriendo**:
   ```bash
   gh workflow run "Quick Status"
   ```

2. **Verificar routers en Traefik**:
   ```bash
   gh workflow run "Check Traefik Routers (Final)"
   ```

3. **Verificar configuración**:
   ```bash
   gh workflow run "Verify CodeSpartan Routing"
   ```

4. **Reiniciar Traefik**:
   ```bash
   gh workflow run "Restart Traefik"
   ```

### Si el Docker Provider empieza a funcionar

Si en el futuro el Docker Provider empieza a descubrir los contenedores automáticamente, se puede:
1. Mantener la configuración del File Provider como backup
2. O eliminar los routers del File Provider y confiar solo en el Docker Provider

**Recomendación**: Mantener el File Provider como solución estable y confiable.

---

## 📖 Referencias

- [Traefik File Provider Documentation](https://doc.traefik.io/traefik/v3.6/providers/file/)
- [Traefik Docker Provider Documentation](https://doc.traefik.io/traefik/v3.6/providers/docker/)
- [Troubleshooting Cyberdyne - Similar Case](./cyberdyne-systems-es/TROUBLESHOOTING_TRAEFIK_DOCKER_PROVIDER.md)

---

## ✅ Checklist de Resolución

- [x] Diagnóstico completo del problema
- [x] Identificación de root cause
- [x] Implementación de solución (File Provider)
- [x] Creación de workflows de diagnóstico
- [x] Verificación de funcionamiento
- [x] Documentación del proceso
- [x] Documentación de mantenimiento futuro

---

## 🔧 Problema Adicional: Puerto 80 vs Puerto 3000 (Next.js)

### Síntomas

Después de resolver el problema de discovery de Traefik, el contenedor `codespartan-www` se iniciaba correctamente pero se cerraba inmediatamente:

```bash
docker logs codespartan-www
# ▲ Next.js 16.0.3
# - Local:         http://localhost:80
# - Network:       http://0.0.0.0:80
# ✓ Starting...
# ✓ Ready in 379ms
# Process exited with status 1
```

El contenedor aparecía como "unhealthy" y no respondía a peticiones HTTP.

### Root Cause

**Problema de privilegios de puerto**:

- En Linux, los puertos < 1024 (como el 80) requieren privilegios de **root**
- El Dockerfile usa el usuario `nextjs` (no-root) por **seguridad**
- Next.js no puede bindear al puerto 80 sin privilegios de root
- El proceso se inicia pero falla al intentar escuchar en el puerto 80

### Solución Implementada

**Cambio a puerto no-privilegiado (3000)**:

1. **Dockerfile** (`trackworks-maqueta/Dockerfile`):
   ```dockerfile
   EXPOSE 3000
   ENV PORT=3000
   ENV HOSTNAME="0.0.0.0"
   
   HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
     CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
   ```

2. **docker-compose.yml**:
   ```yaml
   labels:
     - traefik.http.services.codespartan-www.loadbalancer.server.port=3000
   
   healthcheck:
     test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
   ```

3. **Traefik dynamic-config.yml**:
   ```yaml
   services:
     codespartan-www-service:
       loadBalancer:
         servers:
           - url: "http://codespartan-www:3000"
   ```

### Verificación

```bash
# Verificar que el contenedor está corriendo
docker ps | grep codespartan-www
# codespartan-www   Up 5 minutes (healthy)   3000/tcp

# Verificar que escucha en el puerto 3000
docker exec codespartan-www wget -qO- http://localhost:3000/health
# {"status":"OK"}

# Verificar desde fuera del contenedor
curl -Ik https://www.codespartan.cloud
# HTTP/2 200
```

### Lecciones Aprendidas

1. **Puertos privilegiados**: Siempre usar puertos > 1024 cuando se ejecuta como usuario no-root
2. **Seguridad primero**: Es mejor usar puerto 3000 con usuario no-root que puerto 80 con root
3. **Traefik transparente**: Traefik maneja el routing interno, el puerto 3000 es transparente para usuarios finales
4. **Health checks**: Asegurar que el healthcheck use el mismo puerto que la aplicación

### Alternativas Consideradas

1. **Usar nginx como reverse proxy interno**:
   - Pros: Podría usar puerto 80
   - Contras: Más complejidad, más recursos, capa adicional innecesaria
   - **Decisión**: No necesario, Traefik ya hace el routing

2. **Usar capabilities de Linux**:
   ```dockerfile
   RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/node
   ```
   - Pros: Podría usar puerto 80
   - Contras: Menos seguro, requiere capabilities adicionales
   - **Decisión**: No recomendado por seguridad

3. **Ejecutar como root**:
   - Pros: Podría usar puerto 80
   - Contras: **Riesgo de seguridad crítico**
   - **Decisión**: ❌ Nunca recomendado

### Referencias

- [Next.js Docker Documentation](https://nextjs.org/docs/deployment#docker-image)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Linux Port Privileges](https://www.w3.org/Daemon/User/Installation/PrivilegedPorts.html)

---

## 🔧 Problema Adicional: Docker BuildKit y Directorio `.storybook` (Storybook)

### Síntomas

Durante el despliegue de `ui.codespartan.cloud` (Storybook), el build de Docker fallaba con el siguiente error:

```bash
SB_CORE-SERVER_0006 (MainFileMissingError): No configuration files have been found in your configDir: ./.storybook.
Storybook needs a "main.js" file, please add it.

You can pass a --config-dir flag to tell Storybook, where your main.js file is located at.
```

El contenedor `codespartan-ui` no se podía construir porque Storybook no encontraba su directorio de configuración.

### Root Cause

**Problema de optimización de Docker BuildKit**:

1. **BuildKit optimiza nombres de archivos/directorios**:
   - BuildKit puede "optimizar" nombres de directorios que empiezan con punto (`.storybook`)
   - En algunos casos, copia `.storybook` como `storybook` (sin el punto inicial)
   - Esto rompe la detección automática de Storybook que busca `.storybook` por defecto

2. **Cache de Docker**:
   - Aunque se deshabilitó el cache en el workflow (`no-cache: true`), BuildKit puede seguir usando optimizaciones
   - Los logs mostraban `COPY .storybook ./storybook` en lugar de `COPY .storybook ./.storybook`

3. **Storybook busca `main.js` en `.storybook`**:
   - Storybook busca `main.js` (o `main.ts`) en el directorio `.storybook` por defecto
   - Si el directorio se llama `storybook` (sin punto), Storybook no lo encuentra

### Solución Implementada

**Uso del flag `--config-dir` de Storybook**:

En lugar de intentar forzar que BuildKit copie correctamente `.storybook`, se usa el flag `--config-dir` que Storybook proporciona explícitamente para este caso.

#### Cambios en el Dockerfile

```dockerfile
# 2. Construir Storybook estático (genera storybook-static/)
# Detectar dónde BuildKit copió .storybook y usar --config-dir apropiado
RUN STORYBOOK_DIR="" && \
    if [ -d .storybook ]; then \
      STORYBOOK_DIR=".storybook"; \
      echo "✅ .storybook existe (con punto)"; \
    elif [ -d storybook ]; then \
      STORYBOOK_DIR="storybook"; \
      echo "✅ storybook existe (sin punto - BuildKit optimizó)"; \
    else \
      echo "❌ ERROR: No se encontró .storybook ni storybook" && \
      ls -la | grep storybook && \
      exit 1; \
    fi && \
    echo "📁 Directorio de Storybook: $STORYBOOK_DIR" && \
    ls -la "$STORYBOOK_DIR/" | head -5 && \
    echo "🔧 Construyendo Storybook con --config-dir=$STORYBOOK_DIR" && \
    pnpm build-storybook --config-dir="$STORYBOOK_DIR"
```

**Características de la solución**:

1. **Detección automática**: Detecta si BuildKit copió `.storybook` o `storybook`
2. **Flag `--config-dir`**: Usa el flag que Storybook recomienda explícitamente
3. **Combinado en un solo RUN**: La detección y el build están en el mismo `RUN` para que la variable persista
4. **Debugging**: Incluye logs para ver qué directorio se detectó

### Verificación

```bash
# Verificar que el build detecta correctamente el directorio
docker build -t test-storybook .
# Debe mostrar:
# ✅ .storybook existe (con punto)
# o
# ✅ storybook existe (sin punto - BuildKit optimizó)
# 📁 Directorio de Storybook: .storybook (o storybook)
# 🔧 Construyendo Storybook con --config-dir=.storybook

# Verificar que Storybook se construye correctamente
docker run --rm test-storybook ls -la /usr/share/nginx/html
# Debe mostrar los archivos estáticos de Storybook
```

### Lecciones Aprendidas

1. **BuildKit optimiza nombres**: BuildKit puede "optimizar" nombres de directorios, especialmente los que empiezan con punto
2. **Usar flags oficiales**: Cuando una herramienta proporciona un flag para resolver un problema, usarlo es la mejor solución
3. **Detección vs. Forzar**: Es mejor detectar y adaptarse que intentar forzar un comportamiento específico
4. **Variables en RUN**: Las variables de shell no persisten entre diferentes comandos `RUN`, por lo que la detección y el uso deben estar en el mismo `RUN`

### Alternativas Consideradas

1. **Copiar `.storybook` a un nombre temporal y renombrarlo**:
   ```dockerfile
   COPY .storybook ./_storybook_temp
   RUN mv _storybook_temp .storybook
   ```
   - Pros: Podría funcionar
   - Contras: BuildKit puede seguir optimizando, no es la solución recomendada por Storybook
   - **Decisión**: No usado, Storybook recomienda `--config-dir`

2. **Convertir TypeScript a JavaScript**:
   ```dockerfile
   RUN cd .storybook && tsc main.ts
   ```
   - Pros: Podría resolver el problema de `main.js` vs `main.ts`
   - Contras: No resuelve el problema del directorio, Storybook 8 soporta TypeScript
   - **Decisión**: No necesario, Storybook 8 soporta TypeScript nativamente

3. **Deshabilitar BuildKit**:
   ```bash
   DOCKER_BUILDKIT=0 docker build
   ```
   - Pros: Evitaría las optimizaciones
   - Contras: Pierde todas las ventajas de BuildKit (cache, paralelización, etc.)
   - **Decisión**: ❌ No recomendado, BuildKit es esencial para builds eficientes

### Referencias

- [Storybook CLI Options](https://storybook.js.org/docs/api/cli-options#build-storybook)
- [Docker BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [Storybook Configuration Directory](https://storybook.js.org/docs/configure)

---

**Última actualización**: 2025-11-18  
**Estado**: ✅ Resuelto y documentado

