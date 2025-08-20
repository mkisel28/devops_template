#!/usr/bin/env bash
set -euo pipefail



GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }

NEW_USER="${NEW_USER:-registry}"

log "Обновление пакетов..."
apt update -y

install_docker() {
    apt install -y ca-certificates curl gnupg lsb-release rsync apache2-utils

    install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable --now docker
}

if ! docker compose version >/dev/null 2>&1; then
    install_docker
else
    log "Docker уже установлен"
fi

log "Настройка пользователя ${NEW_USER}..."
if ! id "${NEW_USER}" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "${NEW_USER}"
    ok "Создан пользователь ${NEW_USER}"
else
    log "Пользователь ${NEW_USER} уже существует"
fi

groupadd -f docker
usermod -aG docker "${NEW_USER}"

