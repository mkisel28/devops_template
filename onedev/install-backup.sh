#!/bin/bash

# ===========================================
# УСТАНОВКА СИСТЕМЫ БЕКАПОВ ДЛЯ ONEDEV
# ===========================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_requirements() {
    log_step "Проверка требований..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose не установлен"
        exit 1
    fi
    
    log_info "Все требования выполнены"
}

build_backup_system() {
    log_step "Сборка образа системы бекапов..."
    
    if [ ! -d "backup-system" ]; then
        log_error "Директория backup-system не найдена"
        log_info "Убедитесь что вы запускаете скрипт из корня проекта devops_template"
        exit 1
    fi
    
    cd backup-system
    if docker build -t backup-system .; then
        log_info "Образ backup-system успешно собран"
    else
        log_error "Ошибка сборки образа"
        exit 1
    fi
    cd ..
}

setup_onedev_directories() {
    log_step "Создание структуры директорий для onedev..."
    
    mkdir -p onedev/backup/{config,logs,archives,ssh}
    
    chmod 700 onedev/backup/ssh
    
    log_info "Структура директорий создана"
}

setup_configuration() {
    log_step "Настройка конфигурации..."
    
    if [ ! -f "onedev/backup/config/backup.env" ]; then
        if [ -f "backup-system/config/backup.env.example" ]; then
            cp backup-system/config/backup.env.example onedev/backup/config/backup.env
            log_info "Конфигурационный файл скопирован"
            
            log_step "Настройка параметров для onedev..."
            
            sed -i 's/PROJECT_NAME=onedev/PROJECT_NAME=onedev/' onedev/backup/config/backup.env
            sed -i 's/DB_PASSWORD=onedev_secure_password_change_me/DB_PASSWORD=onedev_secure_password_change_me/' onedev/backup/config/backup.env
            
            log_warn "ВАЖНО: Отредактируйте файл onedev/backup/config/backup.env"
            log_warn "Укажите правильные параметры:"
            log_warn "  - DB_PASSWORD (пароль базы данных)"
            log_warn "  - REMOTE_HOST (адрес сервера бекапов)"
            log_warn "  - REMOTE_USER (пользователь сервера бекапов)"
            log_warn "  - TELEGRAM_BOT_TOKEN (токен Telegram бота)"
            log_warn "  - TELEGRAM_CHAT_ID (ID чата Telegram)"
        else
            log_error "Файл backup.env.example не найден"
            exit 1
        fi
    else
        log_info "Конфигурационный файл уже существует"
    fi
}

generate_ssh_keys() {
    log_step "Генерация SSH ключей..."
    
    local ssh_key_path="onedev/backup/ssh/id_rsa"
    
    if [ ! -f "$ssh_key_path" ]; then
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N "" -C "onedev-backup-$(date +%Y%m%d)"
        chmod 600 "$ssh_key_path"
        chmod 644 "${ssh_key_path}.pub"
        
        log_info "SSH ключи созданы: $ssh_key_path"
        log_warn "ВАЖНО: Скопируйте публичный ключ на сервер бекапов:"
        log_warn "ssh-copy-id -i ${ssh_key_path}.pub backup@your-backup-server.com"
        echo
        echo "Публичный ключ:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "${ssh_key_path}.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_info "SSH ключи уже существуют"
    fi
}

test_system() {
    log_step "Тестирование системы бекапов..."
    
    log_info "Запуск тестового контейнера..."
    
    if docker run --rm \
        -v "$(pwd)/onedev/backup/config:/app/config:ro" \
        -v "$(pwd)/onedev/backup/ssh:/app/config/ssh:ro" \
        -v "/var/run/docker.sock:/var/run/docker.sock" \
        backup-system test-connection; then
        log_info "Тест системы прошел успешно"
    else
        log_warn "Тест выявил проблемы. Проверьте конфигурацию"
        log_info "Вы можете продолжить настройку, исправив проблемы позже"
    fi
}

show_final_instructions() {
    echo
    echo "УСТАНОВКА ЗАВЕРШЕНА!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "Что дальше:"
    echo
    echo "1НАСТРОЙТЕ КОНФИГУРАЦИЮ:"
    echo "   nano onedev/backup/config/backup.env"
    echo
    echo "2 НАСТРОЙТЕ SSH ДОСТУП К СЕРВЕРУ БЕКАПОВ:"
    echo "   ssh-copy-id -i onedev/backup/ssh/id_rsa.pub backup@your-backup-server.com"
    echo
    echo "3.  НАСТРОЙТЕ TELEGRAM БОТА:"
    echo "   - Создайте бота через @BotFather"
    echo "   - Получите токен и chat_id"
    echo "   - Укажите их в конфигурации"
    echo
    echo "4. ЗАПУСТИТЕ СИСТЕМУ БЕКАПОВ:"
    echo "   cd onedev"
    echo "   docker compose --profile backup up -d"
    echo
    echo "5.  ПРОТЕСТИРУЙТЕ БЕКАП:"
    echo "   docker exec onedev-backup /app/scripts/entrypoint.sh backup --dry-run"
    echo
    echo "6.     ПРОВЕРЬТЕ СОЕДИНЕНИЯ:"
    echo "   docker exec onedev-backup /app/scripts/entrypoint.sh test-connection"
    echo
    log_info "Система готова к использованию!"
    echo
    echo " Подробная документация: backup-system/README.md"
    echo " Справка: docker exec onedev-backup /app/scripts/entrypoint.sh help"
}

main() {
    echo "УСТАНОВКА СИСТЕМЫ БЕКАПОВ ДЛЯ ONEDEV"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    check_requirements
    build_backup_system
    setup_onedev_directories
    setup_configuration
    generate_ssh_keys
    
    echo
    read -p "Хотите протестировать систему сейчас? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_system
    else
        log_info "Тестирование пропущено"
    fi
    
    show_final_instructions
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Использование: $0 [--help]"
    echo
    echo "Этот скрипт автоматически настраивает систему бекапов для OneeDev:"
    echo "  - Собирает Docker образ системы бекапов"
    echo "  - Создает необходимые директории"
    echo "  - Копирует конфигурационные файлы"
    echo "  - Генерирует SSH ключи"
    echo "  - Тестирует систему (опционально)"
    echo
    echo "Запускайте из корневой директории devops_template"
    exit 0
fi

main
