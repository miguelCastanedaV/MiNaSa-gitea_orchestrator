#!/bin/bash
# delete-repository.sh
# Elimina un repositorio COMPLETO del registro

REGISTRY_CONTAINER="gitea-registry"

if [ $# -ne 1 ]; then
    echo "Uso: $0 <repositorio>"
    echo "Ejemplo: $0 gs-phva-web"
    exit 1
fi

REPO="$1"

echo -e "⚠️  ¿Eliminar COMPLETAMENTE el repositorio ${REPO}? (s/n)"
read -r confirm

if [[ "$confirm" =~ ^[sS]$ ]]; then
    echo "🗑️  Eliminando repositorio ${REPO}..."

    # Eliminar directorio del repositorio
    docker exec $REGISTRY_CONTAINER rm -rf "/var/lib/registry/docker/registry/v2/repositories/${REPO}"

    echo "✅ Repositorio eliminado"

    # Garbage collection
    echo "🧹 Ejecutando garbage collection..."
    docker exec $REGISTRY_CONTAINER registry garbage-collect /etc/docker/registry/config.yml

    echo "✅ Proceso completado"

    # Verificar
    echo -e "\n📋 Catálogo actual:"
    curl -s http://minasa.local:5000/v2/_catalog | jq '.'
else
    echo "❌ Cancelado"
fi
