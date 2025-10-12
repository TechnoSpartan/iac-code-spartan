#!/bin/bash
# Script de diagnóstico completo para Cyberdyne Systems
# Ejecutar en el VPS: bash diagnose-cyberdyne.sh

set -e

echo "🔍 =========================================="
echo "   DIAGNÓSTICO CYBERDYNE SYSTEMS"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Verificar que el contenedor está corriendo
echo -e "${BLUE}1️⃣ Estado del contenedor cyberdyne-frontend${NC}"
if docker ps | grep -q cyberdyne-frontend; then
    echo -e "${GREEN}✅ Contenedor está corriendo${NC}"
    docker ps | grep cyberdyne-frontend
else
    echo -e "${RED}❌ Contenedor NO está corriendo${NC}"
    echo "Verificando si existe pero está parado..."
    docker ps -a | grep cyberdyne-frontend || echo "No se encuentra el contenedor"
fi
echo ""

# 2. Verificar health status
echo -e "${BLUE}2️⃣ Estado de salud del contenedor${NC}"
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' cyberdyne-frontend 2>/dev/null || echo "no-healthcheck")
if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ Health status: healthy${NC}"
elif [ "$HEALTH_STATUS" = "no-healthcheck" ]; then
    echo -e "${YELLOW}⚠️  No hay health check configurado${NC}"
else
    echo -e "${RED}❌ Health status: $HEALTH_STATUS${NC}"
fi
echo ""

# 3. Verificar que está en la red 'web'
echo -e "${BLUE}3️⃣ Verificación de red Docker${NC}"
if docker network inspect web | grep -q cyberdyne-frontend; then
    echo -e "${GREEN}✅ Contenedor está en la red 'web'${NC}"
else
    echo -e "${RED}❌ Contenedor NO está en la red 'web'${NC}"
    echo "Redes del contenedor:"
    docker inspect cyberdyne-frontend --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "No se puede inspeccionar"
fi
echo ""

# 4. Verificar que Traefik puede ver el contenedor
echo -e "${BLUE}4️⃣ Labels de Traefik en el contenedor${NC}"
TRAEFIK_ENABLE=$(docker inspect cyberdyne-frontend --format='{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "not-found")
if [ "$TRAEFIK_ENABLE" = "true" ]; then
    echo -e "${GREEN}✅ traefik.enable=true${NC}"
    echo ""
    echo "Labels de Traefik configurados:"
    docker inspect cyberdyne-frontend --format='{{range $k, $v := .Config.Labels}}{{if contains $k "traefik"}}  {{$k}}={{$v}}{{"\n"}}{{end}}{{end}}' 2>/dev/null
else
    echo -e "${RED}❌ traefik.enable no está configurado o es false${NC}"
fi
echo ""

# 5. Verificar que Traefik está corriendo
echo -e "${BLUE}5️⃣ Estado de Traefik${NC}"
if docker ps | grep -q traefik; then
    echo -e "${GREEN}✅ Traefik está corriendo${NC}"
    docker ps | grep traefik
else
    echo -e "${RED}❌ Traefik NO está corriendo${NC}"
fi
echo ""

# 6. Test interno del contenedor
echo -e "${BLUE}6️⃣ Test de conectividad interna${NC}"
if docker exec cyberdyne-frontend wget -q -O- http://localhost/ 2>&1 | head -5 > /dev/null; then
    echo -e "${GREEN}✅ El contenedor responde internamente en localhost:80${NC}"
    echo "Primeras líneas de la respuesta:"
    docker exec cyberdyne-frontend wget -q -O- http://localhost/ 2>&1 | head -5
else
    echo -e "${RED}❌ El contenedor NO responde internamente${NC}"
fi
echo ""

# 7. Verificar archivos dentro del contenedor
echo -e "${BLUE}7️⃣ Archivos en /usr/share/nginx/html${NC}"
if docker exec cyberdyne-frontend test -f /usr/share/nginx/html/index.html; then
    echo -e "${GREEN}✅ index.html existe${NC}"
    FILE_SIZE=$(docker exec cyberdyne-frontend stat -c%s /usr/share/nginx/html/index.html)
    echo "Tamaño: $FILE_SIZE bytes"
    echo ""
    echo "Contenido de la carpeta:"
    docker exec cyberdyne-frontend ls -lh /usr/share/nginx/html
else
    echo -e "${RED}❌ index.html NO existe${NC}"
fi
echo ""

# 8. Test de conectividad externa
echo -e "${BLUE}8️⃣ Test de conectividad externa (www.cyberdyne-systems.es)${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://www.cyberdyne-systems.es)
if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "${GREEN}✅ Responde con HTTP $HTTP_STATUS${NC}"
elif [ "$HTTP_STATUS" -eq 404 ]; then
    echo -e "${RED}❌ Responde con HTTP 404${NC}"
    echo -e "${YELLOW}Esto indica un problema de configuración de Traefik/Proxy${NC}"
else
    echo -e "${YELLOW}⚠️  Responde con HTTP $HTTP_STATUS${NC}"
fi
echo ""

# 9. Verificar logs de Traefik
echo -e "${BLUE}9️⃣ Últimas líneas de logs de Traefik${NC}"
echo "Buscando errores relacionados con cyberdyne..."
docker logs traefik --tail 100 2>&1 | grep -i "cyberdyne" || echo "No se encontraron mensajes relacionados con cyberdyne"
echo ""

# 10. Verificar docker-compose.yml
echo -e "${BLUE}🔟 Verificación de docker-compose.yml${NC}"
if [ -f /opt/codespartan/apps/cyberdyne/docker-compose.yml ]; then
    echo -e "${GREEN}✅ docker-compose.yml existe${NC}"
    echo ""
    echo "Labels de Traefik en docker-compose.yml:"
    grep "traefik" /opt/codespartan/apps/cyberdyne/docker-compose.yml | head -10
else
    echo -e "${RED}❌ docker-compose.yml NO existe${NC}"
fi
echo ""

# 11. DNS Check
echo -e "${BLUE}1️⃣1️⃣ Verificación de DNS${NC}"
echo "Resolviendo www.cyberdyne-systems.es..."
dig +short www.cyberdyne-systems.es || nslookup www.cyberdyne-systems.es | grep Address || echo "No se pudo resolver el DNS"
echo ""

# Resumen
echo "=========================================="
echo -e "${BLUE}📋 RESUMEN${NC}"
echo "=========================================="

ISSUES=0

if ! docker ps | grep -q cyberdyne-frontend; then
    echo -e "${RED}❌ Contenedor no está corriendo${NC}"
    ((ISSUES++))
fi

if [ "$HEALTH_STATUS" != "healthy" ] && [ "$HEALTH_STATUS" != "no-healthcheck" ]; then
    echo -e "${RED}❌ Health check fallando${NC}"
    ((ISSUES++))
fi

if ! docker network inspect web | grep -q cyberdyne-frontend; then
    echo -e "${RED}❌ Contenedor no está en la red 'web'${NC}"
    ((ISSUES++))
fi

if [ "$TRAEFIK_ENABLE" != "true" ]; then
    echo -e "${RED}❌ Labels de Traefik no configurados${NC}"
    ((ISSUES++))
fi

if ! docker ps | grep -q traefik; then
    echo -e "${RED}❌ Traefik no está corriendo${NC}"
    ((ISSUES++))
fi

if [ "$HTTP_STATUS" != "200" ]; then
    echo -e "${RED}❌ El sitio responde con HTTP $HTTP_STATUS${NC}"
    ((ISSUES++))
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ Todo parece estar bien configurado${NC}"
else
    echo -e "${RED}❌ Se encontraron $ISSUES problemas${NC}"
    echo ""
    echo "Próximos pasos recomendados:"
    echo "1. Revisar los logs detallados arriba"
    echo "2. Verificar que el docker-compose.yml tenga los labels correctos"
    echo "3. Reconstruir el contenedor: cd /opt/codespartan/apps/cyberdyne && docker compose up -d --force-recreate"
fi

echo ""
echo "=========================================="
echo "Diagnóstico completado"
echo "=========================================="

