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


log "Проверка зависимостей..."

command -v docker >/dev/null 2>&1 || { echo "Docker не найден в PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Пользователь не имеет доступа к Docker (группа docker?)."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose plugin не установлен."; exit 1; }


ok "Все зависимости проверены"


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

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    log "Загружены переменные из $ENV_FILE"
else
    warn "Файл $ENV_FILE не найден"
fi

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
log "   Registry UI:  http://${REGISTRY_DOMAIN}:${NGINX_HTTP_PORT:-80}"
log "   Registry API: http://${REGISTRY_DOMAIN}:${NGINX_HTTP_PORT:-80}/v2/"
log "   Пользователь: ${REGISTRY_USERNAME}"
echo ""
log "Следующие шаги:"
log "   1. Войдите используя учетные данные: ${REGISTRY_USERNAME}"
log "   2. Протестируйте загрузку образа: docker login ${REGISTRY_DOMAIN}:${NGINX_HTTP_PORT:-80}"
log "   3. Загрузите тестовый образ командой: ./manage.sh test"
echo ""
log "Управление: используйте ./manage.sh [test]"