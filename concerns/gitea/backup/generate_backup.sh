#!/bin/bash

# Obtener el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directorio de backups
BACKUP_DIR="$SCRIPT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${TIMESTAMP}.zip"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "🦋 Iniciando respaldo de Gitea"
echo "🕒 Fecha: $(date)"
echo "📁 Contenedor: gitea"
echo "💾 Destino: $BACKUP_DIR/$BACKUP_NAME"
echo "=========================================="
echo ""

# Verificar que el contenedor esté corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^gitea$"; then
    echo "❌ Error: El contenedor 'gitea' no está corriendo"
    echo "   Por favor, inicia el servicio con: docker compose up -d gitea"
    exit 1
fi

# Ejecutar el dump dentro del contenedor
echo "📦 Generando respaldo dentro del contenedor..."
docker exec -u git gitea gitea dump \
    -c /data/gitea/conf/app.ini \
    --file "/tmp/${BACKUP_NAME}"

# Verificar si el dump se creó correctamente
if [ $? -ne 0 ]; then
    echo "❌ Error: Falló la generación del respaldo en el contenedor"
    exit 1
fi

echo ""
echo "📋 Copiando respaldo desde el contenedor..."
# Copiar el archivo de respaldo del contenedor al host
docker cp "gitea:/tmp/${BACKUP_NAME}" "${BACKUP_DIR}/${BACKUP_NAME}"

# Verificar si la copia fue exitosa
if [ $? -ne 0 ]; then
    echo "❌ Error: Falló la copia del respaldo desde el contenedor"
    exit 1
fi

echo ""
echo "🧹 Limpiando archivo temporal en el contenedor..."
# Eliminar el archivo temporal del contenedor
docker exec gitea rm "/tmp/${BACKUP_NAME}"

echo ""
echo "=========================================="
echo "✅ RESPALDO DE GITEA COMPLETADO"
echo "=========================================="
echo "📦 Archivo: $BACKUP_DIR/$BACKUP_NAME"
echo "📊 Tamaño: $(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)"
echo "🕒 Fecha: $(date)"
echo "=========================================="
