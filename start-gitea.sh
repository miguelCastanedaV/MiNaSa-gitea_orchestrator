#!/bin/bash

# Script de inicio rápido para Gitea + Registry
# Este script te ayuda a levantar el entorno completo

set -e

echo "🚀 Iniciando Gitea + Registry + CI/CD..."
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar si Docker está corriendo
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker no está corriendo. Inicia Docker primero.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker está corriendo${NC}"

# Verificar si los puertos están disponibles
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${RED}❌ Puerto $1 está en uso${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Puerto $1 disponible${NC}"
        return 0
    fi
}

echo ""
echo "🔍 Verificando puertos necesarios..."
check_port 3000 || exit 1
check_port 222 || exit 1
check_port 5000 || exit 1

# Levantar servicios
echo ""
echo "📦 Levantando servicios de Gitea..."
docker compose up -d

echo ""
echo "⏳ Esperando a que Gitea inicie (30 segundos)..."
sleep 30

# Verificar estado de servicios
echo ""
echo "🔍 Verificando estado de servicios..."
docker compose ps

echo ""
echo -e "${GREEN}✅ Gitea ha sido iniciado correctamente!${NC}"
echo ""
echo "📋 Próximos pasos:"
echo ""
echo "1. Abre tu navegador en: ${YELLOW}http://localhost:3000${NC}"
echo "2. Completa la instalación inicial de Gitea"
echo "3. Crea tu usuario administrador"
echo "4. Ve a 'Site Administration' → 'Actions' → 'Runners' y copia el Registration Token"
echo "5. Edita docker compose.yml y pega el token en GITEA_RUNNER_REGISTRATION_TOKEN"
echo "6. Ejecuta: ${YELLOW}docker compose restart gitea-runner${NC}"
echo ""
echo "📖 Para más detalles, lee: ${YELLOW}SETUP.md${NC}"
echo ""
echo "🐳 Registry disponible en: ${YELLOW}http://localhost:5000${NC}"
echo "   Test: ${YELLOW}curl http://localhost:5000/v2/_catalog${NC}"
echo ""
echo "Para ver logs en tiempo real:"
echo "   ${YELLOW}docker compose logs -f${NC}"
echo ""
echo "Para detener todo:"
echo "   ${YELLOW}docker compose down${NC}"
echo ""

