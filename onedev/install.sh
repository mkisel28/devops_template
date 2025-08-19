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
err() { echo -e "${RED}[ERR]${NC} $*"; }

NEW_USER="onedev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME=""
TARGET_DIR=""

if [ "$(id -u)" -eq 0 ]; then
    err "Не запускайте install.sh от root. Используйте обычного пользователя с sudo."
    exit 1
fi

get_user_home() {
    if id "${NEW_USER}" >/dev/null 2>&1; then
        TARGET_HOME=$(getent passwd "${NEW_USER}" | cut -d: -f6)
    else
        TARGET_HOME="/home/${NEW_USER}"
    fi
    TARGET_DIR="${TARGET_HOME}/onedev"
}


check_env_file() {
    if [[ ! -f "${TARGET_DIR}/.env" ]]; then
        err "Файл ${TARGET_DIR}/.env не найден!"
        exit 1
    fi
    log "Используем файл окружения: ${TARGET_DIR}/.env"
}

main() {
    log "Установка OneDev системы..."
    log "Рабочая директория: $SCRIPT_DIR"
    
    get_user_home
    
    log "Установка Docker и подготовка пользователя ${NEW_USER}..."
    sudo NEW_USER="${NEW_USER}" "$SCRIPT_DIR/02-check-install-docker.sh"
    
    sudo mkdir -p "${TARGET_DIR}"
    sudo rsync -a --delete "${SCRIPT_DIR}/" "${TARGET_DIR}/"
    sudo chown -R "${NEW_USER}:${NEW_USER}" "${TARGET_DIR}"
    
    log "Создание .env файла из шаблона..."
    if [ ! -f "${TARGET_DIR}/.env" ]; then
        sudo -u "${NEW_USER}" cp "${TARGET_DIR}/.env.example" "${TARGET_DIR}/.env"
        log "Создан файл .env из шаблона"
    else
        warn "Файл .env уже существует, пропускаем создание"
    fi

    log "Запуск OneDev..."
    sudo -iu "${NEW_USER}" bash -lc "cd '$TARGET_DIR' && ./03-up.sh"
    

}

main "$@"
