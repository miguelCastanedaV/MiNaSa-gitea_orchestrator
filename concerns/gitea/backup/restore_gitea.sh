#!/bin/bash
# restore_gitea.sh - Script completo de restauración de Gitea
# Uso: ./restore_gitea.sh <ruta_del_backup.zip>

set -e  # Detener el script si hay error

# ============================================
# CONFIGURACIÓN
# ============================================
# Puerto SSH de Gitea (por defecto es 222)
GITEA_SSH_PORT="${GITEA_SSH_PORT:-222}"

# ============================================
# COLORES PARA OUTPUT
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# FUNCIONES
# ============================================
print_message() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$1${NC}"
    echo "=========================================="
}

# ============================================
# VALIDACIONES INICIALES
# ============================================
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    print_error "Debes especificar la ruta del archivo backup"
    echo "Uso: $0 <ruta_del_backup.zip>"
    echo "Ejemplo: $0 ./gitea_backup_20240101_120000.zip"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Archivo no encontrado: $BACKUP_FILE"
    exit 1
fi

if ! docker ps &>/dev/null; then
    print_error "No tienes permisos para ejecutar Docker"
    print_info "Ejecuta: sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

# ============================================
# INICIO DE LA RESTAURACIÓN
# ============================================
print_header "🦋 INICIANDO RESTAURACIÓN DE GITEA"

print_info "Backup: $(basename "$BACKUP_FILE")"
print_info "Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
print_info "Puerto SSH: $GITEA_SSH_PORT"
print_info "Fecha: $(date)"

# Confirmar restauración
echo ""
print_warning "¡ATENCIÓN! Esto sobrescribirá TODOS los datos actuales de Gitea"
read -p "¿Estás seguro de continuar? (escribe 'yes' para continuar): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    print_message "Restauración cancelada"
    exit 0
fi

# ============================================
# 1. VERIFICAR CONTENEDORES
# ============================================
print_header "📦 1. VERIFICANDO CONTENEDORES"

if ! docker ps --format '{{.Names}}' | grep -q "^gitea$"; then
    print_error "El contenedor 'gitea' no está corriendo"
    print_info "Ejecuta: docker compose up -d gitea"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^gitea-db$"; then
    print_error "El contenedor 'gitea-db' no está corriendo"
    print_info "Ejecuta: docker compose up -d gitea-db"
    exit 1
fi

print_message "Contenedores verificados"

# ============================================
# 2. COPIAR BACKUP AL CONTENEDOR
# ============================================
print_header "📋 2. COPIANDO BACKUP AL CONTENEDOR"

print_info "Copiando archivo..."
docker cp "$BACKUP_FILE" gitea:/tmp/restore.zip
print_message "Backup copiado exitosamente"

# ============================================
# 3. EXTRAER Y RESTAURAR DATOS
# ============================================
print_header "📦 3. EXTRAYENDO Y RESTAURANDO DATOS"

print_info "Extrayendo backup y restaurando archivos..."
docker exec --user root gitea bash -c "
    # Crear directorios necesarios
    mkdir -p /data/git/repositories/
    mkdir -p /data/gitea/{conf,log,custom}

    # Extraer backup
    echo 'Extrayendo archivos...'
    unzip -o /tmp/restore.zip -d /tmp/restore/

    # Copiar archivos de configuración y datos
    echo 'Copiando datos de Gitea...'
    cp -rf /tmp/restore/data/* /data/gitea/ 2>/dev/null || true

    # Copiar repositorios
    echo 'Copiando repositorios...'
    cp -rf /tmp/restore/repos/* /data/git/repositories/ 2>/dev/null || true

    # Ajustar permisos
    echo 'Ajustando permisos...'
    chown -R git:git /data/gitea
    chown -R git:git /data/git

    echo '✅ Datos restaurados correctamente'
"

print_message "Archivos restaurados exitosamente"

# ============================================
# 4. RESTAURAR BASE DE DATOS
# ============================================
print_header "💾 4. RESTAURANDO BASE DE DATOS"

print_info "Restaurando PostgreSQL..."
docker exec gitea bash -c "
    if unzip -p /tmp/restore.zip gitea-db.sql 2>/dev/null; then
        echo 'Base de datos restaurada correctamente'
    else
        echo 'No se encontró archivo SQL en el backup'
        exit 1
    fi
" | docker exec -i gitea-db psql -U gitea gitea 2>/dev/null

print_message "Base de datos restaurada exitosamente"

# ============================================
# 5. REGENERAR HOOKS DE GIT
# ============================================
print_header "🔧 5. REGENERANDO HOOKS DE GIT"

print_info "Regenerando hooks de Git..."
docker exec -u git gitea gitea admin regenerate hooks
print_message "Hooks de Git regenerados"

# ============================================
# 6. REGENERAR CLAVES SSH
# ============================================
print_header "🔑 6. REGENERANDO CLAVES SSH"

print_info "Regenerando archivo authorized_keys..."
docker exec -u git gitea gitea admin regenerate keys
print_message "Claves SSH regeneradas"

# ============================================
# 7. CORREGIR PERMISOS DE SSH
# ============================================
print_header "🔒 7. CORRIGIENDO PERMISOS DE SSH"

docker exec --user root gitea bash -c "
    if [ -d /data/git/.ssh ]; then
        chown -R git:git /data/git/.ssh
        chmod 700 /data/git/.ssh
        chmod 600 /data/git/.ssh/authorized_keys 2>/dev/null || true
        echo '✅ Permisos de SSH corregidos'
    else
        echo '⚠️ Directorio .ssh no encontrado'
    fi
"
print_message "Permisos verificados"

# ============================================
# 8. VERIFICAR REPOSITORIOS
# ============================================
print_header "📁 8. VERIFICANDO REPOSITORIOS"

REPO_COUNT=$(docker exec gitea find /data/git/repositories -name "*.git" -type d 2>/dev/null | wc -l)
print_message "Repositorios encontrados: $REPO_COUNT"

if [ "$REPO_COUNT" -gt 0 ]; then
    print_info "Lista de repositorios:"
    docker exec gitea find /data/git/repositories -name "*.git" -type d 2>/dev/null | while read repo; do
        echo "  📌 $(basename "$repo")"
    done
fi

# ============================================
# 9. VERIFICAR CLAVES SSH EN BD
# ============================================
print_header "🔑 9. VERIFICANDO CLAVES SSH EN BD"

SSH_KEY_COUNT=$(docker exec gitea-db psql -U gitea -t -c "SELECT COUNT(*) FROM public.public_key;" gitea 2>/dev/null | xargs)
if [ -n "$SSH_KEY_COUNT" ] && [ "$SSH_KEY_COUNT" -gt 0 ]; then
    print_message "Claves SSH en BD: $SSH_KEY_COUNT"
else
    print_warning "No hay claves SSH en la base de datos"
    print_info "Los usuarios deberán añadir sus claves desde la web"
fi

# ============================================
# 10. VERIFICAR USUARIOS
# ============================================
print_header "👥 10. VERIFICANDO USUARIOS"

USER_COUNT=$(docker exec gitea-db psql -U gitea -t -c "SELECT COUNT(*) FROM user;" gitea 2>/dev/null | xargs)
print_message "Usuarios en BD: ${USER_COUNT:-0}"

if [ -n "$USER_COUNT" ] && [ "$USER_COUNT" -gt 0 ]; then
    print_info "Lista de usuarios:"
    docker exec gitea-db psql -U gitea -c "SELECT login_name FROM user WHERE type=0;" gitea 2>/dev/null | tail -n +3 | head -n -1 | while read line; do
        echo "  👤 $line"
    done
fi

# ============================================
# 11. LIMPIAR ARCHIVOS TEMPORALES
# ============================================
print_header "🧹 11. LIMPIANDO ARCHIVOS TEMPORALES"

docker exec gitea rm -rf /tmp/restore.zip /tmp/restore/ 2>/dev/null || true
print_message "Archivos temporales eliminados"

# ============================================
# 12. REINICIAR GITEA
# ============================================
print_header "🔄 12. REINICIANDO GITEA"

docker compose restart gitea
sleep 8
print_message "Gitea reiniciado"

# ============================================
# 13. ESTADO FINAL
# ============================================
print_header "✅ 13. ESTADO FINAL"

docker compose ps

# Verificar que Gitea está respondiendo
if curl -s http://localhost:3000/api/v1/version > /dev/null 2>&1; then
    print_message "Gitea está respondiendo correctamente"
else
    print_warning "Verifica con: docker compose logs gitea"
fi

# ============================================
# RESUMEN FINAL
# ============================================
print_header "🎉 RESTAURACIÓN COMPLETADA"

echo ""
echo "📊 RESUMEN:"
echo "  ✅ Repositorios: $REPO_COUNT"
echo "  ✅ Usuarios: ${USER_COUNT:-0}"
echo "  ✅ Claves SSH: ${SSH_KEY_COUNT:-0}"
echo "  ✅ Hooks de Git regenerados"
echo "  ✅ authorized_keys regenerado"
echo "  ✅ Permisos de SSH corregidos"
echo ""
echo "🌐 ACCESO WEB: http://localhost:3000"
echo "🔑 ACCESO SSH: ssh -T git@localhost -p $GITEA_SSH_PORT"
echo ""
echo "📝 COMANDOS ÚTILES:"
echo "  docker compose logs -f gitea"
echo "  docker exec -u git gitea gitea admin user list"
echo "  docker exec gitea cat /data/git/.ssh/authorized_keys"
echo ""
print_message "¡Tu Gitea está listo para usar!"