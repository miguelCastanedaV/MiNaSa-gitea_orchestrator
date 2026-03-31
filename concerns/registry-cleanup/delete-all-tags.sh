#!/bin/bash
# delete-all-tags.sh
# Elimina TODOS los tags de una imagen del registro

REGISTRY_URL="minasa.local:5000"
REGISTRY_CONTAINER="gitea-registry"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -ne 1 ]; then
    echo -e "${RED}Uso: $0 <imagen>${NC}"
    echo "Ejemplo: $0 gs-phva-web"
    echo "         $0 gs-phva-worker"
    exit 1
fi

IMAGE="$1"

echo -e "${YELLOW}🔍 Buscando todos los tags de ${IMAGE}...${NC}"

# Obtener todos los tags
TAGS=$(curl -s "http://${REGISTRY_URL}/v2/${IMAGE}/tags/list" | jq -r '.tags[]?' 2>/dev/null)

if [ -z "$TAGS" ]; then
    echo -e "${RED}❌ No se encontraron tags para ${IMAGE}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Tags encontrados:${NC}"
echo "$TAGS" | sed 's/^/   - /'

# Mostrar resumen
TAG_COUNT=$(echo "$TAGS" | wc -l)
echo -e "\n${YELLOW}📊 Total: ${TAG_COUNT} tags${NC}"

# Confirmar eliminación
echo -e "\n${RED}⚠️  ¿Estás seguro de eliminar TODOS los ${TAG_COUNT} tags de ${IMAGE}?${NC}"
echo -e "Escribe ${YELLOW}DELETE ALL${NC} para confirmar: "
read -r confirm

if [ "$confirm" != "DELETE ALL" ]; then
    echo -e "${RED}❌ Operación cancelada${NC}"
    exit 0
fi

# Eliminar cada tag
echo -e "\n${YELLOW}🗑️  Eliminando tags...${NC}"
FAILED_TAGS=()

for TAG in $TAGS; do
    echo -n "   Eliminando ${IMAGE}:${TAG}... "

    # Obtener digest
    DIGEST=$(curl -s -I -X GET \
        "http://${REGISTRY_URL}/v2/${IMAGE}/manifests/${TAG}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        2>/dev/null | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')

    if [ -z "$DIGEST" ]; then
        echo -e "${RED}❌ No se pudo obtener digest${NC}"
        FAILED_TAGS+=("$TAG")
        continue
    fi

    # Eliminar
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "http://${REGISTRY_URL}/v2/${IMAGE}/manifests/${DIGEST}")

    if [ "$HTTP_CODE" = "202" ] || [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Eliminado (${HTTP_CODE})${NC}"
    else
        echo -e "${RED}❌ Error ${HTTP_CODE}${NC}"
        FAILED_TAGS+=("$TAG")
    fi

    sleep 0.5  # Pequeña pausa para no saturar
done

# Resumen
echo -e "\n${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Eliminación completada${NC}"
echo -e "   Total tags: ${TAG_COUNT}"
echo -e "   Eliminados: $((TAG_COUNT - ${#FAILED_TAGS[@]}))"
echo -e "   Fallidos: ${#FAILED_TAGS[@]}"

if [ ${#FAILED_TAGS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  Tags con error:${NC}"
    for TAG in "${FAILED_TAGS[@]}"; do
        echo "   - $TAG"
    done
fi

# Preguntar si ejecutar limpieza
echo -e "\n${YELLOW}¿Ejecutar garbage collection y limpieza de repositorios? (s/n)${NC}"
read -r cleanup

if [[ "$cleanup" =~ ^[sS]$ ]]; then
    # Ejecutar garbage collection
    echo -e "\n${YELLOW}🧹 Ejecutando garbage collection...${NC}"
    docker exec $REGISTRY_CONTAINER registry garbage-collect /etc/docker/registry/config.yml

    # Verificar si el repositorio quedó vacío
    TAGS_AFTER=$(curl -s "http://${REGISTRY_URL}/v2/${IMAGE}/tags/list" | jq -r '.tags[]?' 2>/dev/null)

    if [ -z "$TAGS_AFTER" ]; then
        echo -e "\n${YELLOW}🗑️  El repositorio ${IMAGE} quedó vacío. ¿Eliminarlo? (s/n)${NC}"
        read -r delete_repo
        if [[ "$delete_repo" =~ ^[sS]$ ]]; then
            docker exec $REGISTRY_CONTAINER rm -rf "/var/lib/registry/docker/registry/v2/repositories/${IMAGE}"
            echo -e "${GREEN}✅ Repositorio ${IMAGE} eliminado${NC}"
        fi
    fi
fi

# Verificar resultado final
echo -e "\n${BLUE}📋 Tags actuales de ${IMAGE}:${NC}"
curl -s "http://${REGISTRY_URL}/v2/${IMAGE}/tags/list" | jq '.'
