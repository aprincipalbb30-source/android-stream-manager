#!/bin/bash
#
# test.sh - Script de Teste
#
set -e

# ===== Cores =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}🚀 Android Stream Manager — Executando Testes${NC}"
echo -e "${BLUE}===================================================${NC}"

# ===== Diretório =====
if [ ! -f "CMakeLists.txt" ]; then
    echo -e "${RED}ERRO: Execute a partir da raiz do projeto.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Verificações iniciais OK.${NC}"

# =========================
# Dependências
# =========================
echo -e "\n${YELLOW}🔧 Etapa 1/3: Verificando dependências...${NC}"
echo -e "Este script assume que as dependências de build já foram instaladas via 'install.sh' ou manualmente."
echo -e "Caso contrário, a compilação pode falhar."

# =========================
# Build
# =========================
echo -e "\n${YELLOW}🏗️ Etapa 2/3: Compilando com testes...${NC}"

rm -rf build
mkdir build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DBUILD_TESTS=ON

make -j$(nproc)

echo -e "${GREEN}✅ Build concluído.${NC}"

# =========================
# Executando Testes
# =========================
echo -e "\n${YELLOW}🚀 Etapa 3/3: Executando testes com ctest...${NC}"

ctest --output-on-failure

# =========================
# Final
# =========================
echo -e "\n${BLUE}===================================================${NC}"
echo -e "${GREEN}🎉 TESTES FINALIZADOS COM SUCESSO 🎉${NC}"
echo -e "${BLUE}===================================================${NC}"

exit 0
