#!/bin/bash

# Usage: ./manage.sh [start|stop|restart|build|test] 

set -e

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
        
        if ! command -v htpasswd &> /dev/null; then
            warn "htpasswd не найден, устанавливаем apache2-utils..."
            sudo apt-get update && sudo apt-get install -y apache2-utils
        fi
        
        mkdir -p auth
        htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > auth/htpasswd
        ok "Файл аутентификации создан"
    fi
}


start_services() {
    log "Запуск сервисов Docker Registry в окружении $ENV..."
    
    check_env_file
    setup_auth
    
    docker compose --env-file "$ENV_FILE" up -d

    ok "Сервисы успешно запущены!"

    source "$ENV_FILE"
    
    echo ""
    log "Services are available at:"
    
    echo "  Nginx Proxy:  http://localhost:$NGINX_HTTP_PORT"
}

stop_services() {
    log "Остановка Docker Registry..."
    docker compose --env-file "$ENV_FILE" down
    ok "Сервисы остановлены успешно!"
}

restart_services() {
    stop_services
    start_services
}


build_services() {
    log "Сборка образов..."
    docker compose --env-file "$ENV_FILE" build
    ok "Образы собраны успешно!"
}


push_test_image() {
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
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  build     Build all services"
    echo "  test      Push a test image to registry"
    echo ""

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
