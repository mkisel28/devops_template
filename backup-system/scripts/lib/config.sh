#!/bin/bash

# ===========================================
# БИБЛИОТЕКА КОНФИГУРАЦИИ
# ===========================================

# Загрузка конфигурации
load_config() {
    local config_file="/app/config/backup.env"
    
    if [ -f "$config_file" ]; then
        # Экспорт переменных из конфигурационного файла
        set -a
        source "$config_file"
        set +a
        log_debug "📄 Конфигурация загружена из: $config_file"
    else
        log_error "❌ Файл конфигурации не найден: $config_file"
        log_info "💡 Скопируйте backup.env.example в backup.env и настройте параметры"
        exit 1
    fi
    
    # Проверка обязательных переменных
    validate_config
}

# Валидация конфигурации
validate_config() {
    local errors=0
    
    log_debug "🔍 Проверка конфигурации..."
    
    # Проверка основных настроек
    if [ -z "${PROJECT_NAME:-}" ]; then
        log_error "❌ PROJECT_NAME не задан"
        errors=$((errors + 1))
    fi
    
    # Проверка настроек базы данных
    if [ "${DB_ENABLED:-false}" = "true" ]; then
        check_required_var "DB_HOST" "$errors"
        check_required_var "DB_NAME" "$errors"
        check_required_var "DB_USER" "$errors"
        check_required_var "DB_PASSWORD" "$errors"
    fi
    
    # Проверка настроек удаленного сервера
    if [ "${REMOTE_ENABLED:-false}" = "true" ]; then
        check_required_var "REMOTE_HOST" "$errors"
        check_required_var "REMOTE_USER" "$errors"
        check_required_var "REMOTE_PATH" "$errors"
        
        # Проверка SSH ключа
        if [ -n "${REMOTE_SSH_KEY:-}" ] && [ ! -f "${REMOTE_SSH_KEY}" ]; then
            log_error "❌ SSH ключ не найден: ${REMOTE_SSH_KEY}"
            errors=$((errors + 1))
        fi
    fi
    
    # Проверка настроек Telegram
    if [ "${TELEGRAM_ENABLED:-false}" = "true" ]; then
        check_required_var "TELEGRAM_BOT_TOKEN" "$errors"
        check_required_var "TELEGRAM_CHAT_ID" "$errors"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "❌ Найдено $errors ошибок в конфигурации"
        exit 1
    fi
    
    log_success "Конфигурация валидна"
}

# Проверка обязательной переменной
check_required_var() {
    local var_name="$1"
    local errors="$2"
    
    if [ -z "${!var_name:-}" ]; then
        log_error "❌ Обязательная переменная не задана: $var_name"
        return 1
    fi
    return 0
}

# Получение значения конфигурации с значением по умолчанию
get_config() {
    local key="$1"
    local default_value="$2"
    echo "${!key:-$default_value}"
}

# Получение списка volumes для бекапа
get_volumes_list() {
    echo "${VOLUMES_LIST:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$'
}

# Получение настроек сжатия
get_compression_cmd() {
    if [ "${COMPRESSION_ENABLED:-false}" = "true" ]; then
        local level="${COMPRESSION_LEVEL:-6}"
        echo "gzip -${level}"
    else
        echo "cat"
    fi
}

# Получение расширения файла бекапа
get_backup_extension() {
    if [ "${COMPRESSION_ENABLED:-false}" = "true" ]; then
        echo ".tar.gz"
    else
        echo ".tar"
    fi
}

# Генерация имени файла бекапа
generate_backup_filename() {
    local type="$1"  # db, volume, full
    local component="$2"  # имя базы данных или volume
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local extension=$(get_backup_extension)
    
    echo "${PROJECT_NAME}_${type}_${component}_${timestamp}${extension}"
}

# Показать текущую конфигурацию
show_config() {
    log_info "📋 Текущая конфигурация:"
    echo "  📦 Проект: ${PROJECT_NAME:-не задано}"
    echo "  📝 Описание: ${PROJECT_DESCRIPTION:-не задано}"
    echo "  💾 Бекап volumes: ${VOLUMES_ENABLED:-false}"
    echo "  🗄️  Бекап БД: ${DB_ENABLED:-false}"
    echo "  🌐 Удаленный сервер: ${REMOTE_ENABLED:-false}"
    echo "  📱 Telegram уведомления: ${TELEGRAM_ENABLED:-false}"
    echo "  🗜️  Сжатие: ${COMPRESSION_ENABLED:-false}"
    echo "  🔒 Шифрование: ${ENCRYPTION_ENABLED:-false}"
    echo "  🔍 Тестовый режим: ${DRY_RUN:-false}"
    
    if [ "${VOLUMES_ENABLED:-false}" = "true" ]; then
        echo "  📂 Volumes для бекапа:"
        get_volumes_list | while read -r volume; do
            [ -n "$volume" ] && echo "    - $volume"
        done
    fi
    
    if [ "${DB_ENABLED:-false}" = "true" ]; then
        echo "  🗄️  База данных:"
        echo "    - Тип: ${DB_TYPE:-postgresql}"
        echo "    - Хост: ${DB_HOST:-не задано}"
        echo "    - База: ${DB_NAME:-не задано}"
        echo "    - Пользователь: ${DB_USER:-не задано}"
    fi
    
    if [ "${REMOTE_ENABLED:-false}" = "true" ]; then
        echo "  🌐 Удаленный сервер:"
        echo "    - Хост: ${REMOTE_HOST:-не задано}"
        echo "    - Пользователь: ${REMOTE_USER:-не задано}"
        echo "    - Путь: ${REMOTE_PATH:-не задано}"
    fi
}
