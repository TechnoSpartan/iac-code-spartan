# CodeSpartan Cloud - Guía de Despliegue para Cliente

## 📋 Resumen Ejecutivo

**Dominios configurados**:
- **www.codespartan.cloud** - Aplicación principal (frontend estático)
- **ui.codespartan.cloud** - Catálogo de componentes (Storybook)

**Estado actual**: ✅ Infraestructura lista, esperando código de la aplicación

**DNS**: ✅ Ya configurado y apuntando al VPS (91.98.137.217)

**SSL**: ✅ Automático via Let's Encrypt (Traefik)

**CI/CD**: ✅ GitHub Actions configurado para despliegue automático

---

## 🚀 Pasos para Integrar tu Código

### Paso 1: Preparar tu código de aplicación (www)

Tu aplicación debe ser un proyecto **React, Vue, o Vite** con estas características:

```json
// package.json mínimo requerido
{
  "name": "tu-app",
  "scripts": {
    "build": "vite build"  // O "react-scripts build"
  },
  "dependencies": {
    "react": "^18.x",
    // ... tus dependencias
  }
}
```

**Estructura esperada**:
```
tu-proyecto/
├── package.json
├── package-lock.json
├── src/              # Tu código fuente
├── public/           # Assets estáticos
└── vite.config.js    # O tu configuración de build
```

### Paso 2: Copiar código a www/

```bash
# Opción A: Clonar este repo y copiar tu código
cd /ruta/a/iac-code-spartan/codespartan/apps/codespartan-cloud/www/

# Copiar TODOS los archivos de tu proyecto aquí
# EXCEPTO: node_modules/, .git/, dist/, build/
cp -r /ruta/a/tu-proyecto/* .

# Asegúrate de mantener estos archivos que ya están aquí:
# - Dockerfile (NO borrar)
# - docker-compose.yml (NO borrar)
# - nginx.conf (NO borrar)
# - README.md (puedes actualizar si quieres)
```

### Paso 3: Ajustar Dockerfile según tu framework

**Por defecto está configurado para React (Create React App)**:
```dockerfile
# Línea 25 del Dockerfile:
COPY --from=builder /app/build /usr/share/nginx/html
```

**Si usas Vite/Vue** (output en `dist/`):
```dockerfile
# Cambiar línea 25 a:
COPY --from=builder /app/dist /usr/share/nginx/html
```

**Si usas Next.js** (output en `out/`):
```dockerfile
# Cambiar línea 25 a:
COPY --from=builder /app/out /usr/share/nginx/html
```

### Paso 4: Commit y Push

```bash
git add .
git commit -m "feat: Add CodeSpartan application code"
git push origin main
```

**🎉 Automático desde aquí**:
1. GitHub Actions detecta cambios en `codespartan/apps/codespartan-cloud/www/`
2. Construye imagen Docker
3. Push a GitHub Container Registry
4. Despliega al VPS
5. Genera certificado SSL
6. ✅ Disponible en https://www.codespartan.cloud

---

## 📚 Paso 5: Configurar Storybook (ui.codespartan.cloud)

### Opción A: Storybook nuevo desde cero

```bash
cd /ruta/a/iac-code-spartan/codespartan/apps/codespartan-cloud/ui/

# Inicializar proyecto React básico (si no tienes uno)
npx create-react-app . --template typescript

# Inicializar Storybook
npx storybook@latest init

# Esto genera:
# - .storybook/main.ts
# - .storybook/preview.ts
# - src/stories/ (ejemplos)

# Verificar scripts en package.json:
# "storybook": "storybook dev -p 6006"
# "build-storybook": "storybook build"

# Test local
npm run storybook
# Abre http://localhost:6006

# Si funciona local, deploy:
git add .
git commit -m "feat: Add Storybook component catalog"
git push origin main
```

### Opción B: Integrar componentes existentes

```bash
cd /ruta/a/iac-code-spartan/codespartan/apps/codespartan-cloud/ui/

# Copiar tus componentes
mkdir -p src/components
cp -r /ruta/a/tu-proyecto/src/components/* src/components/

# Copiar package.json y instalar
cp /ruta/a/tu-proyecto/package.json .
npm install

# Inicializar Storybook
npx storybook@latest init

# Crear stories para tus componentes
# Ejemplo: src/components/Button/Button.stories.tsx
cat > src/components/Button/Button.stories.tsx << 'EOF'
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: {
    variant: 'primary',
    children: 'Click me',
  },
};
EOF

# Test local
npm run storybook

# Deploy
git add .
git commit -m "feat: Add component stories"
git push origin main
```

---

## ⚡ Despliegue Rápido (Placeholder temporal)

Si necesitas que los dominios estén **activos YA** (aunque sin tu código final):

```bash
cd /ruta/a/iac-code-spartan

# Ejecutar los workflows manualmente desde GitHub UI:
# https://github.com/TechnoSpartan/iac-code-spartan/actions

# O via CLI:
gh workflow run deploy-codespartan-www.yml
gh workflow run deploy-codespartan-ui.yml
```

Esto desplegará páginas placeholder básicas que puedes actualizar después.

---

## 🔍 Verificación Post-Despliegue

### Verificar que todo funciona

```bash
# Check DNS
dig www.codespartan.cloud  # Debe retornar 91.98.137.217
dig ui.codespartan.cloud   # Debe retornar 91.98.137.217

# Check HTTP
curl -I https://www.codespartan.cloud  # Debe retornar HTTP 200
curl -I https://ui.codespartan.cloud   # Debe retornar HTTP 200

# Ver logs en el VPS
ssh leonidas@91.98.137.217
docker logs codespartan-www -f
docker logs codespartan-ui -f

# Ver estado de containers
docker ps | grep codespartan
```

### Acceder a las aplicaciones

- **WWW**: https://www.codespartan.cloud
- **UI**: https://ui.codespartan.cloud
- **Health checks**:
  - https://www.codespartan.cloud/health
  - https://ui.codespartan.cloud/health

---

## 🛠️ Troubleshooting

### Build falla con "Cannot find module"

```bash
# Asegúrate de que package-lock.json está incluido
git add package-lock.json
git commit -m "fix: Add package-lock.json"
git push
```

### Build tarda mucho

Es normal en el primer build (15-20 min). Builds subsecuentes usan cache y tardan 2-3 min.

### SSL "Certificate not trusted"

Espera 2-3 minutos después del primer despliegue. Let's Encrypt tarda en emitir el certificado.

### "Health check failed"

```bash
# SSH al VPS y check logs
ssh leonidas@91.98.137.217
docker logs codespartan-www --tail 50

# Common issues:
# 1. Puerto incorrecto en Dockerfile (debe ser 80)
# 2. Nginx config incorrecto
# 3. Build output en directorio incorrecto
```

### Página muestra 404 en rutas

Si es SPA (React Router, Vue Router), asegúrate de que nginx.conf tiene:

```nginx
location / {
    try_files $uri $uri/ /index.html;  # SPA fallback
}
```

---

## 📊 Monitoreo

### Logs en tiempo real

```bash
# SSH al VPS
ssh leonidas@91.98.137.217

# Ver logs de www
docker logs codespartan-www -f

# Ver logs de ui
docker logs codespartan-ui -f

# Ver todos los containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Métricas

- **Grafana**: https://grafana.mambo-cloud.com
  - Usuario: admin / codespartan123
  - Dashboards de CPU, RAM, Network

- **Traefik**: https://traefik.mambo-cloud.com
  - Usuario: admin / codespartan123
  - Ver requests, status codes, latency

---

## 🔄 Workflow de Desarrollo

### Para cambios en tu código

```bash
# 1. Hacer cambios en tu código
vim src/App.tsx

# 2. (Opcional) Test local
npm run dev

# 3. Commit y push
git add .
git commit -m "feat: nueva funcionalidad"
git push

# 4. GitHub Actions despliega automáticamente
# Monitorear en: https://github.com/TechnoSpartan/iac-code-spartan/actions
```

**Tiempo total**: 5-10 minutos desde push hasta producción

---

## 🚨 Rollback

Si un deploy falla o tiene bugs:

```bash
# Opción 1: Revert commit
git revert HEAD
git push

# Opción 2: Deploy versión anterior manualmente
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/codespartan-cloud/www

# Ver imágenes disponibles
docker images | grep codespartan-www

# Editar docker-compose.yml para usar tag anterior
vim docker-compose.yml
# Cambiar: ghcr.io/technospartan/codespartan-www:main-abc123

docker compose down
docker compose up -d
```

---

## 📞 Soporte

### Información del sistema

```bash
# Ver versión de imagen desplegada
docker inspect codespartan-www | grep -i image

# Ver variables de entorno
docker inspect codespartan-www | grep -A 20 Env

# Ver recursos consumidos
docker stats codespartan-www codespartan-ui
```

### Recursos del VPS

- **CPU**: 2 cores ARM64
- **RAM**: 4GB (tus apps usan ~512MB total)
- **Disco**: 40GB
- **Red**: Gigabit

### Contacto

- **VPS IP**: 91.98.137.217
- **SSH User**: leonidas
- **GitHub**: https://github.com/TechnoSpartan/iac-code-spartan

---

## ✅ Checklist Final

Antes de entregar al cliente, verifica:

- [ ] DNS resuelve correctamente
- [ ] HTTPS funciona (certificado válido)
- [ ] www.codespartan.cloud carga tu aplicación
- [ ] ui.codespartan.cloud carga Storybook
- [ ] Health checks retornan 200
- [ ] Logs no muestran errores
- [ ] Monitoreo en Grafana funciona
- [ ] Cliente tiene acceso al repo
- [ ] Cliente sabe cómo hacer cambios (git push)

---

## 🎓 Próximos Pasos (Opcional)

### Variables de entorno

```yaml
# docker-compose.yml
services:
  web:
    environment:
      - API_URL=${API_URL}
      - NODE_ENV=production
```

### Backend API

Si necesitas backend:
```bash
mkdir -p codespartan/apps/codespartan-cloud/api
# Copiar tu API aquí
# Crear Dockerfile
# Deploy similar a www
```

### Base de datos

```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - db_data:/var/lib/postgresql/data
```

### CI/CD avanzado

- Tests automáticos
- Staging environment
- Blue/green deployments
- Canary releases

---

**🎉 ¡Listo para entregar al cliente!**
