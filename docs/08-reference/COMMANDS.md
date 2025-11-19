# Comandos Útiles - Referencia Rápida

Referencia rápida de comandos útiles para operar la plataforma.

## Docker

```bash
# Ver contenedores corriendo
docker ps

# Ver todos los contenedores (incluyendo detenidos)
docker ps -a

# Ver logs de un contenedor
docker logs [container-name] -f

# Reiniciar un servicio
docker restart [container-name]

# Ver estadísticas de recursos
docker stats

# Ver redes Docker
docker network ls
docker network inspect web
```

## Servicios

```bash
# Ver estado de Traefik
docker logs traefik --tail 50

# Ver estado de Grafana
docker logs grafana --tail 50

# Verificar health checks
docker inspect [container] | grep -A 10 Health
```

## DNS

```bash
# Verificar resolución DNS
dig subdomain.mambo-cloud.com
nslookup subdomain.mambo-cloud.com

# Verificar nameservers
dig NS mambo-cloud.com

# Verificar registros A
dig A subdomain.mambo-cloud.com
```

## SSL

```bash
# Verificar certificado SSL
openssl s_client -connect subdomain.mambo-cloud.com:443 -servername subdomain.mambo-cloud.com

# Ver certificados en Traefik
docker exec traefik ls -la /letsencrypt/
```

## Backups

```bash
# Ejecutar backup manual
/opt/codespartan/scripts/backup.sh

# Ver backups disponibles
ls -lh /opt/codespartan/backups/

# Verificar backup
tar -tzf /opt/codespartan/backups/backup-*.tar.gz | head -20
```

## Monitoreo

```bash
# Ver métricas de VictoriaMetrics
curl http://localhost:8428/api/v1/query?query=up

# Ver alertas activas
curl http://localhost:8880/api/v1/rules
curl http://localhost:9093/api/v2/alerts

# Ver logs en Loki (vía API)
curl http://localhost:3100/ready
```

## Sistema

```bash
# Ver uso de recursos
htop
df -h
free -h

# Ver procesos
ps aux | grep docker

# Ver espacio en disco
du -sh /opt/codespartan/*
```

## SSH

```bash
# Conectar al VPS
ssh leonidas@91.98.137.217

# Ejecutar comando remoto
ssh leonidas@91.98.137.217 "docker ps"

# Copiar archivo al VPS
scp archivo.txt leonidas@91.98.137.217:/opt/codespartan/
```

## Troubleshooting

```bash
# Ver logs del sistema
journalctl -u docker -n 50
journalctl -u fail2ban -n 50

# Verificar conectividad
ping 8.8.8.8
curl -I https://google.com

# Verificar puertos abiertos
netstat -tulpn | grep LISTEN
ss -tulpn
```

