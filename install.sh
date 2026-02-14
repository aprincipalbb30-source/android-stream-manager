#!/bin/bash
#
# install.sh - Instalador de Produção
#
set -e

# ===== Cores =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}🚀 Android Stream Manager — Instalação de Produção${NC}"
echo -e "${BLUE}===================================================${NC}"

# ===== Root =====
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERRO: Execute como root (sudo).${NC}"
    exit 1
fi

# ===== Diretório =====
if [ ! -f "CMakeLists.txt" ]; then
    echo -e "${RED}ERRO: Execute a partir da raiz do projeto.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Verificações iniciais OK.${NC}"

# =========================
# Dependências
# =========================
echo -e "\n${YELLOW}🔧 Etapa 1/4: Instalando dependências...${NC}"

DEPS=(
    build-essential
    cmake
    git
    pkg-config

    libssl-dev
    zlib1g-dev
    libsqlite3-dev
    liblz4-dev
    libzip-dev

    # Qt (opcional, mas incluído)
    qt6-base-dev
    qt6-websockets-dev
    qt6-multimedia-dev

    # FFmpeg
    libavcodec-dev
    libavutil-dev
    libswscale-dev

    libxkbcommon-dev
)

apt-get update
apt-get install -y "${DEPS[@]}"

echo -e "${GREEN}✅ Dependências instaladas.${NC}"

# =========================
# Build
# =========================
echo -e "\n${YELLOW}🏗️ Etapa 2/4: Compilação...${NC}"

INSTALL_DIR="/opt/android-stream-manager"

rm -rf build
mkdir build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DBUILD_TESTS=OFF

make -j$(nproc)

echo -e "${GREEN}✅ Build concluído.${NC}"

# =========================
# Instalação
# =========================
echo -e "\n${YELLOW}⚙️ Etapa 3/4: Instalando em ${INSTALL_DIR}...${NC}"

make install

echo -e "${GREEN}✅ Sistema instalado.${NC}"

# =========================
# Serviço systemd
# =========================
echo -e "\n${YELLOW}🚀 Etapa 4/4: Configurando serviço...${NC}"

SERVICE_USER="asm-user"

getent group ${SERVICE_USER} >/dev/null || groupadd --system ${SERVICE_USER}
id -u ${SERVICE_USER} >/dev/null 2>&1 || useradd \
    --system \
    --no-create-home \
    --gid ${SERVICE_USER} \
    --shell /bin/false \
    ${SERVICE_USER}

mkdir -p /var/lib/android-stream-manager
mkdir -p /var/log/android-stream-manager

chown -R ${SERVICE_USER}:${SERVICE_USER} \
    ${INSTALL_DIR} \
    /var/lib/android-stream-manager \
    /var/log/android-stream-manager

mkdir -p /etc/android-stream-manager
chown root:${SERVICE_USER} /etc/android-stream-manager
chmod 775 /etc/android-stream-manager

# ===== systemd unit =====
cat > /etc/systemd/system/android-stream-manager.service <<EOF
[Unit]
Description=Android Stream Manager Server
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
EnvironmentFile=/etc/default/android-stream-manager
ExecStart=${INSTALL_DIR}/bin/stream_server
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# ===== Env =====
cat > /etc/default/android-stream-manager <<EOF
JWT_SECRET="ALTERE-ESTE-SEGREDO-IMEDIATAMENTE"
DB_PATH="/var/lib/android-stream-manager/database.sqlite"
EOF

chmod 640 /etc/default/android-stream-manager
chown root:${SERVICE_USER} /etc/default/android-stream-manager

systemctl daemon-reload
systemctl enable android-stream-manager

echo -e "${GREEN}✅ Serviço configurado.${NC}"

# =========================
# Final
# =========================
echo -e "\n${BLUE}===================================================${NC}"
echo -e "${GREEN}🎉 INSTALAÇÃO FINALIZADA COM SUCESSO 🎉${NC}"
echo -e "${BLUE}===================================================${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1️⃣ Edite o JWT secret:"
echo "   sudo nano /etc/default/android-stream-manager"
echo ""
echo "2️⃣ Inicie o serviço:"
echo "   sudo systemctl start android-stream-manager"
echo ""
echo "3️⃣ Verifique logs:"
echo "   journalctl -u android-stream-manager -f"
echo ""

exit 0