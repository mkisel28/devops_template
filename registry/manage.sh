#!/usr/bin/env bash
set -euo pipefail

# Usage: ./manage.sh [test|help] 

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

    ok "Тестовые образы успешно загружены"
}

show_help() {
    echo "Commands:"
    echo "  test      Push a test image to registry"
    echo ""
}

case "${1:-help}" in
    test)
        push_test_image
        ;;
    help|*)
        show_help
        ;;
esac
