#!/bin/bash
# delete-registry-image.sh
# Script para eliminar una imagen del registro Docker y limpiar residuos

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Configuración
REGISTRY_URL="minasa.local:5000"
REGISTRY_CONTAINER="gitea-registry"
NAMESPACE="gestionasig"  # Ajusta según tu namespace

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funciones auxiliares
print_header() {
    echo -e "\n${PURPLE}╭────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${BOLD}  $1${NC}"
    echo -e "${PURPLE}╰────────────────────────────────────────────────────╯${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Función para mostrar uso
usage() {
    echo -e "${BOLD}USO:${NC}"
    echo "  $0 <imagen> <tag>"
    echo ""
    echo -e "${BOLD}EJEMPLOS:${NC}"
    echo "  $0 gs-phva-web latest"
    echo "  $0 gs-phva-worker v1.2.3"
    echo "  $0 gs-phva-web uat-1.0.0"
    echo ""
    echo -e "${BOLD}DESCRIPCIÓN:${NC}"
    echo "  Elimina una imagen específica del registro Docker y ejecuta"
    echo "  garbage collection junto con limpieza de repositorios vacíos."
    exit 1
}

# Función para obtener el digest del manifiesto
get_manifest_digest() {
    local image="$1"
    local tag="$2"

    # Obtener el digest del manifiesto desde los headers
    local digest
    digest=$(curl -s -I -X GET \
        "http://${REGISTRY_URL}/v2/${image}/manifests/${tag}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        2>/dev/null | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')

    echo "$digest"
}

# Función para eliminar la imagen
delete_image() {
    local image="$1"
    local tag="$2"
    local digest="$3"

    print_info "Eliminando imagen ${image}:${tag}..."

    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "http://${REGISTRY_URL}/v2/${image}/manifests/${digest}")

    if [ "$response" = "202" ] || [ "$response" = "200" ]; then
        print_success "Imagen eliminada correctamente (HTTP $response)"
        return 0
    else
        print_error "Error al eliminar imagen (HTTP $response)"
        return 1
    fi
}

# Función para mostrar información de la imagen
show_image_info() {
    local image="$1"
    local tag="$2"

    print_info "Obteniendo información de ${image}:${tag}..."

    # Obtener el manifiesto completo
    local manifest
    manifest=$(curl -s -X GET \
        "http://${REGISTRY_URL}/v2/${image}/manifests/${tag}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json")

    # Mostrar resumen
    local layers
    layers=$(echo "$manifest" | jq '.layers | length' 2>/dev/null)
    local size
    size=$(echo "$manifest" | jq '[.layers[].size] | add' 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "desconocido")

    echo -e "  📦 Capas: ${layers:-desconocido}"
    echo -e "  💾 Tamaño total: ${size}"
}

# Función para verificar que la imagen existe
check_image_exists() {
    local image="$1"
    local tag="$2"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://${REGISTRY_URL}/v2/${image}/manifests/${tag}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json")

    if [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Función para listar imágenes disponibles
list_available_images() {
    print_info "Imágenes disponibles en el registro:"

    local repos
    repos=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]' 2>/dev/null)

    if [ -z "$repos" ]; then
        echo "  No hay imágenes en el registro"
        return
    fi

    for repo in $repos; do
        local tags
        tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]' 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
        if [ -n "$tags" ]; then
            echo -e "  📦 ${YELLOW}${repo}${NC}: ${tags}"
        fi
    done
}

# Función principal
main() {
    print_header "ELIMINACIÓN DE IMAGEN DEL REGISTRO DOCKER"

    # Verificar argumentos
    if [ $# -ne 2 ]; then
        print_error "Número incorrecto de argumentos"
        list_available_images
        usage
    fi

    IMAGE="$1"
    TAG="$2"

    # Verificar que jq está instalado
    if ! command -v jq &> /dev/null; then
        print_warning "jq no está instalado. Algunas funciones serán limitadas."
    fi

    # Verificar conectividad con el registro
    print_info "Verificando conectividad con el registro ${REGISTRY_URL}..."
    if ! curl -s "http://${REGISTRY_URL}/v2/" > /dev/null; then
        print_error "No se puede conectar al registro"
        exit 1
    fi
    print_success "Conexión exitosa"

    # Verificar que la imagen existe
    print_info "Verificando existencia de ${IMAGE}:${TAG}..."
    if ! check_image_exists "$IMAGE" "$TAG"; then
        print_error "La imagen ${IMAGE}:${TAG} no existe en el registro"
        list_available_images
        exit 1
    fi
    print_success "Imagen encontrada"

    # Mostrar información de la imagen
    show_image_info "$IMAGE" "$TAG"

    # Obtener el digest del manifiesto
    print_info "Obteniendo digest del manifiesto..."
    DIGEST=$(get_manifest_digest "$IMAGE" "$TAG")

    if [ -z "$DIGEST" ]; then
        print_error "No se pudo obtener el digest del manifiesto"
        exit 1
    fi
    print_success "Digest: ${DIGEST}"

    # Confirmar eliminación
    echo -e "\n${YELLOW}${BOLD}⚠️  ¿Estás seguro de eliminar ${IMAGE}:${TAG}?${NC}"
    echo -e "    Digest: ${BLUE}${DIGEST}${NC}"
    echo -n "Escribe 'YES' para confirmar: "
    read -r confirm

    if [ "$confirm" != "YES" ]; then
        print_warning "Operación cancelada por el usuario"
        exit 0
    fi

    # Eliminar la imagen
    echo ""
    if ! delete_image "$IMAGE" "$TAG" "$DIGEST"; then
        print_error "No se pudo eliminar la imagen"
        exit 1
    fi

    # Verificar que se eliminó
    print_info "Verificando eliminación..."
    sleep 2
    if check_image_exists "$IMAGE" "$TAG"; then
        print_warning "La imagen aún aparece en el registro"
    else
        print_success "La imagen ya no está disponible vía API"
    fi

    # PASO 2: Ejecutar garbage collection
    print_header "PASO 2: GARBAGE COLLECTION"
    print_info "Ejecutando garbage collection en contenedor ${REGISTRY_CONTAINER}..."

    # Verificar que el contenedor existe
    if ! docker ps | grep -q "$REGISTRY_CONTAINER"; then
        print_error "Contenedor $REGISTRY_CONTAINER no está corriendo"
    else
        # Mostrar espacio antes
        echo -e "\n${BLUE}Espacio antes de GC:${NC}"
        docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry 2>/dev/null || echo "No disponible"

        # Ejecutar dry-run primero
        echo -e "\n${YELLOW}Simulación (dry-run):${NC}"
        docker exec $REGISTRY_CONTAINER registry garbage-collect --dry-run /etc/docker/registry/config.yml

        # Preguntar si ejecutar GC real
        echo -e "\n${YELLOW}¿Ejecutar garbage collection real? (s/n)${NC}"
        read -r gc_confirm

        if [[ "$gc_confirm" =~ ^[sS]$ ]]; then
            echo -e "\n${YELLOW}Ejecutando garbage collection...${NC}"
            docker exec $REGISTRY_CONTAINER registry garbage-collect /etc/docker/registry/config.yml

            # Mostrar espacio después
            echo -e "\n${GREEN}Espacio después de GC:${NC}"
            docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry 2>/dev/null || echo "No disponible"

            print_success "Garbage collection completado"
        else
            print_warning "Garbage collection omitido"
        fi
    fi

    # PASO 3: Limpiar repositorios vacíos
    print_header "PASO 3: LIMPIEZA DE REPOSITORIOS VACÍOS"

    # Verificar si existe el script cleanup-empty-repos
    CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-empty-repos.sh"

    if [ -f "$CLEANUP_SCRIPT" ]; then
        print_info "Ejecutando limpieza de repositorios vacíos..."
        bash "$CLEANUP_SCRIPT"
    else
        print_warning "Script cleanup-empty-repos.sh no encontrado en $CLEANUP_SCRIPT"
        print_info "Ejecutando limpieza manual básica..."

        # Limpieza manual básica
        echo -e "\n${BLUE}Repositorios actuales:${NC}"
        curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq '.' 2>/dev/null || echo "Error al obtener catálogo"

        echo -e "\n${YELLOW}Verificando repositorios sin tags...${NC}"
        repos=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]' 2>/dev/null)

        for repo in $repos; do
            tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]?' 2>/dev/null)
            if [ -z "$tags" ]; then
                echo -e "  ⚠️  ${YELLOW}$repo${NC}: VACÍO"
                echo "     ¿Eliminar? (s/n): "
                read -r del_repo
                if [[ "$del_repo" =~ ^[sS]$ ]]; then
                    docker exec $REGISTRY_CONTAINER rm -rf "/var/lib/registry/docker/registry/v2/repositories/${repo}"
                    print_success "Repositorio $repo eliminado"
                fi
            fi
        done
    fi

    # Resultado final
    print_header "RESUMEN FINAL"

    echo -e "${BLUE}Catálogo actualizado:${NC}"
    curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq '.' 2>/dev/null || echo "No disponible"

    echo -e "\n${BLUE}Espacio en disco del registro:${NC}"
    docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry 2>/dev/null || echo "No disponible"

    print_success "Proceso completado exitosamente"
}

# Ejecutar función principal
main "$@"
