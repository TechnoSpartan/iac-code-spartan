# Mambo Cloud - Aplicación Principal

Esta es la aplicación principal de la plataforma CodeSpartan que se despliega en múltiples subdominios de mambo-cloud.com.

## Subdominios configurados

- **www.mambo-cloud.com** - Página principal (producción)
- **staging.mambo-cloud.com** - Entorno de staging/pruebas
- **lab.mambo-cloud.com** - Entorno de laboratorio/desarrollo

## Estructura

```
mambo-cloud/
├── docker-compose.yml    # Configuración de contenedores con Traefik
├── html/
│   └── index.html       # Página web principal
└── README.md           # Este archivo
```

## Despliegue

El despliegue se realiza automáticamente via GitHub Actions cuando hay cambios en esta carpeta.

### Despliegue manual

```bash
cd /opt/codespartan/apps/mambo-cloud
docker compose pull
docker compose up -d
```

## Configuración Traefik

La aplicación está configurada para:
- Usar certificados SSL automáticos via Let's Encrypt
- Redireccionar HTTP a HTTPS
- Servir contenido estático desde Nginx
- Detectar automáticamente el entorno según el subdominio
