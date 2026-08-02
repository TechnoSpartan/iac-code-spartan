#!/bin/bash
# ============================================================================
# Script para crear una nueva instancia de Kong API Gateway
# ============================================================================
#
# Uso: ./create-kong-instance.sh <domain-name> <api-host> <api-staging-host>
#
# Ejemplo:
#   ./create-kong-instance.sh dental-ia api.dental-ia.es api-staging.dental-ia.es
#
# ============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validar argumentos
if [ $# -lt 3 ]; then
    echo -e "${RED}Error: Faltan argumentos${NC}"
    echo ""
    echo "Uso: $0 <domain-name> <api-host> <api-staging-host>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 dental-ia api.dental-ia.es api-staging.dental-ia.es"
    echo ""
    exit 1
fi

DOMAIN_NAME=$1
API_HOST=$2
API_STAGING_HOST=$3

# Extraer el dominio base del API_HOST (quitar el prefijo api.)
DOMAIN_HOST=$(echo "$API_HOST" | sed 's/^api\.//')

# Valores por defecto (pueden modificarse despues)
API_CONTAINER="${DOMAIN_NAME//-/}-api"
API_STAGING_CONTAINER="${DOMAIN_NAME//-/}-api-staging"
API_PORT="3000"

# Calcular subnet basado en dominios existentes
# cyberdyne = 172.26.0.0/24, siguiente = 172.27.0.0/24, etc.
EXISTING_KONGS=$(ls -d ../*/docker-compose.yml 2>/dev/null | wc -l || echo "1")
SUBNET_THIRD=$((26 + EXISTING_KONGS))
NETWORK_SUBNET="172.${SUBNET_THIRD}.0.0/24"

# CORS origins
CORS_ORIGIN_PROD="https://${DOMAIN_HOST}"
CORS_ORIGIN_WWW="https://www.${DOMAIN_HOST}"
CORS_ORIGIN_STAGING="https://staging.${DOMAIN_HOST}"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Creando Kong para: ${DOMAIN_NAME}${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Configuracion:"
echo "  - Domain Name:     ${DOMAIN_NAME}"
echo "  - Domain Host:     ${DOMAIN_HOST}"
echo "  - API Host:        ${API_HOST}"
echo "  - API Staging:     ${API_STAGING_HOST}"
echo "  - API Container:   ${API_CONTAINER}"
echo "  - Staging Container: ${API_STAGING_CONTAINER}"
echo "  - API Port:        ${API_PORT}"
echo "  - Network Subnet:  ${NETWORK_SUBNET}"
echo ""

# Confirmar
read -p "¿Continuar? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado."
    exit 0
fi

# Directorio base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="${BASE_DIR}/${DOMAIN_NAME}"

# Verificar que no existe
if [ -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: El directorio ${TARGET_DIR} ya existe${NC}"
    exit 1
fi

# Crear directorio
echo -e "${YELLOW}Creando directorio...${NC}"
mkdir -p "$TARGET_DIR"

# Copiar y procesar docker-compose.yml
echo -e "${YELLOW}Procesando docker-compose.yml...${NC}"
sed -e "s/{{DOMAIN_NAME}}/${DOMAIN_NAME}/g" \
    -e "s/{{DOMAIN_HOST}}/${DOMAIN_HOST}/g" \
    -e "s/{{API_HOST}}/${API_HOST}/g" \
    -e "s/{{API_STAGING_HOST}}/${API_STAGING_HOST}/g" \
    -e "s/{{API_CONTAINER}}/${API_CONTAINER}/g" \
    -e "s/{{API_STAGING_CONTAINER}}/${API_STAGING_CONTAINER}/g" \
    -e "s/{{API_PORT}}/${API_PORT}/g" \
    -e "s|{{NETWORK_SUBNET}}|${NETWORK_SUBNET}|g" \
    "${SCRIPT_DIR}/docker-compose.yml" > "${TARGET_DIR}/docker-compose.yml"

# Copiar y procesar kong.yml
echo -e "${YELLOW}Procesando kong.yml...${NC}"
sed -e "s/{{DOMAIN_NAME}}/${DOMAIN_NAME}/g" \
    -e "s/{{DOMAIN_HOST}}/${DOMAIN_HOST}/g" \
    -e "s/{{API_HOST}}/${API_HOST}/g" \
    -e "s/{{API_STAGING_HOST}}/${API_STAGING_HOST}/g" \
    -e "s/{{API_CONTAINER}}/${API_CONTAINER}/g" \
    -e "s/{{API_STAGING_CONTAINER}}/${API_STAGING_CONTAINER}/g" \
    -e "s/{{API_PORT}}/${API_PORT}/g" \
    -e "s|{{CORS_ORIGIN_PROD}}|${CORS_ORIGIN_PROD}|g" \
    -e "s|{{CORS_ORIGIN_WWW}}|${CORS_ORIGIN_WWW}|g" \
    -e "s|{{CORS_ORIGIN_STAGING}}|${CORS_ORIGIN_STAGING}|g" \
    "${SCRIPT_DIR}/kong.yml" > "${TARGET_DIR}/kong.yml"

# Crear README personalizado
echo -e "${YELLOW}Creando README.md...${NC}"
cat > "${TARGET_DIR}/README.md" << EOF
# Kong API Gateway - ${DOMAIN_NAME}

API Gateway para las APIs de ${DOMAIN_HOST} usando Kong en modo DB-less (declarativo).

## Arquitectura

\`\`\`
Internet --> Traefik (SSL/443) --> Kong (8000) --> API Backend (${API_PORT})
                                      |
                                      v
                                   Prometheus (metricas)
                                   Loki (logs JSON)
\`\`\`

## Servicios Configurados

| Servicio | Host | Backend | Rate Limit |
|----------|------|---------|------------|
| Produccion | ${API_HOST} | ${API_CONTAINER}:${API_PORT} | 50 req/s |
| Staging | ${API_STAGING_HOST} | ${API_STAGING_CONTAINER}:${API_PORT} | 100 req/s |

## Redes

| Red | Subnet | Proposito |
|-----|--------|-----------|
| web | 172.20.0.0/16 | Recibe trafico de Traefik |
| kong_${DOMAIN_NAME} | ${NETWORK_SUBNET} | Conecta con APIs (internal) |

## Comandos Utiles

\`\`\`bash
# Ver estado
docker ps --filter "name=kong-${DOMAIN_NAME}"

# Ver logs
docker logs kong-${DOMAIN_NAME} -f

# Health check
docker exec kong-${DOMAIN_NAME} kong health

# Recargar configuracion (sin downtime)
docker exec kong-${DOMAIN_NAME} kong reload

# Metricas Prometheus
curl http://localhost:8100/metrics
\`\`\`

## Verificacion

\`\`\`bash
# Test produccion
curl -I https://${API_HOST}/health

# Ver headers rate-limit
curl -I https://${API_HOST}/health | grep -i ratelimit

# Test staging
curl -I https://${API_STAGING_HOST}/health
\`\`\`

## Archivos

- \`docker-compose.yml\` - Configuracion del contenedor Kong
- \`kong.yml\` - Configuracion declarativa (servicios, rutas, plugins)

## Recursos

- CPU: 0.5 cores (limite)
- RAM: 512 MB (limite), ~150-200 MB uso real
EOF

# Crear workflow de GitHub Actions
echo -e "${YELLOW}Creando workflow de GitHub Actions...${NC}"
WORKFLOW_DIR="${BASE_DIR}/../../.github/workflows"
sed -e "s/{{DOMAIN_NAME}}/${DOMAIN_NAME}/g" \
    -e "s|{{NETWORK_SUBNET}}|${NETWORK_SUBNET}|g" \
    "${WORKFLOW_DIR}/_TEMPLATE-deploy-kong.yml.template" > "${WORKFLOW_DIR}/deploy-kong-${DOMAIN_NAME}.yml"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Kong ${DOMAIN_NAME} creado exitosamente!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Archivos creados:"
echo "  - ${TARGET_DIR}/docker-compose.yml"
echo "  - ${TARGET_DIR}/kong.yml"
echo "  - ${TARGET_DIR}/README.md"
echo "  - ${WORKFLOW_DIR}/deploy-kong-${DOMAIN_NAME}.yml"
echo ""
echo -e "${YELLOW}Proximos pasos:${NC}"
echo ""
echo "1. Revisar y ajustar la configuracion si es necesario:"
echo "   - API_CONTAINER: ${API_CONTAINER}"
echo "   - API_PORT: ${API_PORT}"
echo ""
echo "2. Agregar scrape de Prometheus en:"
echo "   codespartan/platform/stacks/monitoring/victoriametrics/prometheus.yml"
echo ""
echo "   - job_name: 'kong-${DOMAIN_NAME}'"
echo "     static_configs:"
echo "       - targets: ['kong-${DOMAIN_NAME}:8100']"
echo ""
echo "3. Modificar la API para usar la red kong_${DOMAIN_NAME}:"
echo "   - Quitar labels de Traefik"
echo "   - Cambiar red 'web' por 'kong_${DOMAIN_NAME}'"
echo ""
echo "4. Hacer commit y push:"
echo "   git add ."
echo "   git commit -m 'feat(kong): Add Kong API Gateway for ${DOMAIN_NAME}'"
echo "   git push"
echo ""
echo "5. El workflow se ejecutara automaticamente o manualmente desde GitHub Actions"
echo ""
