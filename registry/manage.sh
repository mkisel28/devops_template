#!/usr/bin/env bash
set -euo pipefail

# Usage: ./manage.sh [start|stop|restart|build|test] 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }

if [ "$(id -u)" -eq 0 ]; then
    err "Не запускайте manage.sh от root."
    err "Переключитесь на пользователя, добавленного в группу docker."
    exit 1
fi

check_docker_access() {
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
}

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

start_services() {
    log "Запуск сервисов Docker Registry..."
    
    check_docker_access
    check_env_file
    setup_auth
    
    docker compose --env-file "$ENV_FILE" up -d

    ok "Сервисы успешно запущены!"
}

stop_services() {
    log "Остановка Docker Registry..."
    check_docker_access
    docker compose --env-file "$ENV_FILE" down
    ok "Сервисы остановлены успешно!"
}

restart_services() {
    stop_services
    start_services
}

build_services() {
    log "Сборка образов..."
    check_docker_access
    docker compose --env-file "$ENV_FILE" build
    ok "Образы собраны успешно!"
}

push_test_image() {
    check_docker_access
    check_env_file
    source "$ENV_FILE"

    local IMAGE="localhost:$NGINX_HTTP_PORT/hello-world"

    docker login "localhost:$NGINX_HTTP_PORT" \
        -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD"

    docker pull hello-world

    local TAGS=("latest" "v1")

    for tag in "${TAGS[@]}"; do
        docker tag hello-world "$IMAGE:$tag"
        docker push "$IMAGE:$tag"
    done

    for tag in "${TAGS[@]}"; do
        docker rmi "$IMAGE:$tag" || true
    done
    docker rmi hello-world || true

    ok "Тестовые образы (${TAGS[*]}) успешно загружены и удалены локально."
}

show_help() {
    echo "Docker Registry Management Script"
    echo ""
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  build     Build all services"
    echo "  test      Push a test image to registry"
    echo ""
    echo "Примечание: Скрипт должен запускаться от пользователя с доступом к Docker"
}

case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    build)
        build_services
        ;;
    test)
        push_test_image
        ;;
    help|*)
        show_help
        ;;
esac
