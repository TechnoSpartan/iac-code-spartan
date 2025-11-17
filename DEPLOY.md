# 🚀 Guía de Despliegue Rápido - CodeSpartan Mambo Cloud

## ✅ Checklist Pre-Despliegue

Antes de empezar, asegúrate de tener:

- [ ] **Hetzner Cloud**: Cuenta + Token API
- [ ] **Hetzner DNS**: Token API (diferente al de Cloud)
- [ ] **Dominio**: mambo-cloud.com con NS apuntando a Hetzner
- [ ] **GitHub**: Repositorio forkeado/clonado
- [ ] **SSH Key**: Generada y configurada

## 🔑 Paso 1: Generar SSH Key

```bash
# Generar nueva clave SSH específica para este proyecto
ssh-keygen -t ed25519 -f ~/.ssh/id_codespartan -C "codespartan@mambo-cloud.com"

# Ver clave pública (necesaria para Terraform)
cat ~/.ssh/id_codespartan.pub

# Ver clave privada (necesaria para GitHub Secrets)
cat ~/.ssh/id_codespartan
```

## 🔐 Paso 2: Configurar GitHub Secrets

Ve a tu repositorio GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Añade estos 5 secrets:

| Nombre | Valor | Notas |
|--------|-------|-------|
| `HCLOUD_TOKEN` | `tu_token_hetzner_cloud` | Console Hetzner Cloud → Security → API tokens |
| `HETZNER_DNS_TOKEN` | `tu_token_hetzner_dns` | Console Hetzner → DNS → API tokens |
| `VPS_SSH_HOST` | `91.98.137.217` | IP fija de tu VPS |
| `VPS_SSH_USER` | `leonidas` | Tu usuario en el VPS |
| `VPS_SSH_KEY` | `-----BEGIN OPENSSH...` | Contenido completo de id_codespartan (privada) |

⚠️ **Importante**: `VPS_SSH_KEY` debe incluir `-----BEGIN OPENSSH PRIVATE KEY-----` y `-----END OPENSSH PRIVATE KEY-----`

## 🏗️ Paso 3: Actualizar Configuración SSH en Terraform

Edita `codespartan/infra/hetzner/terraform.tfvars`:

```hcl
# Cambiar esta línea si usaste un nombre diferente para la SSH key
ssh_public_key_path = "~/.ssh/id_codespartan.pub"
```

## 🚀 Paso 4: Despliegue Secuencial

### 4.1 Crear Infraestructura

1. Ve a **Actions** → **Deploy Infrastructure (Terraform)**
2. Click **Run workflow** → **Run workflow**
3. ⏳ Espera 5-10 minutos
4. ✅ Verifica que termine exitosamente

**Qué hace**: Crea VPS, configura DNS, instala Docker automáticamente

### 4.2 Desplegar Traefik (Proxy Reverso)

1. **Actions** → **Deploy Traefik**
2. **Run workflow**
3. ⏳ Espera 2-3 minutos
4. ✅ Verifica: https://traefik.mambo-cloud.com

**Credenciales**: admin / codespartan123

### 4.3 Desplegar Stack de Monitoreo

1. **Actions** → **Deploy Monitoring Stack**
2. **Run workflow**
3. ⏳ Espera 3-5 minutos
4. ✅ Verifica: https://grafana.mambo-cloud.com

**Credenciales**: admin / codespartan123

### 4.4 Desplegar Backoffice

1. **Actions** → **Deploy Backoffice**
2. **Run workflow**
3. ⏳ Espera 1-2 minutos
4. ✅ Verifica: https://backoffice.mambo-cloud.com

**Credenciales**: admin / codespartan123

### 4.5 Desplegar Aplicación Principal

1. **Actions** → **Deploy Mambo Cloud App**
2. **Run workflow**
3. ⏳ Espera 1-2 minutos
4. ✅ Verifica: https://www.mambo-cloud.com

### 4.6 Desplegar CodeSpartan Cloud

1. **Actions** → **Deploy CodeSpartan WWW**
2. **Run workflow**
3. ⏳ Espera 1-2 minutos
4. ✅ Verifica: https://www.codespartan.cloud

5. **Actions** → **Deploy CodeSpartan UI (Storybook)**
6. **Run workflow**
7. ⏳ Espera 1-2 minutos
8. ✅ Verifica: https://ui.codespartan.cloud

⚠️ **Nota**: Si los dominios devuelven 404 después del despliegue, consulta [TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md](codespartan/docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md) para la solución.

## 🔍 Paso 5: Verificación Completa

### URLs a probar:

```bash
✅ https://traefik.mambo-cloud.com     # Dashboard Traefik
✅ https://grafana.mambo-cloud.com     # Monitoreo + Métricas
✅ https://backoffice.mambo-cloud.com  # Panel de Control
✅ https://www.mambo-cloud.com         # App Principal
✅ https://staging.mambo-cloud.com     # Entorno Staging
✅ https://lab.mambo-cloud.com         # Entorno Lab
✅ https://www.codespartan.cloud      # CodeSpartan Website
✅ https://ui.codespartan.cloud       # CodeSpartan UI/Storybook
```

### Verificación por SSH:

```bash
# Conectar al VPS
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217

# Verificar contenedores
docker ps

# Debería mostrar algo así:
# traefik
# victoriametrics
# vmagent
# loki
# promtail
# grafana
# node-exporter
# cadvisor
# backoffice
# mambo-cloud-app

# Ver logs si hay problemas
docker logs traefik
docker logs grafana
```

## 🐛 Troubleshooting Rápido

### Problema: GitHub Actions falla

```bash
# 1. Verificar secrets están configurados
# 2. Ver logs detallados en Actions → Job fallido
# 3. Verificar SSH key es correcta:
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217 "whoami"
```

### Problema: No puedo acceder a los dominios

```bash
# 1. Verificar DNS resuelve correctamente
dig traefik.mambo-cloud.com

# 2. Verificar nameservers del dominio
dig NS mambo-cloud.com

# Debería mostrar:
# helium.ns.hetzner.de
# hydrogen.ns.hetzner.de  
# oxygen.ns.hetzner.de
```

### Problema: SSL no funciona

- ⏳ Los certificados tardan 1-2 minutos en generarse
- 🔄 Traefik los gestiona automáticamente con Let's Encrypt
- 📋 Verificar en logs: `docker logs traefik | grep -i acme`

### Problema: Servicio no arranca

```bash
# SSH al VPS
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217

# Ver qué está pasando
docker ps -a | grep servicio_problema
docker logs servicio_problema

# Verificar configuración
cd /opt/codespartan/ruta/del/servicio
docker compose config
```

## ⚡ Comandos de Emergencia

### Reiniciar todo:

```bash
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217

# Parar todos los servicios
cd /opt/codespartan
find . -name "docker-compose.yml" -execdir docker compose down \;

# Arrancar en orden
cd /opt/codespartan/platform/traefik && docker compose up -d
cd /opt/codespartan/platform/stacks/monitoring && docker compose up -d
cd /opt/codespartan/platform/stacks/backoffice && docker compose up -d
cd /opt/codespartan/apps/mambo-cloud && docker compose up -d
```

### Limpiar y empezar de cero:

```bash
# ⚠️ DESTRUCTIVO: Borra todo
ssh -i ~/.ssh/id_codespartan leonidas@91.98.137.217
docker system prune -a -f
sudo rm -rf /opt/codespartan
# Luego re-ejecutar workflows GitHub Actions
```

## 🎉 ¡Éxito! Próximos Pasos

Una vez que todo funcione:

### 1. Personalizar aplicación
- Edita: `codespartan/apps/mambo-cloud/html/index.html`
- Haz commit y push → Se despliega automáticamente

### 2. Explorar Grafana
- Ve a https://grafana.mambo-cloud.com
- Explora dashboards y métricas
- Configura alertas personalizadas

### 3. Agregar más aplicaciones
- Crea nueva app en `codespartan/apps/nueva-app/`
- Añade subdominio en `terraform.tfvars`
- Despliega con GitHub Actions

### 4. Monitorear logs
- Grafana → Explore → Loki datasource
- Ver logs de todos los contenedores centralizados

---

## 📞 Si Necesitas Ayuda

1. **Revisa los logs** detallados en GitHub Actions
2. **SSH al VPS** y verifica contenedores: `docker ps`
3. **Consulta documentación**:
   - [RUNBOOK.md](codespartan/docs/RUNBOOK.md) - Guía completa
   - [BEGINNER.md](codespartan/docs/BEGINNER.md) - Tutorial paso a paso
   - [GITHUB.md](codespartan/docs/GITHUB.md) - CI/CD detallado
   - [TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md](codespartan/docs/TROUBLESHOOTING_TRAEFIK_CODESPARTAN.md) - Solución problemas CodeSpartan Cloud

**¡Disfruta de tu nueva infraestructura cloud profesional! 🚀**
