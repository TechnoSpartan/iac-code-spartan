#!/bin/bash
set -euo pipefail

# ============================================================================
# FASE 2: Deployment de Authelia SSO
# ============================================================================
# Este script despliega Authelia con SSO y MFA para todos los dashboards
#
# Uso: ./deploy.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRAEFIK_DIR="$(cd "${SCRIPT_DIR}/../traefik" && pwd)"
MONITORING_DIR="$(cd "${SCRIPT_DIR}/../stacks/monitoring" && pwd)"
BACKUP_DIR="/tmp/authelia-backup-$(date +%s)"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log_info "🚀 FASE 2: Deploying Authelia SSO with MFA"

# ============================================================================
# PASO 1: Validaciones
# ============================================================================
log_info "🔍 Validando entorno..."

if [ ! -d "/opt/codespartan" ]; then
    log_error "Este script debe ejecutarse en el VPS de producción"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "Docker no está corriendo"
    exit 1
fi

log_info "✅ Validaciones completadas"

# ============================================================================
# PASO 2: Backup
# ============================================================================
log_info "💾 Creando backup..."
mkdir -p "$BACKUP_DIR"
cp -r "$TRAEFIK_DIR" "$BACKUP_DIR/"
cp -r "$MONITORING_DIR" "$BACKUP_DIR/"

log_info "✅ Backup creado en: $BACKUP_DIR"

# ============================================================================
# PASO 3: Deploy Authelia
# ============================================================================
log_info "🔐 Desplegando Authelia..."
cd "$SCRIPT_DIR"
docker compose up -d

# Health check
log_info "🔍 Verificando health de Authelia..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' authelia 2>/dev/null || echo "unknown")

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        log_info "✅ Authelia está healthy"
        break
    fi

    if [ $ATTEMPT -eq $((MAX_ATTEMPTS - 1)) ]; then
        log_error "Authelia no pasó el health check"
        docker logs authelia --tail 50
        log_warn "🔄 Iniciando rollback..."
        docker compose down --volumes --remove-orphans
        exit 1
    fi

    echo -n "."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

# ============================================================================
# PASO 4: Actualizar Traefik
# ============================================================================
log_info "🔄 Actualizando Traefik con Authelia middleware..."
cd "$TRAEFIK_DIR"
docker compose down --remove-orphans
docker rm -f traefik 2>/dev/null || true
docker compose up -d

# Health check
log_info "🔍 Verificando Traefik..."
sleep 10

# ============================================================================
# PASO 5: Actualizar Grafana
# ============================================================================
log_info "🔄 Actualizando Grafana con SSO..."
cd "$MONITORING_DIR"
docker compose up -d grafana --force-recreate

log_info "⏳ Esperando a que Grafana inicie..."
sleep 15

# ============================================================================
# SUCCESS
# ============================================================================
log_info ""
log_info "════════════════════════════════════════════════════════════"
log_info "✨ FASE 2 completada exitosamente ✨"
log_info "════════════════════════════════════════════════════════════"
log_info ""
log_info "🔐 Authelia SSO desplegado"
log_info "🚪 Traefik dashboard protegido con Authelia"
log_info "📊 Grafana protegido con Authelia"
log_info ""
log_info "📋 Próximos pasos:"
log_info "  1. Acceder a https://auth.mambo-cloud.com"
log_info "  2. Login con: admin / <ver password manager / última rotación de AUTHELIA_ADMIN_PASSWORD_HASH>"
log_info "  3. Configurar MFA (escanear QR con Google Authenticator)"
log_info "  4. Acceder a https://traefik.mambo-cloud.com (redirigirá a Authelia)"
log_info "  5. Acceder a https://grafana.mambo-cloud.com (redirigirá a Authelia)"
log_info ""
log_info "💾 Backup disponible en: $BACKUP_DIR"
log_info "════════════════════════════════════════════════════════════"
