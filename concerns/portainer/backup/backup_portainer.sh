#!/bin/bash

# Obtener el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# El backup se guardará en el mismo directorio del script (no en subcarpeta)
BACKUP_DIR="$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="portainer_backup_${TIMESTAMP}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "=========================================="
echo "🐳 Iniciando respaldo de Portainer"
echo "🕒 Fecha: $(date)"
echo "📁 Contenedor: portainer"
echo "💾 Destino: $BACKUP_PATH"
echo "=========================================="
echo ""

# Verificar que el contenedor esté corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
    echo "❌ Error: El contenedor 'portainer' no está corriendo"
    echo "   Por favor, inicia el servicio con: docker compose up -d portainer"
    exit 1
fi

# Detener el contenedor para consistencia
echo "⏸️  Deteniendo contenedor portainer para garantizar consistencia..."
docker stop portainer

echo ""
echo "📦 Creando respaldo del volumen portainer_data..."
docker run --rm \
    -v portainer_data:/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine sh -c "
        echo '📊 Calculando tamaño original...'
        du -sh /source 2>/dev/null
        echo ''
        echo '🗜️  Comprimiendo directamente...'
        tar -czf '/backup/${BACKUP_NAME}' -C /source .
    "

# Verificar si se creó el archivo
if [ $? -eq 0 ] && [ -f "$BACKUP_PATH" ]; then
    # Cambiar propietario del archivo al usuario actual del host
    echo ""
    echo "🔐 Ajustando permisos del archivo para el usuario actual..."
    sudo chown "$(id -u):$(id -g)" "$BACKUP_PATH" 2>/dev/null || chown "$(id -u):$(id -g)" "$BACKUP_PATH"
else
    echo ""
    echo "❌ Error: Falló la generación del respaldo"
    docker start portainer
    exit 1
fi

echo ""
echo "▶️  Re-iniciando contenedor portainer..."
docker start portainer

echo ""
echo "=========================================="
echo "✅ RESPALDO DE PORTAINER COMPLETADO"
echo "=========================================="
echo "📦 Archivo: $BACKUP_PATH"
echo "📊 Tamaño: $(du -h "$BACKUP_PATH" | cut -f1)"
echo "🔐 Permisos: $(ls -l "$BACKUP_PATH" | awk '{print $1, $3, $4}')"
echo "🕒 Fecha: $(date)"
echo "=========================================="
