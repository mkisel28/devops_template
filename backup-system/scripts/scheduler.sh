#!/bin/bash

# ===========================================
# ПЛАНИРОВЩИК АВТОМАТИЧЕСКИХ БЕКАПОВ
# ===========================================

set -euo pipefail

# Загрузка библиотек
source /app/scripts/lib/logger.sh
source /app/scripts/lib/config.sh
source /app/scripts/lib/telegram.sh

# Инициализация
init_logger
load_config

log_info "⏰ Запуск планировщика бекапов для проекта: $PROJECT_NAME"

# Создание crontab файла
create_crontab() {
    local crontab_file="/tmp/backup_crontab"
    local backup_schedule="${BACKUP_SCHEDULE:-0 2 * * *}"
    
    cat > "$crontab_file" << EOF
# Автоматический бекап для проекта $PROJECT_NAME
$backup_schedule /app/scripts/backup.sh >> /app/logs/cron.log 2>&1

# Еженедельная проверка соединений (каждое воскресенье в 1:00)
0 1 * * 0 /app/scripts/test-connection.sh >> /app/logs/cron.log 2>&1

# Ежемесячная очистка старых бекапов (1 число каждого месяца в 3:00)
0 3 1 * * /app/scripts/cleanup.sh >> /app/logs/cron.log 2>&1
EOF
    
    # Установка crontab
    crontab "$crontab_file"
    rm -f "$crontab_file"
    
    log_success "Планировщик настроен с расписанием: $backup_schedule"
}

# Проверка конфигурации перед запуском планировщика
check_configuration() {
    log_step "Проверка конфигурации планировщика..."
    
    # Проверка базовых настроек
    if [ "${BACKUP_ENABLED:-false}" != "true" ]; then
        log_error "❌ Бекапы отключены в конфигурации (BACKUP_ENABLED=false)"
        exit 1
    fi
    
    # Проверка расписания
    if [ -z "${BACKUP_SCHEDULE:-}" ]; then
        log_error "❌ Не задано расписание бекапов (BACKUP_SCHEDULE)"
        exit 1
    fi
    
    log_success "Конфигурация планировщика валидна"
}

# Проверка доступности компонентов
test_components() {
    log_step "Проверка доступности компонентов системы..."
    
    # Проверка доступности скриптов
    local required_scripts=("backup.sh" "test-connection.sh" "cleanup.sh")
    
    for script in "${required_scripts[@]}"; do
        if [ ! -x "/app/scripts/$script" ]; then
            log_error "❌ Скрипт не найден или не исполняемый: $script"
            exit 1
        fi
    done
    
    log_success "Все необходимые скрипты доступны"
}

# Создание первоначального тестового бекапа
initial_backup_test() {
    log_step "Выполнение первоначального тестирования..."
    
    # Тест соединений
    if /app/scripts/test-connection.sh; then
        log_success "Тест соединений прошел успешно"
    else
        log_error "❌ Тест соединений завершился с ошибкой"
        log_warn "⚠️  Планировщик будет запущен, но автоматические бекапы могут не работать"
    fi
    
    # Пробный бекап в dry-run режиме
    log_info "🔍 Выполнение пробного бекапа в тестовом режиме..."
    if DRY_RUN=true /app/scripts/backup.sh --dry-run; then
        log_success "Пробный бекап прошел успешно"
    else
        log_error "❌ Пробный бекап завершился с ошибкой"
        exit 1
    fi
}

# Запуск cron daemon
start_cron_daemon() {
    log_step "Запуск cron daemon..."
    
    # Создание необходимых директорий
    mkdir -p /tmp/cron
    
    # Запуск crond в фоновом режиме (Alpine Linux)
    crond -f -l 0 -L /app/logs/cron.log &
    local cron_pid=$!
    
    log_success "Cron daemon запущен (PID: $cron_pid)"
    
    # Уведомление о запуске планировщика
    notify_backup_start "$PROJECT_NAME" "Планировщик запущен"
    
    # Ожидание завершения процесса
    wait $cron_pid
}

# Обработчик сигналов для корректного завершения
cleanup_on_exit() {
    local exit_code=$?
    
    log_info "🛑 Получен сигнал завершения, остановка планировщика..."
    
    # Остановка cron
    pkill crond 2>/dev/null || true
    
    # Уведомление об остановке
    if [ "${TELEGRAM_ENABLED:-false}" = "true" ]; then
        send_telegram_message "🛑 <b>Планировщик остановлен</b>

📦 <b>Проект:</b> $PROJECT_NAME
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    fi
    
    exit $exit_code
}

trap cleanup_on_exit SIGTERM SIGINT

# Основная функция
main() {
    log_info "⏰ Инициализация планировщика автоматических бекапов"
    
    # Показать конфигурацию
    show_config
    
    echo
    
    # Проверки перед запуском
    check_configuration
    test_components
    initial_backup_test
    
    echo
    
    # Настройка и запуск планировщика
    create_crontab
    
    log_info "🚀 Планировщик готов к работе"
    log_info "📅 Расписание бекапов: ${BACKUP_SCHEDULE}"
    log_info "📋 Логи доступны в: /app/logs/"
    
    # Показать активные задания cron
    log_info "📝 Активные задания cron:"
    crontab -l | grep -v '^#' | while read -r line; do
        [ -n "$line" ] && log_info "   $line"
    done
    
    echo
    start_cron_daemon
}

# Запуск основной функции
main "$@"
