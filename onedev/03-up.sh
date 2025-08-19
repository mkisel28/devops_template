#!/usr/bin/env bash
set -euo pipefail

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

if ! command -v docker >/dev/null 2>&1; then
    err "Docker не найден в PATH"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    err "Пользователь не имеет доступа к Docker."
    err "Убедитесь что пользователь добавлен в группу docker:"
    err "  sudo usermod -aG docker \$USER"
    err "  newgrp docker"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose plugin не установлен"
    exit 1
fi

ok "Все зависимости проверены"

# Загрузка переменных окружения
if [ -f .env ]; then
    source .env
    log "Загружены переменные из .env"
else
    warn "Файл .env не найден, используются значения по умолчанию"
fi

log "Получение образов Docker..."
docker compose pull

log "Запуск системы OneDev..."
docker compose up -d


log "Проверка статуса сервисов..."
docker compose ps

log "Ожидание готовности сервисов..."
timeout=300
elapsed=0

while [ $elapsed -lt $timeout ]; do
    if docker compose exec -T onedev-server curl -f http://localhost:6610/health >/dev/null 2>&1; then
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
done

echo ""

if [ $elapsed -ge $timeout ]; then
    warn "Сервисы могут быть ещё не готовы (таймаут $timeout сек)"
else
    ok "OneDev сервер готов к работе"
fi

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
