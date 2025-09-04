#!/usr/bin/env bash
set -euo pipefail


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR]${NC} $*"; }

NEW_USER="${NEW_USER:-onedev}"

if [ "$(id -u)" -ne 0 ]; then
    log "Требуются права администратора. Введите пароль sudo..."
    sudo -v || { error "Аутентификация sudo не удалась"; exit 1; }
    exec sudo -E -- "$0" "$@"
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

ok "Пользователь ${NEW_USER} настроен"