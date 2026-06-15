#!/bin/bash
# registry-cleanup.sh
# Punto de entrada unificado para todas las operaciones de limpieza del registro Docker

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuración
REGISTRY_URL="minasa.local:5000"
REGISTRY_CONTAINER="gitea-registry"
NAMESPACE="gestionasig"

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar que los scripts existen
DELETE_IMAGE_SCRIPT="${SCRIPT_DIR}/delete-registry-image.sh"
DELETE_ALL_TAGS_SCRIPT="${SCRIPT_DIR}/delete-all-tags.sh"
DELETE_REPO_SCRIPT="${SCRIPT_DIR}/delete-repository.sh"
CLEANUP_GC_SCRIPT="${SCRIPT_DIR}/cleanup-gitea-registry.sh"
CLEANUP_EMPTY_SCRIPT="${SCRIPT_DIR}/cleanup-empty-repos.sh"

# Función para mostrar el header
show_header() {
    clear
    echo -e "${PURPLE}╭────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${BOLD}     🐳 REGISTRY DOCKER - HERRAMIENTAS DE LIMPIEZA  ${NC}${PURPLE}│${NC}"
    echo -e "${PURPLE}╰────────────────────────────────────────────────────╯${NC}"
    echo ""
    echo -e "${CYAN}Registro:${NC} ${REGISTRY_URL}"
    echo -e "${CYAN}Contenedor:${NC} ${REGISTRY_CONTAINER}"
    echo ""
}

# Función para mostrar el menú principal
show_menu() {
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║            🎯 SELECCIONA UNA OPCIÓN              ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Eliminar un tag específico${NC}"
    echo -e "     ${BLUE}→ Usa:${NC} delete-registry-image.sh (elimina un tag + GC + limpieza)"
    echo ""
    echo -e "  ${GREEN}2)${NC} ${BOLD}Eliminar TODOS los tags de una imagen${NC}"
    echo -e "     ${BLUE}→ Usa:${NC} delete-all-tags.sh (elimina todos los tags de un repositorio)"
    echo ""
    echo -e "  ${GREEN}3)${NC} ${BOLD}Eliminar un repositorio COMPLETO${NC}"
    echo -e "     ${BLUE}→ Usa:${NC} delete-repository.sh (elimina todo el repositorio + GC)"
    echo ""
    echo -e "  ${GREEN}4)${NC} ${BOLD}Garbage Collection solamente${NC}"
    echo -e "     ${BLUE}→ Usa:${NC} cleanup-gitea-registry.sh (solo GC, sin eliminar imágenes)"
    echo ""
    echo -e "  ${GREEN}5)${NC} ${BOLD}Limpiar repositorios vacíos${NC}"
    echo -e "     ${BLUE}→ Usa:${NC} cleanup-empty-repos.sh (elimina repos sin tags)"
    echo ""
    echo -e "  ${GREEN}6)${NC} ${BOLD}Ver estado actual del registro${NC}"
    echo -e "     ${BLUE}→ Muestra:${NC} catálogo, espacio usado, tags disponibles"
    echo ""
    echo -e "  ${GREEN}7)${NC} ${BOLD}Ejecutar limpieza COMPLETA${NC}"
    echo -e "     ${BLUE}→ Secuencia:${NC} GC → Limpieza repos vacíos → Verificación"
    echo ""
    echo -e "  ${RED}0)${NC} Salir"
    echo ""
    echo -n "Opción: "
}

# Función para verificar conectividad
check_connectivity() {
    echo -e "\n${BLUE}🔍 Verificando conectividad...${NC}"
    if curl -s "http://${REGISTRY_URL}/v2/" > /dev/null; then
        echo -e "${GREEN}✅ Conexión exitosa${NC}"
        return 0
    else
        echo -e "${RED}❌ No se puede conectar al registro${NC}"
        return 1
    fi
}

# Función para ver estado del registro
show_status() {
    echo -e "\n${YELLOW}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}📊 ESTADO DEL REGISTRO${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════${NC}"

    # Verificar conectividad
    if ! check_connectivity; then
        return 1
    fi

    # Mostrar catálogo
    echo -e "\n${CYAN}📋 Catálogo de repositorios:${NC}"
    local repos
    repos=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]?' 2>/dev/null)

    if [ -z "$repos" ]; then
        echo "   No hay repositorios"
    else
        for repo in $repos; do
            local tags
            tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]?' 2>/dev/null | tr '\n' ' ')
            if [ -n "$tags" ]; then
                echo -e "   📦 ${GREEN}${repo}${NC}: ${tags}"
            else
                echo -e "   📦 ${YELLOW}${repo}${NC}: ${RED}(vacío)${NC}"
            fi
        done
    fi

    # Mostrar espacio en disco
    echo -e "\n${CYAN}💾 Espacio en disco:${NC}"
    if docker ps | grep -q "$REGISTRY_CONTAINER"; then
        local space
        space=$(docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry 2>/dev/null | awk '{print $1}')
        echo -e "   ${BLUE}${space:-No disponible}${NC}"
    else
        echo -e "   ${RED}Contenedor $REGISTRY_CONTAINER no está corriendo${NC}"
    fi

    echo -e "\n${YELLOW}════════════════════════════════════════════════════${NC}"
}

# Función para ejecutar limpieza completa
full_cleanup() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}🧹 EJECUTANDO LIMPIEZA COMPLETA${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════${NC}"

    # Paso 1: Garbage Collection
    echo -e "\n${YELLOW}PASO 1: Garbage Collection${NC}"
    if [ -f "$CLEANUP_GC_SCRIPT" ]; then
        bash "$CLEANUP_GC_SCRIPT"
    else
        echo -e "${RED}❌ Script no encontrado: $CLEANUP_GC_SCRIPT${NC}"
    fi

    # Paso 2: Limpiar repositorios vacíos
    echo -e "\n${YELLOW}PASO 2: Limpieza de repositorios vacíos${NC}"
    if [ -f "$CLEANUP_EMPTY_SCRIPT" ]; then
        bash "$CLEANUP_EMPTY_SCRIPT"
    else
        echo -e "${RED}❌ Script no encontrado: $CLEANUP_EMPTY_SCRIPT${NC}"
    fi

    # Paso 3: Mostrar estado final
    echo -e "\n${YELLOW}PASO 3: Estado final${NC}"
    show_status
}

# Función para verificar si un script existe
check_script() {
    local script="$1"
    local name="$2"

    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Error: Script $name no encontrado en:${NC}"
        echo -e "   $script"
        return 1
    fi
    if [ ! -x "$script" ]; then
        echo -e "${YELLOW}⚠️  Script $name no es ejecutable. Intentando arreglar...${NC}"
        chmod +x "$script"
    fi
    return 0
}

# Función para ejecutar un script con validación
run_script() {
    local script="$1"
    local name="$2"
    shift 2
    local args="$@"

    if check_script "$script" "$name"; then
        echo -e "\n${GREEN}▶ Ejecutando ${name}...${NC}"
        bash "$script" $args
    else
        echo -e "${RED}❌ No se puede ejecutar ${name}${NC}"
        read -p "Presiona Enter para continuar..."
    fi
}

# Función para seleccionar imagen del catálogo
select_image() {
    echo -e "\n${CYAN}📋 Imágenes disponibles:${NC}"
    local repos
    repos=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]?' 2>/dev/null)

    if [ -z "$repos" ]; then
        echo "   No hay imágenes disponibles"
        return 1
    fi

    local i=1
    declare -A repo_map

    for repo in $repos; do
        local tags
        tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]?' 2>/dev/null | head -3 | tr '\n' ' ')
        echo -e "   ${GREEN}$i)${NC} ${repo} ${BLUE}[tags: ${tags:-sin tags}]${NC}"
        repo_map[$i]="$repo"
        ((i++))
    done

    echo -n -e "\n${YELLOW}Selecciona número (0 para cancelar):${NC} "
    read -r selection

    if [ "$selection" = "0" ]; then
        return 1
    fi

    if [ -n "${repo_map[$selection]}" ]; then
        SELECTED_IMAGE="${repo_map[$selection]}"
        return 0
    else
        echo -e "${RED}Selección inválida${NC}"
        return 1
    fi
}

# Función para seleccionar tag de una imagen
select_tag() {
    local image="$1"

    echo -e "\n${CYAN}🏷️  Tags disponibles para ${image}:${NC}"
    local tags
    tags=$(curl -s "http://${REGISTRY_URL}/v2/${image}/tags/list" | jq -r '.tags[]?' 2>/dev/null)

    if [ -z "$tags" ]; then
        echo "   No hay tags disponibles"
        return 1
    fi

    local i=1
    declare -A tag_map

    for tag in $tags; do
        echo -e "   ${GREEN}$i)${NC} ${tag}"
        tag_map[$i]="$tag"
        ((i++))
    done

    echo -e "   ${GREEN}*)${NC} ${YELLOW}TODOS los tags${NC}"

    echo -n -e "\n${YELLOW}Selecciona número (0 para cancelar):${NC} "
    read -r selection

    if [ "$selection" = "0" ]; then
        return 1
    fi

    if [ "$selection" = "*" ]; then
        SELECTED_TAG="all"
        return 0
    fi

    if [ -n "${tag_map[$selection]}" ]; then
        SELECTED_TAG="${tag_map[$selection]}"
        return 0
    else
        echo -e "${RED}Selección inválida${NC}"
        return 1
    fi
}

# Función para manejar opción 1: eliminar tag específico
option_delete_tag() {
    echo -e "\n${GREEN}▶ Eliminar un tag específico${NC}"

    if ! check_connectivity; then
        read -p "Presiona Enter para continuar..."
        return
    fi

    if select_image; then
        if select_tag "$SELECTED_IMAGE"; then
            if [ "$SELECTED_TAG" = "all" ]; then
                echo -e "\n${YELLOW}Para eliminar TODOS los tags, usa la opción 2 del menú principal.${NC}"
            else
                run_script "$DELETE_IMAGE_SCRIPT" "delete-registry-image.sh" "$SELECTED_IMAGE" "$SELECTED_TAG"
            fi
        fi
    fi

    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 2: eliminar todos los tags
option_delete_all_tags() {
    echo -e "\n${GREEN}▶ Eliminar TODOS los tags de una imagen${NC}"

    if ! check_connectivity; then
        read -p "Presiona Enter para continuar..."
        return
    fi

    if select_image; then
        run_script "$DELETE_ALL_TAGS_SCRIPT" "delete-all-tags.sh" "$SELECTED_IMAGE"
    fi

    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 3: eliminar repositorio completo
option_delete_repository() {
    echo -e "\n${GREEN}▶ Eliminar repositorio COMPLETO${NC}"

    if ! check_connectivity; then
        read -p "Presiona Enter para continuar..."
        return
    fi

    if select_image; then
        run_script "$DELETE_REPO_SCRIPT" "delete-repository.sh" "$SELECTED_IMAGE"
    fi

    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 4: solo garbage collection
option_garbage_collection() {
    echo -e "\n${GREEN}▶ Garbage Collection solamente${NC}"
    run_script "$CLEANUP_GC_SCRIPT" "cleanup-gitea-registry.sh"
    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 5: limpiar repositorios vacíos
option_cleanup_empty() {
    echo -e "\n${GREEN}▶ Limpiar repositorios vacíos${NC}"
    run_script "$CLEANUP_EMPTY_SCRIPT" "cleanup-empty-repos.sh"
    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 6: ver estado
option_show_status() {
    show_status
    read -p "Presiona Enter para continuar..."
}

# Función para manejar opción 7: limpieza completa
option_full_cleanup() {
    full_cleanup
    read -p "Presiona Enter para continuar..."
}

# Función principal
main() {
    while true; do
        show_header

        # Verificar scripts disponibles
        echo -e "${BLUE}Scripts disponibles:${NC}"
        [ -f "$DELETE_IMAGE_SCRIPT" ] && echo -e "  ${GREEN}✓${NC} delete-registry-image.sh" || echo -e "  ${RED}✗${NC} delete-registry-image.sh"
        [ -f "$DELETE_ALL_TAGS_SCRIPT" ] && echo -e "  ${GREEN}✓${NC} delete-all-tags.sh" || echo -e "  ${RED}✗${NC} delete-all-tags.sh"
        [ -f "$DELETE_REPO_SCRIPT" ] && echo -e "  ${GREEN}✓${NC} delete-repository.sh" || echo -e "  ${RED}✗${NC} delete-repository.sh"
        [ -f "$CLEANUP_GC_SCRIPT" ] && echo -e "  ${GREEN}✓${NC} cleanup-gitea-registry.sh" || echo -e "  ${RED}✗${NC} cleanup-gitea-registry.sh"
        [ -f "$CLEANUP_EMPTY_SCRIPT" ] && echo -e "  ${GREEN}✓${NC} cleanup-empty-repos.sh" || echo -e "  ${RED}✗${NC} cleanup-empty-repos.sh"

        echo ""
        show_menu
        read -r option

        case $option in
            1) option_delete_tag ;;
            2) option_delete_all_tags ;;
            3) option_delete_repository ;;
            4) option_garbage_collection ;;
            5) option_cleanup_empty ;;
            6) option_show_status ;;
            7) option_full_cleanup ;;
            0)
                echo -e "\n${GREEN}¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Opción inválida${NC}"
                sleep 1
                ;;
        esac
    done
}

# Ejecutar función principal
main


# Eliminar imagen en local
# docker rmi $(docker images "minasa.local:5000/gestionasig/public-web" -q) --force
