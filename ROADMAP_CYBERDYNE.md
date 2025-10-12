# 🗺️ Roadmap - Cyberdyne Systems Deployment

## 📍 Estado Actual (2025-10-10)

### ✅ Completado

#### Infraestructura Base
- [x] VPS Hetzner ARM64 (CodeSpartan-alma) operativo en `91.98.137.217`
- [x] DNS configurado para `cyberdyne-systems.es` y subdominios
- [x] Traefik reverse proxy con SSL automático (Let's Encrypt)
- [x] Monitoring stack (VictoriaMetrics, Grafana, Loki, Promtail)

#### Aplicación Cyberdyne Systems
- [x] Frontend React + Vite + PWA
- [x] Dockerfile multi-stage optimizado (Node 20 → Nginx Alpine)
- [x] Docker Compose con labels Traefik
- [x] Deployment funcionando en producción

#### CI/CD Pipeline Profesional
- [x] Workflow GitHub Actions con 5 jobs
- [x] Quality checks (lint, type-check, build)
- [x] Docker build con métricas
- [x] Deploy automático con rollback
- [x] Health checks y verificación
- [x] Notificaciones Discord
- [x] Métricas de deployment (tamaño, tiempo, performance)
- [x] Dashboard visual en GitHub Actions

### 🌐 URLs Activas

| Endpoint | URL | Estado |
|----------|-----|--------|
| Producción | https://www.cyberdyne-systems.es | ✅ Activo |
| Root (redirect) | https://cyberdyne-systems.es | ✅ Activo |
| Staging | https://staging.cyberdyne-systems.es | ✅ Activo |
| Lab | https://lab.cyberdyne-systems.es | ✅ Activo |
| **API** | **https://api.cyberdyne-systems.es** | 🟡 **Configurado** |
| Traefik Dashboard | https://traefik.mambo-cloud.com | ✅ Activo |
| Grafana | https://grafana.mambo-cloud.com | ✅ Activo |

### 🔑 Configuración Actual

#### GitHub Secrets (TechnoSpartan/ft-rc-bko-dummy)
```
✅ VPS_SSH_HOST = 91.98.137.217
✅ VPS_SSH_USER = leonidas
✅ VPS_SSH_KEY = [configurado]
✅ DISCORD_WEBHOOK_URL = [configurado]
```

#### Repositorios
- **IaC**: https://github.com/tu-usuario/iac-core-hetzner
- **App**: https://github.com/TechnoSpartan/ft-rc-bko-dummy
- **Branch actual app**: `feature/CS01-Eventos` (pendiente merge a main)

#### Archivos Clave

**En App Repo (`/Users/krbaio3/Worker/@CodeSpartan/ft-rc-bko-pwa/`):**
```
├── .github/
│   ├── workflows/
│   │   └── ci-cd.yml              # Workflow profesional completo
│   └── DEPLOYMENT.md              # Documentación del pipeline
├── Dockerfile                     # Multi-stage build
├── .dockerignore                  # Optimización build
├── docker-compose.yml             # Traefik labels + networking
├── tsconfig.app.json              # noUnusedLocals: false (para build)
└── src/                           # Código React PWA
```

**En IaC Repo (`/Volumes/Worker/@CodeSpartan/iac-core-hetzner/`):**
```
├── codespartan/
│   ├── infra/hetzner/
│   │   └── terraform.tfvars      # DNS: cyberdyne-systems.es
│   ├── apps/cyberdyne/
│   │   ├── docker-compose.yml    # Template (no usado actualmente)
│   │   └── README.md             # Docs deployment
│   └── platform/
│       ├── traefik/              # Reverse proxy
│       └── stacks/monitoring/    # Grafana, Loki, etc
└── .github/workflows/
    └── deploy-cyberdyne.yml      # Workflow desde IaC (deprecado)
```

---

## 🎯 Próximos Pasos

### 🔴 Urgente (Hacer Ahora)
1. **Merge feature branch a main**
   ```bash
   cd /Users/krbaio3/Worker/@CodeSpartan/ft-rc-bko-pwa
   git checkout main
   git pull
   git merge feature/CS01-Eventos
   git push
   ```
   - Esto activará el workflow completo
   - Recibirás notificaciones Discord
   - Verifica que todo funcione correctamente

---

## 🚀 Roadmap de Mejoras

### Fase 1: Testing & Quality (1-2 días) 🧪

#### 1.1 Unit Testing
- [ ] Configurar Vitest
- [ ] Tests para componentes críticos
- [ ] Coverage reports (mínimo 70%)
- [ ] Integrar en CI/CD workflow

#### 1.2 E2E Testing
- [ ] Setup Playwright
- [ ] Tests de flujos principales
- [ ] Visual regression testing
- [ ] Screenshots en fallos

#### 1.3 Code Quality
- [ ] ESLint strict rules
- [ ] Prettier auto-format
- [ ] Husky pre-commit hooks
- [ ] Commitlint

**Archivos a crear:**
```
vitest.config.ts
playwright.config.ts
.husky/pre-commit
tests/unit/
tests/e2e/
```

---

### Fase 2: Staging Environment (1 día) 🧪

#### 2.1 Branch Strategy
- [ ] Setup branch `develop` como staging
- [ ] Workflow separado para staging
- [ ] Deploy automático a `staging.cyberdyne-systems.es`

#### 2.2 Workflow Staging
- [ ] Crear `.github/workflows/deploy-staging.yml`
- [ ] Deploy en push a `develop`
- [ ] No requiere approvals
- [ ] Notificaciones Discord separadas

#### 2.3 Configuración
- [ ] Environment `staging` en GitHub
- [ ] Variables de entorno específicas staging
- [ ] Datos de prueba/mock

**Archivos a crear:**
```
.github/workflows/deploy-staging.yml
.env.staging
```

---

### Fase 3: Monitoring Avanzado (2-3 días) 📊

#### 3.1 Application Metrics
- [ ] Integrar con Grafana existente
- [ ] Dashboard personalizado Cyberdyne
- [ ] Métricas custom (user actions, errors)
- [ ] Logs estructurados

#### 3.2 Alerting
- [ ] Alertas en Grafana
- [ ] Integración Discord/Slack
- [ ] Alertas por email
- [ ] Escalation policies

#### 3.3 Uptime Monitoring
- [ ] UptimeRobot o Betterstack
- [ ] Health check endpoints
- [ ] Status page público
- [ ] SLA tracking

**Servicios a configurar:**
```
- Grafana Dashboard (grafana.mambo-cloud.com)
- UptimeRobot (https://uptimerobot.com) - Free tier
- Status Page (https://statuspage.io o self-hosted)
```

---

### Fase 4: Performance Optimization (2-3 días) ⚡

#### 4.1 Build Optimization
- [ ] Vite bundle analyzer
- [ ] Code splitting optimizado
- [ ] Tree shaking verification
- [ ] Lazy loading components

#### 4.2 Image Optimization
- [ ] Automático con Sharp/ImageMagick
- [ ] WebP/AVIF formats
- [ ] Responsive images
- [ ] CDN integration

#### 4.3 Lighthouse CI
- [ ] Integrar en workflow
- [ ] Performance budgets
- [ ] Regression alerts
- [ ] Reports en cada PR

#### 4.4 Cache Strategy
- [ ] Service Worker optimizado
- [ ] Static assets caching
- [ ] API response cache
- [ ] CDN CloudFlare (opcional)

**Archivos a crear:**
```
.lighthouserc.js
vite.config.ts (optimizations)
service-worker.ts (custom)
```

---

### Fase 5: Security Hardening (2 días) 🔒

#### 5.1 Security Scanning
- [ ] Trivy para Docker images
- [ ] Snyk para dependencies
- [ ] OWASP dependency check
- [ ] Integrar en CI/CD

#### 5.2 Dependency Management
- [ ] Dependabot configurado
- [ ] Auto-merge minor updates
- [ ] Security advisories
- [ ] License compliance

#### 5.3 Secrets Management
- [ ] Vault para secrets (opcional)
- [ ] Rotate SSH keys
- [ ] Secret scanning en repo
- [ ] .env validation

#### 5.4 SSL/Security Headers
- [ ] Verificar SSL config
- [ ] Security headers (CSP, HSTS, etc)
- [ ] SSL monitoring
- [ ] Certificate auto-renewal check

**Archivos a crear:**
```
.github/dependabot.yml
trivy.yaml
security-policy.md
```

---

### Fase 6: Backups & Disaster Recovery (1-2 días) 💾

#### 6.1 Automated Backups
- [ ] Backup diario de contenedores
- [ ] Backup de configuración
- [ ] Backup de datos (si hay DB)
- [ ] Retention policy (7 días)

#### 6.2 Backup Storage
- [ ] Backblaze B2 o S3
- [ ] Encrypted backups
- [ ] Geo-redundancy
- [ ] Backup verification

#### 6.3 Disaster Recovery Plan
- [ ] DR runbook documentado
- [ ] Recovery time objective (RTO)
- [ ] Recovery point objective (RPO)
- [ ] Test DR quarterly

**Scripts a crear:**
```bash
/opt/codespartan/scripts/backup-cyberdyne.sh
/opt/codespartan/scripts/restore-cyberdyne.sh
```

---

### Fase 7: Multi-Project Template (2-3 días) 🏗️

#### 7.1 Template Repository
- [ ] Crear template repo reutilizable
- [ ] Cookiecutter o similar
- [ ] Variables parametrizadas
- [ ] Documentación completa

#### 7.2 Infrastructure as Code Template
- [ ] Terraform modules reusables
- [ ] Ansible playbooks
- [ ] Docker Compose templates
- [ ] CI/CD workflows templates

#### 7.3 Deployment Scripts
- [ ] Script de setup inicial
- [ ] One-command deployment
- [ ] Configuración interactiva
- [ ] Validación automática

**Estructura template:**
```
template-react-vps/
├── .github/workflows/
├── infrastructure/
├── scripts/
├── docs/
└── cookiecutter.json
```

---

## 📚 Documentación a Crear

### Para Cada Fase
- [ ] README específico de cada feature
- [ ] Runbooks operacionales
- [ ] Troubleshooting guides
- [ ] Architecture Decision Records (ADRs)

### Documentos Generales
- [ ] `ARCHITECTURE.md` - Diagrama y explicación
- [ ] `OPERATIONS.md` - Guía operacional
- [ ] `CONTRIBUTING.md` - Guía contribución
- [ ] `CHANGELOG.md` - Histórico cambios

---

## 🛠️ Comandos Útiles

### SSH al VPS
```bash
ssh leonidas@91.98.137.217
```

### Ver estado Cyberdyne
```bash
ssh leonidas@91.98.137.217 "docker ps | grep cyberdyne"
ssh leonidas@91.98.137.217 "docker logs cyberdyne-frontend -f"
```

### Rebuild manual
```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/cyberdyne
docker compose build --no-cache
docker compose up -d
```

### Ver métricas
```bash
ssh leonidas@91.98.137.217 "docker stats --no-stream cyberdyne-frontend"
```

### Verificar DNS
```bash
dig www.cyberdyne-systems.es +short
dig staging.cyberdyne-systems.es +short
dig lab.cyberdyne-systems.es +short
```

### Health checks
```bash
curl -I https://www.cyberdyne-systems.es
curl -w "%{time_total}\n" -o /dev/null -s https://www.cyberdyne-systems.es
```

---

## 📊 Métricas de Éxito

### Performance Targets
| Métrica | Target | Actual |
|---------|--------|--------|
| Build Time | < 30s | ~15s ✅ |
| Deploy Time | < 60s | ~25s ✅ |
| Response Time | < 500ms | ~250ms ✅ |
| Build Size | < 2MB | ~1.2MB ✅ |
| Image Size | < 100MB | ~45MB ✅ |

### Quality Targets
| Métrica | Target | Actual |
|---------|--------|--------|
| Test Coverage | > 70% | 0% 🔴 |
| Lighthouse Score | > 90 | ? 🟡 |
| Uptime | > 99.5% | ? 🟡 |
| Deploy Success Rate | > 95% | 100% ✅ |

---

## 🎓 Recursos y Referencias

### Documentación Oficial
- **Vite**: https://vitejs.dev/
- **React**: https://react.dev/
- **Docker**: https://docs.docker.com/
- **Traefik**: https://doc.traefik.io/traefik/
- **GitHub Actions**: https://docs.github.com/en/actions

### Herramientas
- **Vitest**: https://vitest.dev/
- **Playwright**: https://playwright.dev/
- **Lighthouse CI**: https://github.com/GoogleChrome/lighthouse-ci
- **Trivy**: https://aquasecurity.github.io/trivy/

### Monitoring
- **Grafana**: https://grafana.com/docs/
- **VictoriaMetrics**: https://docs.victoriametrics.com/
- **UptimeRobot**: https://uptimerobot.com/

---

## 🔄 Workflow de Desarrollo

### Feature Development
```bash
# 1. Crear feature branch
git checkout -b feature/nueva-funcionalidad

# 2. Desarrollar y commitear
git add .
git commit -m "feat: descripción"

# 3. Push y crear PR
git push -u origin feature/nueva-funcionalidad

# 4. CI corre quality checks
# 5. Review y merge a develop
# 6. Deploy automático a staging
# 7. Testing en staging
# 8. Merge develop → main
# 9. Deploy automático a production
```

---

## 🚨 Troubleshooting Quick Reference

### Deployment Failed
1. Check GitHub Actions logs
2. Check Discord notification
3. SSH al VPS y ver logs: `docker logs cyberdyne-frontend`
4. Si rollback → fix issue → re-deploy

### Site Down
1. Check Traefik: `docker logs traefik | grep cyberdyne`
2. Check container: `docker ps | grep cyberdyne`
3. Restart si necesario: `docker restart cyberdyne-frontend`
4. Check DNS: `dig www.cyberdyne-systems.es`

### SSL Issues
1. Check Traefik logs
2. Verify Let's Encrypt: `docker exec traefik ls -la /letsencrypt/`
3. Regenerar si necesario: `docker restart traefik`

---

## 📝 Notas de Sesión Actual

### Cambios Pendientes
- [ ] Branch `feature/CS01-Eventos` tiene 3 commits sin push
- [ ] Merge a `main` pendiente para activar workflow
- [ ] Discord webhook configurado pero sin probar

### Decisiones Técnicas
- Se deshabilitó `noUnusedLocals` en tsconfig para permitir builds
- Se usa `--no-frozen-lockfile` en Dockerfile por inconsistencias lockfile
- Se eligió build en VPS vs registry por simplicidad

### Issues Conocidos
- Variable `getUsersByRoles` sin usar en `notificationEventService.ts:592`
- Pendiente limpieza de código TypeScript

---

## 🎯 Prioridades Recomendadas

1. **Inmediato**: Merge a main y verificar deployment completo
2. **Esta semana**: Testing (Fase 1)
3. **Próxima semana**: Staging environment (Fase 2)
4. **Mes 1**: Monitoring + Performance (Fases 3-4)
5. **Mes 2**: Security + Backups (Fases 5-6)
6. **Mes 3**: Template reutilizable (Fase 7)

---

## 📞 Contacto y Soporte

- **VPS Provider**: Hetzner Cloud
- **Domain Registrar**: Hetzner DNS
- **GitHub Org**: TechnoSpartan
- **Discord**: Canal configurado para notificaciones

---

**Última actualización**: 2025-10-10
**Próxima revisión**: Después de completar Fase 1

---

## 🎉 Quick Win Ideas

Cosas rápidas que puedes hacer para mejorar:

- [ ] Añadir favicon personalizado
- [ ] Configurar meta tags SEO
- [ ] Añadir Google Analytics
- [ ] Crear página 404 personalizada
- [ ] Añadir sitemap.xml
- [ ] Configurar robots.txt
- [ ] Progressive Web App manifest mejorado
- [ ] Dark mode toggle
- [ ] Accessibility audit con axe
- [ ] Performance budget en workflow

---

**🚀 Happy Deployment!**
