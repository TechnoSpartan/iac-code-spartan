# Guía para Principiantes - CodeSpartan Mambo Cloud

## 🎯 ¿Qué es esto?

Este proyecto te permite crear tu **propia infraestructura en la nube** de forma automática y profesional, usando las mejores prácticas de la industria.

### En términos sencillos:
- Tienes un **servidor en Hetzner** (VPS ARM64)
- Todo se **despliega automáticamente** con GitHub Actions
- Usas **contenedores Docker** para las aplicaciones
- Tienes **monitoreo profesional** con Grafana
- **SSL automático** para todos tus dominios

## 🏗️ ¿Cómo funciona la arquitectura?

```
Internet ──▶ Hetzner DNS ──▶ Tu VPS ──▶ Traefik ──▶ Aplicaciones
                             (ARM64)     (Proxy)     (Contenedores)
```

### Componentes principales:

1. **Terraform** = Crea el servidor automáticamente
2. **Traefik** = Proxy reverso que dirige el tráfico
3. **Docker** = Contenedores para las aplicaciones
4. **Grafana** = Dashboard para ver métricas
5. **GitHub Actions** = Despliega todo automáticamente

## 🚀 Tu primer despliegue (Paso a paso)

### Paso 1: Preparar las cuentas
```bash
# Necesitas estas cuentas:
1. Hetzner Cloud (para el VPS)
2. Hetzner DNS (para gestionar mambo-cloud.com)
3. GitHub (para el código y CI/CD)
```

### Paso 2: Configurar tokens y secrets
En GitHub → Tu repo → Settings → Secrets:

```
HCLOUD_TOKEN = tu_token_de_hetzner_cloud
HETZNER_DNS_TOKEN = tu_token_de_hetzner_dns  
VPS_SSH_HOST = 91.98.137.217
VPS_SSH_USER = root
VPS_SSH_KEY = tu_clave_privada_ssh_completa
```

### Paso 3: Ejecutar el despliegue
1. Ve a GitHub Actions
2. Ejecuta "Deploy Infrastructure (Terraform)" ✅
3. Espera 5-10 minutos
4. Ejecuta "Deploy Traefik" ✅
5. Ejecuta "Deploy Monitoring Stack" ✅
6. Ejecuta "Deploy Backoffice" ✅
7. Ejecuta "Deploy Mambo Cloud App" ✅

### Paso 4: ¡Verificar que todo funciona!
- https://traefik.mambo-cloud.com (admin/codespartan123)
- https://grafana.mambo-cloud.com (admin/codespartan123)  
- https://backoffice.mambo-cloud.com (admin/codespartan123)
- https://www.mambo-cloud.com

## 🤔 Conceptos importantes para entender

### ¿Qué es Traefik?
Es como un **portero inteligente** que:
- Recibe todas las peticiones web
- Las dirige al contenedor correcto
- Gestiona automáticamente los certificados SSL
- Proporciona balanceado de carga

### ¿Qué es Docker?
- **Contenedores** = Como cajas que contienen una aplicación completa
- **docker-compose.yml** = Receta para crear y configurar contenedores
- **Imágenes** = Plantillas para crear contenedores
- **Volúmenes** = Almacenamiento persistente para los datos

### ¿Qué es Terraform?
- **Infraestructura como Código (IaC)**
- Describes lo que quieres (servidor, DNS, firewall)
- Terraform lo crea automáticamente
- Si necesitas cambios, editas el código y aplicas

### ¿Qué es GitHub Actions?
- **CI/CD automatizado**
- Cada vez que haces `git push`, se ejecuta automáticamente
- Despliega cambios sin tocar el servidor manualmente
- Rastrea todos los cambios y despliegues

## 📁 Estructura del proyecto explicada

```
codespartan/
├── infra/
│   └── hetzner/           # 🏗️ Terraform: crea el VPS y DNS
│       ├── main.tf        # Configuración principal
│       ├── variables.tf   # Variables configurables
│       └── terraform.tfvars # Valores específicos del proyecto
│
├── platform/
│   ├── traefik/           # 🚪 Proxy reverso y SSL automático
│   │   ├── docker-compose.yml
│   │   └── .env           # Configuración específica
│   └── stacks/
│       ├── monitoring/    # 📊 Grafana + Prometheus + Loki
│       ├── backoffice/    # 🏢 Panel de control web
│       └── logging/       # 📋 Loki + Promtail para logs
│
├── apps/
│   ├── mambo-cloud/       # 🌐 Aplicación web principal
│   ├── cyberdyne/         # 🤖 Otras aplicaciones...
│   └── dental-ia-es/      # 🦷 Más aplicaciones...
│
└── docs/
    ├── RUNBOOK.md         # 📚 Guía operativa completa
    ├── BEGINNER.md        # 👶 Esta guía para principiantes
    └── GITHUB.md          # 🐙 Configuración GitHub Actions
```

## 🔧 Comandos básicos que necesitas saber

### Conectar por SSH al servidor
```bash
ssh root@91.98.137.217
```

### Ver contenedores ejecutándose
```bash
docker ps
```

### Ver logs de un contenedor
```bash
docker logs traefik -f
docker logs grafana --tail 50
```

### Reiniciar un servicio
```bash
cd /opt/codespartan/platform/traefik
docker compose restart
```

### Ver el estado del sistema
```bash
# CPU y memoria
htop

# Espacio en disco  
df -h

# Servicios de Docker
docker compose ps
```

## 🎮 Experimentando y aprendiendo

### Cambiar la página principal
1. Edita: `codespartan/apps/mambo-cloud/html/index.html`
2. Haz commit y push
3. GitHub Actions desplegará automáticamente
4. Ve el cambio en https://www.mambo-cloud.com

### Agregar una nueva aplicación
1. Crea directorio: `codespartan/apps/mi-nueva-app/`
2. Crea `docker-compose.yml` con labels de Traefik
3. Añade el subdominio en `terraform.tfvars`
4. Despliega todo

### Ver métricas en tiempo real
1. Ve a https://grafana.mambo-cloud.com
2. Explora los dashboards preconfigurados
3. Crea tus propias consultas y gráficos

## ❗ Errores comunes y soluciones

### "No puedo acceder a mi dominio"
```bash
# Verificar DNS
dig mambo-cloud.com

# Verificar Traefik
ssh root@91.98.137.217
docker logs traefik
```

### "El certificado SSL no funciona"
- Los certificados tardan 1-2 minutos en generarse
- Traefik usa Let's Encrypt automáticamente
- Verifica que el DNS apunte correctamente

### "GitHub Actions falla"
- Revisa que todos los secrets estén configurados
- Verifica que la SSH key sea correcta
- Mira los logs detallados en la pestaña Actions

### "Un contenedor no arranca"
```bash
# Ver qué está pasando
docker logs nombre_contenedor

# Verificar la configuración
cd /opt/codespartan/ruta/del/servicio
docker compose config
```

## 🎓 Conceptos para aprender más

A medida que te sientas cómodo, puedes explorar:

### Docker avanzado
- Crear tus propias imágenes con Dockerfile
- Docker networks y volumes
- Multi-stage builds
- Docker security best practices

### Terraform avanzado
- Modules y reutilización de código
- Remote state management
- Terraform workspaces
- Planning and validation

### Monitoreo avanzado
- Crear dashboards personalizados en Grafana
- Configurar alertas por email/Slack
- Métricas personalizadas de aplicaciones
- Logs estructurados y parsing

### GitOps y CI/CD
- Estrategias de deployment (blue/green, canary)
- Rollbacks automáticos
- Testing automatizado
- Security scanning

## 🆘 ¿Necesitas ayuda?

### Recursos útiles
- **Documentación oficial**: Siempre la fuente más actualizada
- **Docker Hub**: Para buscar imágenes oficiales
- **Traefik Docs**: Para configuraciones avanzadas de proxy
- **Grafana Dashboards**: Dashboards públicos para importar

### Comandos de diagnóstico
```bash
# Estado general del sistema
systemctl status docker
docker system df
docker system prune  # Limpiar recursos no usados

# Red de containers
docker network ls
docker network inspect web

# Verificar configuraciones
docker compose config
terraform validate
terraform plan
```

### Filosofía de aprendizaje
1. **Experimenta sin miedo** - Los containers son aislados
2. **Lee los logs** - Siempre contienen la información crucial
3. **Un cambio a la vez** - Facilita el debugging
4. **Documenta lo que aprendes** - Para futuras referencias

---

¡Recuerda que esta infraestructura está diseñada para ser **resiliente** y **fácil de recrear**. Si algo se rompe completamente, puedes destruir todo y recrearlo desde cero en menos de 30 minutos! 🎉
