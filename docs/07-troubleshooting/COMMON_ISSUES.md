# Problemas Comunes

Guía de problemas frecuentes y sus soluciones.

## Contenedores no Inician

**Síntomas:**
- `docker ps` no muestra el contenedor
- `docker ps -a` muestra contenedor como "Exited"

**Solución:**
```bash
# Ver logs del contenedor
docker logs [container-name]

# Verificar configuración
cd /opt/codespartan/[ruta]/[servicio]
docker compose config

# Reiniciar servicio
docker compose up -d
```

## Health Checks Fallan

**Síntomas:**
- Contenedor muestra estado "unhealthy"
- `docker inspect [container]` muestra health check fallando

**Solución:**
```bash
# Verificar health check manualmente
docker exec [container] wget --spider http://localhost:[port]/

# Verificar que el puerto es correcto
docker inspect [container] | grep -A 5 Health

# Verificar logs
docker logs [container] --tail 50
```

## Aplicaciones no Accesibles

**Síntomas:**
- URL devuelve 404 o timeout
- Contenedor está corriendo pero no responde

**Solución:**
1. Verificar contenedor está corriendo: `docker ps | grep [service]`
2. Verificar Traefik routing: `docker logs traefik | grep [subdomain]`
3. Verificar red Docker: `docker network inspect web`
4. Probar acceso interno: `curl -H "Host: subdomain.mambo-cloud.com" http://localhost`

## Puerto ya en Uso

**Síntomas:**
- Error: "port is already allocated"
- Contenedor no puede iniciar

**Solución:**
```bash
# Ver qué está usando el puerto
sudo lsof -i :80
sudo lsof -i :443

# Detener contenedor que usa el puerto
docker stop [container-using-port]

# O cambiar puerto en docker-compose.yml
```

## Espacio en Disco Lleno

**Síntomas:**
- Error: "no space left on device"
- Docker no puede crear contenedores

**Solución:**
```bash
# Verificar espacio
df -h

# Limpiar imágenes no usadas
docker system prune -a

# Limpiar volúmenes no usados (CAUTION)
docker volume prune

# Limpiar backups antiguos
rm /opt/codespartan/backups/backup-YYYY-MM-DD_*.tar.gz
```

## Red Docker no Existe

**Síntomas:**
- Error: "network web not found"
- Contenedores no pueden conectarse

**Solución:**
```bash
# Crear red web
docker network create web

# Verificar red existe
docker network ls | grep web
```

## Certificados SSL no se Renuevan

**Síntomas:**
- Certificados próximos a expirar
- Traefik no renueva automáticamente

**Solución:**
1. Verificar logs: `docker logs traefik | grep -i renew`
2. Verificar configuración ACME en Traefik
3. Reiniciar Traefik: `docker restart traefik`
4. Ver [SSL.md](SSL.md) para más detalles

## Problemas de Permisos

**Síntomas:**
- Error: "permission denied"
- Scripts no se pueden ejecutar

**Solución:**
```bash
# Dar permisos de ejecución
chmod +x /opt/codespartan/scripts/*.sh

# Verificar propietario
ls -la /opt/codespartan/scripts/

# Cambiar propietario si es necesario
sudo chown -R leonidas:leonidas /opt/codespartan/
```

## Siguiente Paso

Si el problema no está listado aquí, consulta:
- [Índice de Troubleshooting](INDEX.md)
- [Runbook](../03-operations/RUNBOOK.md)
- Logs específicos del servicio

