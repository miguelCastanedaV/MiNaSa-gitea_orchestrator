#!/bin/bash

# Obtener UID y GID del usuario actual
USER_UID=$(id -u)
USER_GID=$(id -g)

# Obtener el directorio donde está el script (estará en ./concerns/registry-backup/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# El backup se guardará en el mismo directorio del script
BACKUP_DIR="$SCRIPT_DIR"

# Ejecutar backup
docker run --rm \
  --user "$USER_UID:$USER_GID" \
  -v minasa-registry-data:/source:ro \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME=\"registry_backup_\${TIMESTAMP}.tar.gz\"
    echo '=========================================='
    echo '📦 Iniciando respaldo del registry'
    echo \"🕒 Fecha: \$(date)\"
    echo '📁 Origen: minasa-registry-data'
    echo \"💾 Destino: /backup/\${BACKUP_NAME}\"
    echo '=========================================='
    echo ''
    echo '📊 Calculando tamaño original...'
    du -sh /source
    echo ''
    echo '🗜️  Comprimiendo directamente...'
    tar -czf \"/backup/\${BACKUP_NAME}\" -C /source .
    echo ''
    echo '=========================================='
    echo '✅ RESPALDO COMPLETADO'
    echo '=========================================='
    echo \"📦 Archivo: /backup/\${BACKUP_NAME}\"
    echo \"📊 Tamaño comprimido: \$(du -h \"/backup/\${BACKUP_NAME}\" | cut -f1)\"
    echo '=========================================='
  "
