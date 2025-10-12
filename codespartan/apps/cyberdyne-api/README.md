# Cyberdyne Systems API

Este directorio contiene la configuración de Docker Compose para desplegar la API de Cyberdyne Systems.

## 🌐 Dominio

- **API**: https://api.cyberdyne-systems.es

## 🚀 Despliegue

La API se despliega automáticamente mediante GitHub Actions cuando:
- Se ejecuta manualmente el workflow `Deploy Cyberdyne API`
- Se hace push a la rama principal del repositorio de la API

## 🔧 Configuración

### Variables de Entorno

El contenedor utiliza las siguientes variables de entorno:
- `NODE_ENV=production`
- `PORT=3000`

Para añadir más variables de entorno, edita el archivo `docker-compose.yml`.

### Health Check

La API debe exponer un endpoint `/health` que responda con un status 200 OK.

### CORS

La configuración incluye middleware de CORS para permitir peticiones desde:
- https://www.cyberdyne-systems.es
- https://staging.cyberdyne-systems.es
- https://lab.cyberdyne-systems.es

## 📦 Requisitos

- La imagen Docker debe estar publicada en GitHub Container Registry
- El repositorio debe tener los secrets de GitHub configurados
- Traefik debe estar corriendo en el VPS

## 🔍 Verificación

Después del despliegue, verifica que la API esté funcionando:

```bash
curl https://api.cyberdyne-systems.es/health
```

