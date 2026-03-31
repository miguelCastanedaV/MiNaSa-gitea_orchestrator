#!/bin/bash

REGISTRY_CONTAINER="gitea-registry"
REGISTRY_URL="minasa.local:5000"

echo "🔍 Limpiando registro Docker en contenedor: $REGISTRY_CONTAINER"

# Verificar que el contenedor existe
if ! docker ps | grep -q "$REGISTRY_CONTAINER"; then
    echo "❌ Contenedor $REGISTRY_CONTAINER no está corriendo"
    exit 1
fi

# Mostrar espacio antes
echo -e "\n📊 Espacio usado ANTES de limpiar:"
docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry

# Listar imágenes actuales
echo -e "\n📋 Imágenes en el registro (vía API):"
curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq '.'

# Dry-run
echo -e "\n🔍 Simulación de garbage collection:"
docker exec $REGISTRY_CONTAINER registry garbage-collect --dry-run /etc/docker/registry/config.yml

# Preguntar
echo -e "\n⚠️  ¿Ejecutar garbage collection real? (s/n)"
read -r confirm

if [[ "$confirm" =~ ^[sS]$ ]]; then
    echo -e "\n🗑️  Ejecutando garbage collection..."
    docker exec $REGISTRY_CONTAINER registry garbage-collect /etc/docker/registry/config.yml

    # Mostrar espacio después
    echo -e "\n📊 Espacio DESPUÉS de limpiar:"
    docker exec $REGISTRY_CONTAINER du -sh /var/lib/registry

    # Verificar catálogo actualizado
    echo -e "\n📋 Catálogo actualizado:"
    curl -s "http://${REGISTRY_URL}/v2/_catalog" | jq '.'

    echo -e "\n✅ Proceso completado"
else
    echo "❌ Operación cancelada"
fi
