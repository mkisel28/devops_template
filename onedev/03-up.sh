#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENV_FILE=".env"

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }

if [ "$(id -u)" -eq 0 ]; then
    err "Не запускайте этот скрипт от root."
    err "Переключитесь на пользователя, добавленного в группу docker."
    exit 1
fi

log "Проверка зависимостей..."

command -v docker >/dev/null 2>&1 || { echo "Docker не найден в PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Пользователь не имеет доступа к Docker (группа docker?)."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose plugin не установлен."; exit 1; }

ok "Все зависимости проверены"


if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    log "Загружены переменные из $ENV_FILE"
else
    warn "Файл $ENV_FILE не найден"
fi

log "Получение образов Docker..."
docker compose pull

log "Запуск системы OneDev..."
docker compose up -d


log "Проверка статуса сервисов..."
docker compose ps


echo ""
ok "Система OneDev запущена!"
echo ""
log "📋 Информация о доступе:"
log "   🌐 Web UI:     http://localhost:${NGINX_HTTP_PORT:-80}"
log "   🐳 OneDev:     http://localhost:${ONEDEV_HTTP_PORT:-6610}"
log "   🔐 SSH:        ssh://localhost:${ONEDEV_SSH_PORT:-6611}"
echo ""
log "📚 Следующие шаги:"
log "   1. Войдите используя учетные данные администратора"
log "   2. Настройте систему согласно документации"
log "   3. Создайте первый проект"
echo ""
log "📖 Документация: https://docs.onedev.io"
