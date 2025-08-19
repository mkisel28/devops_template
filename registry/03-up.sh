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

ENV_FILE=".env"

check_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        err "Файл окружения $ENV_FILE не найден!"
        exit 1
    fi
    log "Используем файл окружения: $ENV_FILE"
}

setup_auth() {
    if [[ ! -f "auth/htpasswd" ]]; then
        log "Настройка аутентификации..."

        source "$ENV_FILE"
        
        mkdir -p auth

        if command -v htpasswd &> /dev/null; then
            htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > auth/htpasswd
        else
            if command -v docker &> /dev/null; then
                docker run --rm httpd:2.4-alpine \
                    htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" \
                    > auth/htpasswd

                docker rmi httpd:2.4-alpine
            else
                err "Не найден ни htpasswd, ни docker. Установите apache2-utils."
                exit 1
            fi
        fi
        ok "Файл аутентификации создан"
    fi
}

check_env_file
source "$ENV_FILE"

log "Настройка аутентификации..."
setup_auth

log "Получение образов Docker..."
docker compose --env-file "$ENV_FILE" pull

log "Запуск системы Docker Registry..."
docker compose --env-file "$ENV_FILE" up -d

log "Проверка статуса сервисов..."
docker compose ps


echo ""
ok "Система Docker Registry запущена!"
echo ""
log "Информация о доступе:"
log "   Registry UI:  http://localhost:${NGINX_HTTP_PORT:-80}"
log "   Registry API: http://localhost:${NGINX_HTTP_PORT:-80}/v2/"
log "   Пользователь: ${REGISTRY_USERNAME}"
echo ""
log "Следующие шаги:"
log "   1. Войдите используя учетные данные: ${REGISTRY_USERNAME}"
log "   2. Протестируйте загрузку образа: docker login localhost:${NGINX_HTTP_PORT:-80}"
log "   3. Загрузите тестовый образ командой: ./manage.sh test"
echo ""
log "Управление: используйте ./manage.sh [start|stop|restart|test]"