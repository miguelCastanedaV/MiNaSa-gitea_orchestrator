#!/bin/bash
# cleanup-empty-repos.sh

REGISTRY_CONTAINER="gitea-registry"
REGISTRY_URL="minasa.local:5000"

echo "🔍 Buscando repositorios sin tags..."

# Obtener lista de repositorios
repos=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]')

for repo in $repos; do
    echo -n "📦 Verificando $repo... "

    # Verificar si tiene tags
    tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]?' 2>/dev/null)

    if [ -z "$tags" ]; then
        echo "⚠️  VACÍO (sin tags)"
        echo "   ¿Eliminar repositorio $repo? (s/n)"
        read -r confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            echo "   🗑️  Eliminando $repo..."
            docker exec $REGISTRY_CONTAINER rm -rf "/var/lib/registry/docker/registry/v2/repositories/${repo}"
            echo "   ✅ Eliminado"
        fi
    else
        echo "✅ Tiene tags: $tags"
    fi
done

echo -e "\n📋 Catálogo actualizado:"
curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq '.'
