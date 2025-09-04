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
error() { echo -e "${RED}[ERR]${NC} $*"; }


request_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        log "Требуются права администратора. Введите пароль sudo..."
        sudo -v || { error "Аутентификация sudo не удалась"; exit 1; }
        exec sudo -E -- "$0" "$@"
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION_CODENAME=${VERSION_CODENAME:-$UBUNTU_CODENAME}
    else
        error "Не удалось определить дистрибутив"
        exit 1
    fi
    
    case $DISTRO in
        ubuntu)
            log "Обнаружен Ubuntu"
            DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
            ;;
        debian)
            log "Обнаружен Debian"
            DOCKER_REPO_URL="https://download.docker.com/linux/debian"
            ;;
        *)
            error "Неподдерживаемый дистрибутив: $DISTRO"
            exit 1
            ;;
    esac
}

check_docker_installed() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        local compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        success "Docker уже установлен"
        log "Docker версия: $docker_version"
        log "Docker Compose версия: $compose_version"
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    log "Обновление пакетов..."
    apt update -y
    
    log "Установка зависимостей..."
    apt install -y ca-certificates curl gnupg lsb-release rsync apache2-utils
}

setup_docker_repository() {
    log "Настройка репозитория Docker..."
    
    install -m 0755 -d /etc/apt/keyrings
    
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        log "Добавление GPG ключа Docker..."
        curl -fsSL "${DOCKER_REPO_URL}/gpg" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    else
        log "GPG ключ Docker уже существует"
    fi
    
    log "Добавление репозитория Docker в sources.list..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] ${DOCKER_REPO_URL} \
        ${VERSION_CODENAME} stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update -y
}

install_docker_packages() {
    log "Установка пакетов Docker..."
    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
}

configure_docker_service() {
    log "Настройка службы Docker..."
    
    systemctl enable docker.service
    systemctl enable containerd.service
    
    systemctl start docker
    
    success "Docker запущен и настроен для автозапуска"
}

verify_installation() {
    log "Проверка установки Docker..."
    
    if docker --version && docker compose version; then
        success "Docker успешно установлен и работает"
        
        if systemctl is-active --quiet docker; then
            success "Служба Docker активна"
        else
            warn "Служба Docker не активна"
        fi
        
        log "Информация о Docker:"
        docker --version
        docker compose version
        
        return 0
    else
        error "Ошибка при проверке установки Docker"
        return 1
    fi
}

install_docker() {    
    request_sudo
    detect_distro

    install_dependencies
    setup_docker_repository
    install_docker_packages
    configure_docker_service
    
    if verify_installation; then
        success "=========================================="
        success "Docker успешно установлен!"
        success "=========================================="
        
    else
        error "=========================================="
        error "Установка Docker завершилась с ошибками"
        error "=========================================="
    fi
}

if check_docker_installed; then
    warn "Docker уже установлен. Пропускаем установку."
else
    install_docker "$@"
fi


