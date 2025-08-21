#!/bin/bash

# ===========================================
# ШАБЛОН УСТАНОВКИ СИСТЕМЫ БЕКАПОВ
# ===========================================

set -euo pipefail

# НАСТРОЙКИ ПРОЕКТА - ИЗМЕНИТЕ ПОД ВАШ ПРОЕКТ
PROJECT_NAME="your_project_name"                    # Имя проекта (например: registry, backend)
PROJECT_DESCRIPTION="Your Project Description"      # Описание проекта
PROJECT_VOLUMES="volume1,volume2"                   # Volumes для бекапа (через запятую)
PROJECT_DB_ENABLED="true"                           # Есть ли база данных (true/false)
PROJECT_DB_HOST="your-db-host"                      # Хост базы данных
PROJECT_DB_NAME="your_db_name"                      # Имя базы данных
PROJECT_DB_USER="your_db_user"                      # Пользователь базы данных

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
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

# Проверка окружения
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
    
    if [ ! -d "../backup-system" ]; then
        log_error "Система бекапов не найдена в ../backup-system"
        log_info "Убедитесь что backup-system находится в корне проекта"
        exit 1
    fi
    
    log_info "Все требования выполнены"
}

# Сборка образа системы бекапов
build_backup_system() {
    log_step "Сборка образа системы бекапов..."
    
    cd ../backup-system
    if docker build -t backup-system .; then
        log_info "Образ backup-system успешно собран"
    else
        log_error "Ошибка сборки образа"
        exit 1
    fi
    cd - > /dev/null
}

# Настройка директорий
setup_directories() {
    log_step "Создание структуры директорий для $PROJECT_NAME..."
    
    mkdir -p backup/{config,logs,archives,ssh}
    chmod 700 backup/ssh
    
    log_info "Структура директорий создана"
}

# Настройка конфигурации
setup_configuration() {
    log_step "Настройка конфигурации..."
    
    if [ ! -f "backup/config/backup.env" ]; then
        # Создание конфигурации на основе шаблона
        cat > backup/config/backup.env << EOF
# ===========================================
# НАСТРОЙКИ БЕКАПА ДЛЯ ${PROJECT_NAME^^}
# ===========================================

# Включить/отключить компоненты бекапа
BACKUP_ENABLED=true
BACKUP_VOLUMES=true
BACKUP_DATABASE=$PROJECT_DB_ENABLED

# Настройки проекта
PROJECT_NAME=$PROJECT_NAME
PROJECT_DESCRIPTION="$PROJECT_DESCRIPTION"

# ===========================================
# НАСТРОЙКИ БАЗЫ ДАННЫХ PostgreSQL
# ===========================================
DB_ENABLED=$PROJECT_DB_ENABLED
DB_TYPE=postgresql
DB_HOST=$PROJECT_DB_HOST
DB_PORT=5432
DB_NAME=$PROJECT_DB_NAME
DB_USER=$PROJECT_DB_USER
DB_PASSWORD=your_password_here

# ===========================================
# НАСТРОЙКИ VOLUME БЕКАПОВ
# ===========================================
VOLUMES_ENABLED=true
# Список volume для бекапа (через запятую)
VOLUMES_LIST=$PROJECT_VOLUMES

# ===========================================
# НАСТРОЙКИ УДАЛЕННОГО СЕРВЕРА
# ===========================================
REMOTE_ENABLED=true
REMOTE_HOST=backup-server.example.com
REMOTE_PORT=22
REMOTE_USER=backup
REMOTE_PATH=/backups/$PROJECT_NAME

# SSH ключ (путь внутри контейнера)
REMOTE_SSH_KEY=/app/config/ssh/id_rsa

# ===========================================
# НАСТРОЙКИ РОТАЦИИ БЕКАПОВ
# ===========================================
# Количество дней для хранения бекапов
RETENTION_DAYS=30
# Количество еженедельных бекапов для хранения
RETENTION_WEEKLY=4
# Количество месячных бекапов для хранения
RETENTION_MONTHLY=12

# ===========================================
# НАСТРОЙКИ РАСПИСАНИЯ
# ===========================================
# Cron расписание для автоматических бекапов
BACKUP_SCHEDULE="0 2 * * *"  # Каждый день в 2:00

# ===========================================
# НАСТРОЙКИ УВЕДОМЛЕНИЙ TELEGRAM
# ===========================================
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here

# ===========================================
# НАСТРОЙКИ ЛОГИРОВАНИЯ
# ===========================================
LOG_LEVEL=INFO  # DEBUG, INFO, WARN, ERROR
LOG_FILE=/app/logs/backup.log
MAX_LOG_SIZE=10M
LOG_RETENTION=7

# ===========================================
# ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
# ===========================================
# Сжатие бекапов
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL=6  # 1-9

# Шифрование бекапов
ENCRYPTION_ENABLED=false
ENCRYPTION_PASSWORD=""

# Тестовый режим (dry-run)
DRY_RUN=false
EOF
        
        log_info "Конфигурационный файл создан"
        log_warn "ВАЖНО: Отредактируйте файл backup/config/backup.env"
    else
        log_info "Конфигурационный файл уже существует"
    fi
}

# Генерация SSH ключей
generate_ssh_keys() {
    log_step "Генерация SSH ключей..."
    
    local ssh_key_path="backup/ssh/id_rsa"
    
    if [ ! -f "$ssh_key_path" ]; then
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N "" -C "${PROJECT_NAME}-backup-$(date +%Y%m%d)"
        chmod 600 "$ssh_key_path"
        chmod 644 "${ssh_key_path}.pub"
        
        log_info "SSH ключи созданы: $ssh_key_path"
        echo
        echo "Публичный ключ для копирования на сервер:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "${ssh_key_path}.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_info "SSH ключи уже существуют"
    fi
}

# Создание docker-compose секции
create_docker_compose_section() {
    log_step "Создание секции для docker-compose.yml..."
    
    cat > backup/docker-compose-backup.yml << EOF
# Добавьте эту секцию в ваш docker-compose.yml

  backup:
    build:
      context: ../backup-system
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-backup
    restart: unless-stopped
    depends_on:
      # Укажите зависимости (например, база данных)
      # your-db:
      #   condition: service_healthy
    volumes:
      # Docker socket для доступа к volumes
      - /var/run/docker.sock:/var/run/docker.sock
      # Конфигурация бекапа
      - ./backup/config:/app/config:ro
      # Логи бекапа
      - ./backup/logs:/app/logs
      # Локальное хранилище бекапов
      - ./backup/archives:/backup/archives
      # SSH ключи для удаленного сервера
      - ./backup/ssh:/app/config/ssh:ro
      # Volumes для бекапа (настройте под ваш проект)
      # - volume1:/backup-volumes/volume1:ro
      # - volume2:/backup-volumes/volume2:ro
    networks:
      # Укажите ваши сети
      # - your-network
    environment:
      - TZ=Europe/Moscow
    profiles:
      - backup
    command: schedule
    healthcheck:
      test: ["CMD", "test", "-f", "/app/logs/backup.log"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF
    
    log_info "Шаблон docker-compose создан: backup/docker-compose-backup.yml"
    log_warn "Скопируйте содержимое в ваш основной docker-compose.yml"
}

# Показать финальные инструкции
show_final_instructions() {
    echo
    echo "🎉 УСТАНОВКА ЗАВЕРШЕНА ДЛЯ $PROJECT_NAME!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "Следующие шаги:"
    echo
    echo "1. 📝 НАСТРОЙТЕ КОНФИГУРАЦИЮ:"
    echo "   nano backup/config/backup.env"
    echo
    echo "2. 🐳 ОБНОВИТЕ DOCKER-COMPOSE:"
    echo "   - Скопируйте содержимое backup/docker-compose-backup.yml"
    echo "   - Вставьте в ваш docker-compose.yml"
    echo "   - Настройте volumes и зависимости"
    echo
    echo "3. 🔑 НАСТРОЙТЕ SSH ДОСТУП:"
    echo "   ssh-copy-id -i backup/ssh/id_rsa.pub backup@your-backup-server.com"
    echo
    echo "4. 📱 НАСТРОЙТЕ TELEGRAM:"
    echo "   - Создайте бота через @BotFather"
    echo "   - Укажите токен и chat_id в конфигурации"
    echo
    echo "5. 🚀 ЗАПУСТИТЕ СИСТЕМУ:"
    echo "   docker compose --profile backup up -d"
    echo
    echo "6. 🧪 ПРОТЕСТИРУЙТЕ:"
    echo "   docker exec ${PROJECT_NAME}-backup /app/scripts/entrypoint.sh test-connection"
    echo "   docker exec ${PROJECT_NAME}-backup /app/scripts/entrypoint.sh backup --dry-run"
    echo
    log_info "Система готова к использованию!"
}

# Основная функция
main() {
    echo "🛠️  УСТАНОВКА СИСТЕМЫ БЕКАПОВ ДЛЯ ${PROJECT_NAME^^}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    if [ "$PROJECT_NAME" = "your_project_name" ]; then
        log_error "Настройте переменные в начале скрипта перед использованием!"
        exit 1
    fi
    
    check_requirements
    build_backup_system
    setup_directories
    setup_configuration
    generate_ssh_keys
    create_docker_compose_section
    show_final_instructions
}

# Проверка аргументов
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Использование: $0 [--help]"
    echo
    echo "Этот скрипт - шаблон для настройки системы бекапов для любого проекта."
    echo "Перед использованием настройте переменные в начале скрипта:"
    echo "  - PROJECT_NAME"
    echo "  - PROJECT_DESCRIPTION"  
    echo "  - PROJECT_VOLUMES"
    echo "  - PROJECT_DB_* параметры"
    echo
    exit 0
fi

# Запуск основной функции
main
