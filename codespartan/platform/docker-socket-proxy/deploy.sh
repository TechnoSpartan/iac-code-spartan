#!/bin/bash
set -euo pipefail

# ============================================================================
# FASE 1: Deployment de docker-socket-proxy
# ============================================================================
# Este script despliega docker-socket-proxy con health checks y rollback
# automático en caso de fallo.
#
# Uso: ./deploy.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRAEFIK_DIR="$(cd "${SCRIPT_DIR}/../traefik" && pwd)"
BACKUP_DIR="/tmp/traefik-backup-$(date +%s)"

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================================
# PASO 1: Validaciones pre-deployment
# ============================================================================
log_info "🔍 Validando entorno..."

# Verificar que estamos en el servidor correcto
if [ ! -d "/opt/codespartan" ]; then
    log_error "Este script debe ejecutarse en el VPS de producción"
    exit 1
fi

# Verificar que Docker está corriendo
if ! docker info >/dev/null 2>&1; then
    log_error "Docker no está corriendo"
    exit 1
fi

# Verificar que la red 'web' existe
if ! docker network ls | grep -q "web"; then
    log_error "La red 'web' no existe. Debe crearse primero."
    exit 1
fi

log_info "✅ Validaciones completadas"

# ============================================================================
# PASO 2: Backup de configuración actual
# ============================================================================
log_info "💾 Creando backup de configuración actual..."

mkdir -p "$BACKUP_DIR"
cp -r "$TRAEFIK_DIR" "$BACKUP_DIR/"

log_info "✅ Backup creado en: $BACKUP_DIR"

# ============================================================================
# PASO 3: Deploy docker-socket-proxy
# ============================================================================
log_info "🚀 Desplegando docker-socket-proxy..."

cd "$SCRIPT_DIR"

# Deploy docker-socket-proxy (la red se crea automáticamente)
log_info "Iniciando docker-socket-proxy..."
docker compose up -d

# ============================================================================
# PASO 4: Health check docker-socket-proxy
# ============================================================================
log_info "🔍 Verificando health de docker-socket-proxy..."

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' docker-socket-proxy 2>/dev/null || echo "unknown")

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        log_info "✅ docker-socket-proxy está healthy"
        break
    fi

    if [ $ATTEMPT -eq $((MAX_ATTEMPTS - 1)) ]; then
        log_error "docker-socket-proxy no pasó el health check"
        log_error "$(docker logs docker-socket-proxy --tail 50)"

        log_warn "🔄 Iniciando rollback..."
        docker compose down --volumes --remove-orphans
        exit 1
    fi

    echo -n "."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

# ============================================================================
# PASO 5: Actualizar Traefik
# ============================================================================
log_info "🔄 Actualizando configuración de Traefik..."

cd "$TRAEFIK_DIR"

# Recrear Traefik con nueva configuración
log_info "Recreando contenedor de Traefik..."
docker compose down --remove-orphans
# Forzar eliminación de contenedores huérfanos
docker rm -f traefik 2>/dev/null || true
docker compose up -d

# ============================================================================
# PASO 6: Health check Traefik
# ============================================================================
log_info "🔍 Verificando health de Traefik..."

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' traefik 2>/dev/null || echo "unknown")

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        log_info "✅ Traefik está healthy"
        break
    fi

    if [ $ATTEMPT -eq $((MAX_ATTEMPTS - 1)) ]; then
        log_error "Traefik no pasó el health check"
        log_error "$(docker logs traefik --tail 50)"

        log_warn "🔄 Iniciando rollback completo..."

        # Restaurar Traefik
        cd "$TRAEFIK_DIR"
        docker compose down --remove-orphans
        docker rm -f traefik 2>/dev/null || true
        cp -r "$BACKUP_DIR/traefik/"* "$TRAEFIK_DIR/"
        docker compose up -d

        # Eliminar docker-socket-proxy (y su red)
        cd "$SCRIPT_DIR"
        docker compose down --volumes --remove-orphans

        log_error "Rollback completado. Revisa los logs para más detalles."
        exit 1
    fi

    echo -n "."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

# ============================================================================
# PASO 7: Verificación de conectividad
# ============================================================================
log_info "🔍 Verificando conectividad de Traefik al Docker API..."

# Verificar que Traefik puede listar contenedores
if docker logs traefik 2>&1 | grep -q "Provider connection established"; then
    log_info "✅ Traefik conectado exitosamente a docker-socket-proxy"
else
    log_warn "⚠️  No se encontró mensaje de conexión. Verificando manualmente..."

    # Dar 10 segundos más
    sleep 10

    if docker logs traefik 2>&1 | grep -qi "error.*docker"; then
        log_error "Traefik tiene errores conectándose al Docker API"
        log_error "$(docker logs traefik --tail 20)"

        log_warn "🔄 Iniciando rollback..."
        cd "$TRAEFIK_DIR"
        docker compose down --remove-orphans
        docker rm -f traefik 2>/dev/null || true
        cp -r "$BACKUP_DIR/traefik/"* "$TRAEFIK_DIR/"
        docker compose up -d

        cd "$SCRIPT_DIR"
        docker compose down --volumes --remove-orphans

        exit 1
    else
        log_info "✅ No se detectaron errores. Traefik parece funcionar correctamente."
    fi
fi

# ============================================================================
# PASO 8: Test de routing
# ============================================================================
log_info "🔍 Probando routing de Traefik..."

if curl -f -s -o /dev/null -w "%{http_code}" http://localhost:8080/ping | grep -q "200"; then
    log_info "✅ Traefik responde correctamente"
else
    log_error "Traefik no responde al ping endpoint"
    exit 1
fi

# ============================================================================
# PASO 9: Limpieza
# ============================================================================
log_info "🧹 Limpiando backups antiguos..."

# Mantener solo los últimos 3 backups
cd /tmp
ls -t | grep "traefik-backup-" | tail -n +4 | xargs -r rm -rf

# ============================================================================
# SUCCESS
# ============================================================================
log_info ""
log_info "════════════════════════════════════════════════════════════"
log_info "✨ FASE 1 completada exitosamente ✨"
log_info "════════════════════════════════════════════════════════════"
log_info ""
log_info "🔒 docker-socket-proxy desplegado y funcionando"
log_info "🚪 Traefik actualizado para usar TCP endpoint"
log_info "🛡️  Socket de Docker ahora protegido (solo operaciones GET)"
log_info ""
log_info "📋 Próximos pasos:"
log_info "  1. Verificar en https://traefik.mambo-cloud.com que todo funciona"
log_info "  2. Monitorear logs: docker logs traefik -f"
log_info "  3. Continuar con FASE 2: Authelia SSO"
log_info ""
log_info "💾 Backup disponible en: $BACKUP_DIR"
log_info "════════════════════════════════════════════════════════════"
