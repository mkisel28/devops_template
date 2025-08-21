#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

NEW_USER="gitea"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_target_dir() {
    if id "${NEW_USER}" >/dev/null 2>&1; then
        TARGET_HOME=$(getent passwd "${NEW_USER}" | cut -d: -f6)
    else
        TARGET_HOME="/home/${NEW_USER}"
    fi
    TARGET_DIR="${TARGET_HOME}/gitea"
}

if [ "$(id -u)" -eq 0 ]; then
    err "install.sh НЕ нужно запускать от root. Запустите как обычный пользователь с sudo."
    exit 1
fi

cd "$SCRIPT_DIR"
get_target_dir

log "Рабочая директория: $SCRIPT_DIR"

log "Установка Docker и подготовка пользователя gitea…"
sudo NEW_USER="${NEW_USER}" ./02-check-install-docker.sh



sudo mkdir -p "${TARGET_DIR}"
sudo rsync -a --delete "${SCRIPT_DIR}/" "${TARGET_DIR}/"
sudo chown -R "${NEW_USER}:${NEW_USER}" "${TARGET_DIR}"


log "Запуск docker-compose под пользователем gitea…"
sudo -iu gitea bash -lc "cd '$TARGET_DIR' && ./03-up.sh"

ok "Готово. Дальнейшие шаги см. в выводе 03-up.sh."
