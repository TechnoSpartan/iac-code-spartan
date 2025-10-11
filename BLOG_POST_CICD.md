# CI/CD Profesional: De Deploy Manual a Automatización Completa en 24 Horas

**Autor:** Jorge Carballo - CodeSpartan
**Fecha:** 10 Octubre 2025
**Tiempo de lectura:** 10-12 minutos
**Nivel:** Intermedio-Avanzado

---

## TL;DR (Resumen Ejecutivo)

He construido un pipeline CI/CD profesional que incluye:
- ✅ Deploy automatizado en 2 minutos
- ✅ Rollback automático si algo falla
- ✅ Health checks y verificación
- ✅ Métricas en tiempo real vía Discord
- ✅ Multi-environment (prod, staging, lab)
- ✅ Zero downtime en producción

**Stack:** GitHub Actions, Docker, Traefik, Terraform, VictoriaMetrics + Grafana
**Resultado:** 100% tasa de éxito, de 30min manuales a 2min automatizados
**Proyecto real:** [cyberdyne-systems.es](https://www.cyberdyne-systems.es)

---

## El Problema: Deploy Manual en 2025

Seamos honestos. Si todavía estás haciendo deploys manuales, cada viernes a las 18h te da un poco de ansiedad.

**El proceso típico:**
1. Hacer merge a main
2. SSH al servidor
3. `git pull`
4. `docker compose build` (rezar que compile)
5. `docker compose up -d` (rezar que levante)
6. Probar manualmente en el navegador
7. Si algo falla → pánico, revertir a mano
8. Cruzar los dedos

**Tiempo total:** 30-40 minutos
**Probabilidad de que algo falle:** Más alta de lo que admites
**Estrés generado:** Innecesario

He estado ahí. Y decidí que 2025 era el año de automatizar TODO.

---

## La Visión: Cómo Debería Ser

Imagina esto:

```bash
git push origin master
```

Y automáticamente:
1. Se corren tests y quality checks
2. Se construye la imagen Docker optimizada
3. Se despliega en producción
4. Se verifican health checks
5. Si algo falla → rollback automático
6. Te llega una notificación con métricas en Discord

**Todo en 2 minutos. Sin intervención manual.**

Eso es exactamente lo que construí.

---

## La Arquitectura: Componentes Clave

### 1. GitHub Actions (El Cerebro)

El workflow se divide en 5 jobs secuenciales:

```yaml
jobs:
  notify-start   # Notificación Discord de inicio
  quality        # Lint, type-check, build
  build-image    # Docker build con métricas
  deploy         # Deploy con rollback automático
  post-deploy    # Verificación y métricas finales
  notify         # Notificación de resultado
```

Cada job tiene una responsabilidad clara. Si uno falla, los siguientes no se ejecutan.

### 2. Docker Multi-Stage (El Músculo)

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --no-frozen-lockfile
COPY . .
RUN pnpm run build

# Stage 2: Production
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# Custom nginx config para SPA routing
RUN echo 'server { ... }' > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**¿Por qué multi-stage?**
- Imagen final: 45MB (vs 300MB+ sin optimizar)
- Solo incluye lo necesario para producción
- Build reproducible

### 3. Traefik (El Proxy Inteligente)

Maneja:
- Routing por dominio/subdominio
- SSL automático con Let's Encrypt
- Load balancing si escalo
- Health checks

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.cyberdyne-www.rule=Host(`www.cyberdyne-systems.es`)
  - traefik.http.routers.cyberdyne-www.entrypoints=websecure
  - traefik.http.routers.cyberdyne-www.tls.certresolver=le
```

### 4. Terraform (La Infraestructura)

Todo como código:

```hcl
# DNS
domains = ["mambo-cloud.com", "cyberdyne-systems.es"]
subdomains = ["traefik", "grafana", "www", "staging", "lab", "api"]

# VPS
server_type = "cax11"  # ARM64
location = "nbg1"      # Nuremberg
```

Si mañana necesito replicar esto en otro dominio, son 5 minutos.

---

## El Workflow: Paso a Paso

### Job 1: Quality Checks

```yaml
quality:
  steps:
    - name: Install dependencies
      run: pnpm install --frozen-lockfile

    - name: Run linter
      run: pnpm run lint

    - name: Type check
      run: pnpm exec tsc --noEmit

    - name: Build application
      run: |
        START_TIME=$(date +%s)
        pnpm run build
        END_TIME=$(date +%s)
        echo "Build time: $((END_TIME - START_TIME))s"
```

**Captura métricas:**
- Tamaño del bundle
- Tiempo de build
- Errores de TypeScript

Si falla aquí, no sigue. El código malo no llega a producción.

### Job 2: Docker Build

```yaml
build-image:
  steps:
    - name: Build Docker image
      run: |
        docker buildx build \
          --tag cyberdyne-frontend:${SHORT_SHA} \
          --output type=docker,dest=/tmp/image.tar \
          .

    - name: Upload as artifact
      uses: actions/upload-artifact@v4
      with:
        name: docker-image
        path: /tmp/image.tar
```

**Por qué usar artifacts:**
- El job de deploy corre en otro runner
- Necesitamos pasar la imagen construida
- Más rápido que rebuild en el VPS

### Job 3: Deploy (La Magia)

Aquí es donde ocurre todo:

```bash
# 1. Backup de la imagen actual
BACKUP_IMAGE=$(docker inspect cyberdyne-frontend --format='{{.Image}}')

# 2. Cargar nueva imagen
docker load -i /tmp/image.tar

# 3. Deploy
docker compose up -d --force-recreate

# 4. Health checks (10 intentos, 3s cada uno)
for i in {1..10}; do
  if docker exec cyberdyne-frontend wget -q --spider http://localhost; then
    echo "✅ Health check passed"
    exit 0
  fi
  sleep 3
done

# 5. Si llegamos aquí, falló → ROLLBACK
echo "❌ Health check failed"
docker tag $BACKUP_IMAGE cyberdyne-frontend:rollback
docker compose up -d --force-recreate
echo "↩️ Rollback completed"
exit 1
```

**Esto es CRÍTICO:**
- Si el nuevo deploy no responde en 30 segundos → rollback automático
- El usuario nunca ve un sitio caído
- La versión anterior vuelve a estar activa

### Job 4: Post-Deploy Verification

```bash
# Check HTTP 200
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://www.cyberdyne-systems.es)

# Medir response time
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' https://www.cyberdyne-systems.es)

# Verificar todos los endpoints
DOMAINS=(
  "https://www.cyberdyne-systems.es"
  "https://staging.cyberdyne-systems.es"
  "https://lab.cyberdyne-systems.es"
)
```

Si algo falla aquí, sabes inmediatamente qué endpoint tiene problemas.

### Job 5: Notificaciones Discord

```yaml
- name: Discord notification - Success
  uses: sarisia/actions-status-discord@v1
  with:
    webhook: ${{ secrets.DISCORD_WEBHOOK_URL }}
    title: "✅ Deployment Successful"
    description: |
      **Métricas:**
      • Build Size: ${{ needs.quality.outputs.build-size }}
      • Build Time: ${{ needs.quality.outputs.build-time }}
      • Deploy Time: ${{ needs.deploy.outputs.deploy-time }}s
      • Response Time: ${{ needs.post-deploy.outputs.response-time }}

      **Production:** https://www.cyberdyne-systems.es
```

**Tipos de notificaciones:**
- 🚀 Deployment Started (azul)
- ✅ Deployment Successful (verde) con métricas
- ❌ Deployment Failed (rojo)
- ⚠️ Rolled Back (naranja)

---

## Los Números: Métricas Reales

Después de 15+ deploys en producción:

| Métrica | Antes (Manual) | Ahora (Automatizado) | Mejora |
|---------|----------------|----------------------|--------|
| **Tiempo de deploy** | 30-40 min | 2 min | **93% más rápido** |
| **Tasa de éxito** | ~85% | 100% | **15% mejora** |
| **Tiempo de rollback** | 15-20 min | < 30 seg | **97% más rápido** |
| **Downtime** | 2-5 min | 0 min | **100% mejora** |
| **Estrés generado** | Alto | Cero | **Impagable** |

**Ahorro de tiempo:**
- 30 min → 2 min = 28 min ahorrados por deploy
- 1 deploy/día promedio = 140 min/semana = **2.3 horas/semana**
- 10 horas/mes ahorradas

**ROI:**
Si tu hora vale 50€ (freelance junior), ahorras 500€/mes en tiempo.
La inversión inicial: ~8 horas de setup = 400€.

**Payback:** < 1 mes.

---

## Lecciones Aprendidas

### 1. El Rollback Automático es NO-NEGOCIABLE

La primera vez que vi un deploy fallar y revertirse solo, supe que esto era oro.

**Sin rollback automático:**
- Detectas el problema (2-5 min)
- Entras al servidor (1 min)
- Reviertes manualmente (5-10 min)
- Verificas (2 min)
- **Total: 10-18 minutos de downtime**

**Con rollback automático:**
- Health check falla (30 seg)
- Sistema revierte automáticamente (10 seg)
- **Total: < 1 minuto de downtime**

### 2. Las Métricas Importan

Saber que tu build pesa 1.2MB vs 1.8MB importa.
Saber que el deploy tardó 25s vs 45s importa.
Saber que el response time es 250ms vs 500ms importa.

**¿Por qué?**
- Detectas regresiones inmediatamente
- Puedes optimizar con datos, no intuición
- Demuestras profesionalidad a clientes

### 3. Discord > Email para Notificaciones

Email:
- Lo ves 30 minutos después
- Se pierde entre spam
- No es visual

Discord:
- Notificación push instantánea
- Visual (colores según estado)
- Historial completo de deploys
- Puedes compartir canal con el equipo

### 4. Multi-Environment desde el Día 1

Tener `staging.cyberdyne-systems.es` y `lab.cyberdyne-systems.es` desde el inicio ha salvado mi trasero múltiples veces.

**Workflow ideal:**
1. Desarrollo en local
2. Push a branch `develop` → deploy automático a staging
3. Testing en staging
4. Merge a `master` → deploy automático a producción

### 5. Infrastructure as Code > ClickOps

Terraform puede parecer overkill al inicio, pero:
- Documentación automática de tu infra
- Replicable en minutos
- Versionado en Git
- No hay "ah, ¿qué hice en la consola?"

---

## Cómo Replicar Esto en Tu Proyecto

### Paso 1: Dockeriza Tu App (1-2 horas)

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Paso 2: Setup Básico de GitHub Actions (30 min)

```yaml
name: CI/CD

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          docker build -t myapp .
```

### Paso 3: Añade Deploy (1 hora)

```yaml
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        run: |
          ssh user@server 'cd /app && docker compose up -d'
```

### Paso 4: Health Checks (30 min)

```yaml
  verify:
    needs: deploy
    runs-on: ubuntu-latest
    steps:
      - name: Check health
        run: |
          curl -f https://myapp.com/health || exit 1
```

### Paso 5: Rollback (1 hora)

```yaml
  deploy:
    steps:
      - name: Backup & Deploy
        run: |
          BACKUP=$(docker inspect app --format='{{.Image}}')
          docker compose up -d

          # Health check
          sleep 10
          if ! curl -f http://localhost/health; then
            docker tag $BACKUP app:rollback
            docker compose up -d
            exit 1
          fi
```

### Paso 6: Notificaciones (15 min)

Añade Discord webhook y:

```yaml
  notify:
    if: always()
    steps:
      - uses: sarisia/actions-status-discord@v1
        with:
          webhook: ${{ secrets.DISCORD_WEBHOOK }}
```

**Total:** 4-5 horas de setup inicial.
**Ahorro:** 10+ horas/mes para siempre.

---

## Stack Completo y Alternativas

### Lo Que Yo Usé

| Componente | Tecnología | Por Qué |
|------------|------------|---------|
| CI/CD | GitHub Actions | Gratis, integrado con GitHub |
| Containers | Docker | Estándar de facto |
| Reverse Proxy | Traefik | SSL automático, easy config |
| IaC | Terraform | Multi-cloud, gran comunidad |
| Monitoring | VictoriaMetrics + Grafana | Open source, potente |
| Notificaciones | Discord | Instantáneo, visual |
| VPS | Hetzner Cloud ARM64 | Barato, buen rendimiento |

### Alternativas Válidas

**CI/CD:**
- GitLab CI (si usas GitLab)
- CircleCI (buen free tier)
- Jenkins (self-hosted, más control)

**Containers:**
- Podman (sin daemon, más seguro)
- Pero seamos realistas, Docker es el estándar

**Reverse Proxy:**
- Nginx (más control, más config manual)
- Caddy (aún más simple que Traefik)
- HAProxy (enterprise-grade)

**IaC:**
- Pulumi (si prefieres TypeScript/Python)
- CloudFormation (si estás AWS-only)
- Ansible (más imperativo)

**Hosting:**
- DigitalOcean (más caro, mejor UX)
- AWS EC2 (potente, complejo)
- Fly.io (serverless, muy rápido)

---

## Casos de Uso: ¿Cuándo Vale la Pena?

### ✅ Deberías Implementar Esto Si:

1. **Haces 3+ deploys a la semana**
   ROI inmediato

2. **Tienes clientes/usuarios reales**
   Downtime = dinero perdido

3. **Trabajas en equipo**
   Necesitas proceso consistente

4. **Ofreces servicios profesionales**
   Es tu carta de presentación

5. **Quieres dormir tranquilo**
   Literal

### ❌ Quizás No Lo Necesitas Si:

1. **Es un side project personal**
   Aunque sigue siendo buena práctica

2. **Deployeas una vez al mes**
   El ROI tarda más

3. **Tienes < 10 usuarios**
   Pero te prepara para escalar

---

## El Factor Humano: Soft Skills

Montar esto me enseñó algo más allá de la técnica:

### Comunicación

Explicar a un cliente:
> "Tenemos rollback automático. Si algo falla, el sistema vuelve a la versión anterior en segundos."

Es mucho más profesional que:
> "Si algo falla, lo arreglo rápido, tranqui."

### Confianza

Cuando un cliente ve notificaciones de Discord en tiempo real con métricas, confía más en ti.

No es solo "funciona". Es "tengo visibilidad completa del proceso".

### Diferenciación

Como freelance, esto me separa del 80% de la competencia.

La mayoría puede hacer una web React. Pocos pueden montar un pipeline CI/CD profesional.

**Eso se cobra más caro.**

---

## Próximos Pasos: Llevándolo al Siguiente Nivel

Esto es solo el inicio. Aquí está mi roadmap de mejoras:

### Fase 2: Testing (Próximas 2 semanas)

```yaml
quality:
  steps:
    - name: Unit tests
      run: npm test -- --coverage

    - name: E2E tests
      run: npx playwright test

    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

**Meta:** 70% coverage mínimo

### Fase 3: Performance Budgets (Próximo mes)

```yaml
  - name: Lighthouse CI
    run: |
      npm install -g @lhci/cli
      lhci autorun
```

**Meta:**
- Performance score > 90
- First Contentful Paint < 1.5s
- Time to Interactive < 3s

### Fase 4: Security Scanning

```yaml
  - name: Trivy scan
    run: |
      trivy image myapp:latest \
        --severity HIGH,CRITICAL \
        --exit-code 1
```

**Meta:** Zero vulnerabilidades críticas en producción

### Fase 5: Multi-Region Deploy

```yaml
deploy:
  strategy:
    matrix:
      region: [eu-west, us-east, ap-south]
```

**Meta:** < 100ms latency global

---

## Recursos y Referencias

### Documentación Oficial
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Terraform Docs](https://developer.hashicorp.com/terraform/docs)

### Artículos Relacionados
- Martin Fowler - Continuous Integration
- The Twelve-Factor App
- GitOps Principles

### Tools Mencionadas
- [GitHub Actions](https://github.com/features/actions)
- [Docker](https://www.docker.com/)
- [Traefik](https://traefik.io/)
- [Terraform](https://www.terraform.io/)
- [VictoriaMetrics](https://victoriametrics.com/)
- [Grafana](https://grafana.com/)

---

## Código Fuente

¿Quieres ver el código completo?

**Workflow completo:** Disponible en GitHub (próximamente template público)

**Feedback bienvenido:**
Si implementas algo similar, me encantaría saber:
- ¿Qué funcionó?
- ¿Qué tuviste que adaptar?
- ¿Qué mejorarías?

Déjame un comentario o contáctame directamente.

---

## Conclusión: Vale Cada Minuto Invertido

Montar este pipeline me tomó aproximadamente 8 horas de trabajo concentrado.

**¿Vale la pena?**

Absolutamente.

No solo por el ahorro de tiempo (10h/mes), sino por:

1. **Profesionalidad** - Puedo vender esto como servicio
2. **Tranquilidad** - Deploy sin estrés
3. **Aprendizaje** - He dominado Docker, GitHub Actions, IaC
4. **Portfolio** - Esto me diferencia como freelance
5. **Escalabilidad** - Puedo replicarlo en otros proyectos en 1 hora

Si eres desarrollador freelance, tech lead, o simplemente alguien que quiere mejorar su workflow, esto debería estar en tu toolkit.

**No es solo código. Es profesionalismo.**

---

## Sobre CodeSpartan

En [CodeSpartan](https://www.codespartan.es) ofrecemos soluciones cloud profesionales:

- 🚀 CI/CD Pipelines
- ☁️ Arquitecturas Cloud (AWS, GCP, Azure)
- 🤖 Integración de IA/ML
- 🔧 DevOps & Automation
- 📊 Monitoring & Observability

**¿Tu proyecto necesita este nivel de profesionalidad?**

[Hablemos →](https://www.codespartan.es/contacto)

---

## Call to Action

**¿Te ha sido útil este artículo?**

1. Compártelo en LinkedIn/Twitter
2. Déjame un comentario con tu experiencia
3. Si implementas algo similar, cuéntame qué tal fue

**¿Quieres ayuda implementando esto?**

Ofrezco consultorías de 1-2 horas para:
- Revisar tu setup actual
- Diseñar tu pipeline CI/CD
- Implementar mejoras específicas

[Reserva una sesión →](https://www.codespartan.es/consultoria)

---

**Tags:** #DevOps #CICD #Docker #GitHub Actions #Terraform #React #Automation #Cloud #FreelanceDev

**Última actualización:** 10 Octubre 2025

---

_¿Preguntas? ¿Feedback? Contáctame en [jorge@codespartan.es](mailto:jorge@codespartan.es)_
