#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR"

# Buscar el archivo de respaldo (puede pasarse como argumento o usar el último)
if [ -z "$1" ]; then
    BACKUP_FILE=$(ls -t ${BACKUP_DIR}/portainer_backup_*.tar.gz 2>/dev/null | head -n1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "=========================================="
        echo "❌ ERROR: No se encontró ningún respaldo"
        echo "=========================================="
        echo "   Buscado en: $BACKUP_DIR"
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
echo "🔄 Iniciando restauración de Portainer"
echo "🕒 Fecha: $(date)"
echo "📁 Contenedor: portainer"
echo "📦 Respaldo: $BACKUP_NAME"
echo "=========================================="
echo ""

# Detener y eliminar contenedor actual si existe
if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
    echo "⏸️  Deteniendo contenedor portainer..."
    docker stop portainer
    echo "🗑️  Eliminando contenedor portainer..."
    docker rm portainer
fi

echo ""
echo "⚠️  ATENCIÓN: Se eliminará el volumen actual 'portainer_data'"
echo "   Esto borrará TODOS los datos actuales de Portainer"
echo "   El contenedor actual será eliminado (luego lo recrearemos con docker compose)"
echo ""
read -p "   ¿Estás seguro de continuar? (escribe 'yes' para confirmar): " confirm
if [ "$confirm" != "yes" ]; then
    echo ""
    echo "❌ Restauración cancelada por el usuario"
    exit 1
fi

echo ""
echo "🗑️  Eliminando volumen antiguo portainer_data..."
docker volume rm portainer_data 2>/dev/null

echo "📦 Creando nuevo volumen portainer_data..."
docker volume create portainer_data >/dev/null

echo ""
echo "📀 Restaurando datos desde el respaldo..."
docker run --rm \
    -v portainer_data:/target \
    -v "$BACKUP_DIR":/backup:ro \
    alpine sh -c "
        echo '📊 Extrayendo archivos...'
        tar -xzf '/backup/${BACKUP_NAME}' -C /target
        echo '✅ Extracción completada'
        echo ''
        echo '📊 Verificando tamaño restaurado...'
        du -sh /target
    "

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ RESTAURACIÓN COMPLETADA"
    echo "=========================================="
    echo "📦 Volumen: portainer_data"
    echo "🕒 Fecha: $(date)"
    echo ""
    echo "▶️  Ahora puedes levantar Portainer con:"
    echo "   docker compose up -d portainer"
    echo "=========================================="
else
    echo ""
    echo "❌ Error: Falló la restauración del respaldo"
    exit 1
fi
