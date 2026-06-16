#!/bin/bash
# restore_registry_images.sh - Restaura las imágenes del Docker Registry desde un backup
# Uso: ./restore_registry_images.sh [archivo_respaldo.tar.gz]

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
REGISTRY_VOLUME="minasa-registry-data"
REGISTRY_CONTAINER="gitea-registry"

# Obtener el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR"

# ============================================
# COLORES PARA OUTPUT
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }

# ============================================
# BUSCAR O VALIDAR ARCHIVO DE BACKUP
# ============================================
if [ -z "$1" ]; then
    BACKUP_FILE=$(ls -t ${BACKUP_DIR}/registry_backup_*.tar.gz 2>/dev/null | head -n1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "=========================================="
        echo "❌ ERROR: No se encontró ningún respaldo"
        echo "=========================================="
        echo "   Buscado en: $BACKUP_DIR"
        echo "   Patrón: registry_backup_*.tar.gz"
        echo "   Uso: $0 [archivo_respaldo.tar.gz]"
        exit 1
    fi
else
    BACKUP_FILE="$1"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "=========================================="
    echo "❌ ERROR: Archivo no encontrado"
    echo "=========================================="
    echo "   Archivo: $BACKUP_FILE"
    exit 1
fi

BACKUP_NAME=$(basename "$BACKUP_FILE")

echo "=========================================="
echo "📦 Iniciando restauración del Registry"
echo "🕒 Fecha: $(date)"
echo "📁 Contenedor: $REGISTRY_CONTAINER"
echo "💾 Volumen: $REGISTRY_VOLUME"
echo "📦 Respaldo: $BACKUP_NAME"
echo "=========================================="
echo ""

# ============================================
# DETENER CONTENEDOR SI ESTÁ CORRIENDO
# ============================================
if docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_CONTAINER}$"; then
    echo "⏸️  Deteniendo contenedor $REGISTRY_CONTAINER..."
    docker stop "$REGISTRY_CONTAINER"
    print_message "Contenedor detenido"
fi

echo ""
echo "⚠️  ATENCIÓN: Se eliminará el volumen actual '$REGISTRY_VOLUME'"
echo "   Esto borrará TODAS las imágenes del registry actual"
echo ""
read -p "   ¿Estás seguro de continuar? (escribe 'yes' para confirmar): " confirm
if [ "$confirm" != "yes" ]; then
    echo ""
    echo "❌ Restauración cancelada por el usuario"
    exit 0
fi

# ============================================
# ELIMINAR Y RECREAR VOLUMEN
# ============================================
echo ""
echo "🗑️  Eliminando volumen antiguo $REGISTRY_VOLUME..."
docker volume rm "$REGISTRY_VOLUME" 2>/dev/null && print_message "Volumen eliminado" || print_info "Volumen no existía"

echo "📦 Creando nuevo volumen $REGISTRY_VOLUME..."
docker volume create "$REGISTRY_VOLUME" >/dev/null
print_message "Volumen creado"

# ============================================
# RESTAURAR BACKUP
# ============================================
echo ""
echo "📀 Restaurando datos desde el respaldo..."
echo "   ⏳ Esto puede tomar unos minutos dependiendo del tamaño..."

docker run --rm \
    -v "$REGISTRY_VOLUME":/target \
    -v "$BACKUP_DIR":/backup:ro \
    alpine sh -c "
        BACKUP_FILE=\"/backup/$(basename "$BACKUP_FILE")\"

        echo '📊 Extrayendo archivos...'
        tar -xzf \"\$BACKUP_FILE\" -C /target --no-same-owner 2>/dev/null || tar -xzf \"\$BACKUP_FILE\" -C /target

        echo '✅ Extracción completada'
        echo ''
        echo '📊 Verificando tamaño restaurado...'
        du -sh /target
    "

if [ $? -eq 0 ]; then
    echo ""
    echo "🔧 Ajustando permisos para el registry..."
    docker run --rm \
        -v "$REGISTRY_VOLUME":/target \
        alpine sh -c "
            chmod -R 755 /target 2>/dev/null || true
            chown -R 1000:1000 /target 2>/dev/null || true
        "
    print_message "Permisos ajustados"

    echo ""
    echo "=========================================="
    echo "✅ RESTAURACIÓN COMPLETADA"
    echo "=========================================="
    echo "📦 Volumen: $REGISTRY_VOLUME"
    echo "📦 Backup: $BACKUP_NAME"
    echo "🕒 Fecha: $(date)"
    echo ""
    echo "📊 Verificando contenido restaurado:"

    # Verificar estructura
    docker run --rm -v "$REGISTRY_VOLUME":/source:ro alpine ls -la /source/ 2>/dev/null | head -5

    # Contar repositorios
    REPO_COUNT=$(docker run --rm -v "$REGISTRY_VOLUME":/source:ro alpine sh -c "ls -1 /source/docker/registry/v2/repositories/ 2>/dev/null | wc -l")
    echo "   📁 Repositorios encontrados: ${REPO_COUNT:-0}"

    echo ""
    echo "▶️  Ahora puedes levantar el Registry con:"
    echo "   docker compose up -d gitea-registry"
    echo ""
    echo "🔍 Para verificar:"
    echo "   curl http://localhost:5000/v2/_catalog"
    echo "=========================================="
else
    echo ""
    echo "❌ Error: Falló la restauración del respaldo"
    exit 1
fi