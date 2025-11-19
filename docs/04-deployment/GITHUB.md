# Guía GitHub Actions - CodeSpartan Mambo Cloud

## 🎯 Descripción General

Este proyecto utiliza GitHub Actions para automatizar completamente el despliegue de la infraestructura y aplicaciones. Cada componente tiene su propio workflow que se ejecuta automáticamente cuando hay cambios.

## 🔐 Configuración de Secrets

### Secrets Requeridos

Ve a tu repositorio → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `HCLOUD_TOKEN` | Token API Hetzner Cloud | `xxxxxxxxxxxxxxxxxxx` |
| `HETZNER_DNS_TOKEN` | Token API Hetzner DNS | `xxxxxxxxxxxxxxxxxxx` |
| `VPS_SSH_HOST` | IP del VPS | `91.98.137.217` |
| `VPS_SSH_USER` | Usuario SSH | `leonidas` |
| `VPS_SSH_KEY` | Clave privada SSH completa | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

### Generar SSH Key para GitHub Actions

```bash
# 1. Generar la clave (si no existe)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "github-actions@mambo-cloud.com"

# 2. Copiar la clave pública (va en Terraform)
cat ~/.ssh/id_ed25519.pub

# 3. Copiar la clave privada (va en VPS_SSH_KEY secret)
cat ~/.ssh/id_ed25519
```

## 🚀 Workflows Disponibles

### 1. Deploy Infrastructure (Terraform)
**Archivo**: `.github/workflows/deploy-infrastructure.yml`

**Triggers**:
- Manual (workflow_dispatch)
- Push a `codespartan/infra/hetzner/**`
- Solo en branch `main`

**Acciones**:
- ✅ Terraform init, plan, apply
- ✅ Crea VPS, DNS, firewall
- ✅ Instala Docker automáticamente

**Uso manual**:
```
GitHub → Actions → Deploy Infrastructure (Terraform) → Run workflow
Seleccionar: plan / apply / destroy
```

### 2. Deploy Traefik
**Archivo**: `.github/workflows/deploy-traefik.yml`

**Triggers**:
- Manual (workflow_dispatch)  
- Push a `codespartan/platform/traefik/**`

**Acciones**:
- ✅ Copia configuración de Traefik
- ✅ Despliega reverse proxy
- ✅ Configura SSL automático

### 3. Deploy Monitoring Stack
**Archivo**: `.github/workflows/deploy-monitoring.yml`

**Triggers**:
- Manual (workflow_dispatch)
- Push a `codespartan/platform/stacks/monitoring/**`

**Acciones**:
- ✅ Despliega VictoriaMetrics + vmagent + Grafana + Loki + Promtail + cAdvisor + Node Exporter
- ✅ Configura datasources automáticamente
- ✅ Importa dashboards predefinidos
- ✅ Retención de 7 días para métricas y logs

### 4. Deploy Backoffice
**Archivo**: `.github/workflows/deploy-backoffice.yml`

**Triggers**:
- Manual (workflow_dispatch)
- Push a `codespartan/platform/stacks/backoffice/**`

**Acciones**:
- ✅ Despliega panel de control web
- ✅ Configura autenticación básica

### 5. Deploy Mambo Cloud App
**Archivo**: `.github/workflows/deploy-mambo-cloud.yml`

**Triggers**:
- Manual (workflow_dispatch)
- Push a `codespartan/apps/mambo-cloud/**`

**Acciones**:
- ✅ Despliega aplicación principal
- ✅ Configura múltiples subdominios (www, staging, lab)

## 📋 Orden de Despliegue Recomendado

### Primer Despliegue (Desde Cero)
```
1. 🏗️  Deploy Infrastructure (Terraform)    ← Crea VPS y DNS
2. ⏳  Esperar 5-10 minutos                  ← Docker se instala
3. 🚪  Deploy Traefik                        ← Proxy reverso
4. 📊  Deploy Monitoring Stack               ← VictoriaMetrics + Grafana + Loki + Promtail
5. 🏢  Deploy Backoffice                     ← Panel de control
6. 🌐  Deploy Mambo Cloud App                ← Aplicación principal
```

### Actualizaciones Posteriores
- Solo ejecutar el workflow del componente que has modificado
- GitHub Actions detecta automáticamente los cambios por paths

## 🔄 Funcionamiento de los Workflows

### Estructura Común
Todos los workflows siguen el mismo patrón:

```yaml
1. Checkout código
2. Preparar artefactos
3. Crear directorios remotos
4. Copiar archivos via SCP
5. Ejecutar docker compose via SSH
```

### Proceso de Despliegue
```bash
# 1. Se preparan los archivos localmente
mkdir -p artifacts/componente
cp -r codespartan/path/* artifacts/componente/

# 2. Se crea la estructura en el VPS
mkdir -p /opt/codespartan/path

# 3. Se copian los archivos via SCP
scp artifacts/* root@VPS:/opt/codespartan/path/

# 4. Se despliega via SSH
docker network create web || true
cd /opt/codespartan/path
docker compose pull
docker compose up -d
```

## 🐛 Debugging de Workflows

### Ver logs detallados
1. Ve a Actions → Workflow ejecutado
2. Click en el job fallido
3. Expande la sección que falló
4. Revisa los logs línea por línea

### Errores comunes y soluciones

#### "SSH connection failed"
```yaml
# Verificar secrets:
VPS_SSH_HOST=91.98.137.217  # ✅ IP correcta
VPS_SSH_USER=root           # ✅ Usuario correcto
VPS_SSH_KEY=-----BEGIN...   # ✅ Clave privada COMPLETA
```

#### "Permission denied (publickey)"
```bash
# La clave pública debe estar en Terraform:
ssh_public_key_path = "~/.ssh/id_ed25519.pub"

# Y aplicada en el VPS:
terraform apply
```

#### "Docker command not found"
```bash
# El VPS necesita tiempo para instalar Docker
# Espera 5-10 minutos después del terraform apply
# O conéctate por SSH y verifica:
ssh root@91.98.137.217 "docker --version"
```

#### "Network web not found"
```bash
# Se crea automáticamente en cada workflow:
docker network create web || true
# El "|| true" evita error si ya existe
```

## 🔒 Seguridad de los Workflows

### Secrets Management
- ✅ Nunca hardcodear credenciales en el código
- ✅ Usar GitHub Secrets para datos sensibles
- ✅ Rotar tokens periódicamente
- ✅ Usar least-privilege principle

### SSH Security  
- ✅ Usar llaves SSH en lugar de passwords
- ✅ Restringir IPs en firewall si es posible
- ✅ Usar `script_stop: true` para fallar rápido

### Docker Security
- ✅ Usar imágenes oficiales cuando sea posible
- ✅ No ejecutar contenedores como root
- ✅ Escanear vulnerabilidades regularmente

## ⚡ Workflows Avanzados

### Rollback Automático
```yaml
# Futuro: Workflow para rollback
- name: Health Check
  run: |
    curl -f https://www.mambo-cloud.com || exit 1
    
- name: Rollback if failed  
  if: failure()
  run: |
    # Comandos para rollback
```

### Deployment con Testing
```yaml
# Futuro: Testing antes del deploy
- name: Run Tests
  run: |
    # Unit tests, integration tests, etc.
    
- name: Deploy only if tests pass
  if: success()
  # ... deployment steps
```

### Multi-Environment
```yaml
# Futuro: Deploy a diferentes entornos
- name: Deploy to Staging
  if: github.ref == 'refs/heads/develop'
  
- name: Deploy to Production  
  if: github.ref == 'refs/heads/main'
```

## 📊 Monitoreo de Workflows

### Status Badges
Añadir al README.md:
```markdown
![Infrastructure](https://github.com/tu-usuario/iac-core-hetzner/actions/workflows/deploy-infrastructure.yml/badge.svg)
![Traefik](https://github.com/tu-usuario/iac-core-hetzner/actions/workflows/deploy-traefik.yml/badge.svg)
```

### Notifications
Configurar notificaciones de Slack/Discord:
```yaml
- name: Notify Success
  if: success()
  uses: 8398a7/action-slack@v3
  with:
    status: success
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🚨 Troubleshooting Avanzado

### Debug Mode SSH
```yaml
- name: Debug SSH Connection
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.VPS_SSH_HOST }}
    username: ${{ secrets.VPS_SSH_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    debug: true  # ← Activa logs detallados
    script: |
      whoami
      pwd
      docker --version
      docker ps
```

### Verificar archivos copiados
```yaml
- name: Verify files
  uses: appleboy/ssh-action@v1.0.3
  with:
    # ... conexión SSH
    script: |
      ls -la /opt/codespartan/platform/traefik/
      cat /opt/codespartan/platform/traefik/.env
      docker compose config
```

### Cleanup en caso de fallo
```yaml
- name: Cleanup on failure
  if: failure()
  uses: appleboy/ssh-action@v1.0.3
  with:
    # ... conexión SSH  
    script: |
      cd /opt/codespartan/platform/traefik
      docker compose down || true
      docker system prune -f
```

---

## 📚 Referencias

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [SSH Action](https://github.com/appleboy/ssh-action)
- [SCP Action](https://github.com/appleboy/scp-action)
- [Docker Compose](https://docs.docker.com/compose/)

**Contacto**: infra@mambo-cloud.com  
**Repositorio**: https://github.com/CodeSpartan/iac-core-hetzner
