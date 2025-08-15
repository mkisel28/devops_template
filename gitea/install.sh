#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

NEW_USER="gitea"
TARGET_HOME=$(getent passwd "${NEW_USER}" | cut -d: -f6)
TARGET_DIR="${TARGET_HOME}/gitea"

if [ "$(id -u)" -eq 0 ]; then
  err "install.sh НЕ нужно запускать от root. Запустите как обычный пользователь с sudo."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log "Рабочая директория: $SCRIPT_DIR"

log "Установка Docker и подготовка пользователя gitea…"
sudo NEW_USER="${NEW_USER}" ./02-check-install-docker.sh



sudo mkdir -p "${TARGET_DIR}"
sudo rsync -a --delete "${SCRIPT_DIR}/" "${TARGET_DIR}/"
sudo chown -R "${NEW_USER}:${NEW_USER}" "${TARGET_DIR}"


log "Запуск docker-compose под пользователем gitea…"
sudo -iu gitea bash -lc "cd '$TARGET_DIR' && ./03-up.sh"

ok "Готово. Дальнейшие шаги см. в выводе 03-up.sh."
