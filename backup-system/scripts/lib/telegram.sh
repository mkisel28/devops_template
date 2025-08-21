#!/bin/bash

# ===========================================
# БИБЛИОТЕКА TELEGRAM УВЕДОМЛЕНИЙ
# ===========================================

# Отправка сообщения в Telegram
send_telegram_message() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    
    if [ "${TELEGRAM_ENABLED:-false}" != "true" ]; then
        log_debug "📱 Telegram уведомления отключены"
        return 0
    fi
    
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        log_warn "⚠️  Не настроены параметры Telegram"
        return 1
    fi
    
    log_debug "📱 Отправка Telegram сообщения..."
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Отправка Telegram сообщения: $message"
        return 0
    fi
    
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    local payload=$(jq -n \
        --arg chat_id "${TELEGRAM_CHAT_ID}" \
        --arg text "$message" \
        --arg parse_mode "$parse_mode" \
        '{
            chat_id: $chat_id,
            text: $text,
            parse_mode: $parse_mode,
            disable_web_page_preview: true
        }')
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url")
    
    if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
        log_debug "✅ Telegram сообщение отправлено успешно"
        return 0
    else
        log_error "❌ Ошибка отправки Telegram сообщения: $response"
        return 1
    fi
}

# Уведомление о начале бекапа
notify_backup_start() {
    local project_name="$1"
    local backup_type="$2"
    
    local message="🚀 <b>Начало бекапа</b>

📦 <b>Проект:</b> ${project_name}
🔄 <b>Тип:</b> ${backup_type}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    
    send_telegram_message "$message"
}

# Уведомление об успешном завершении бекапа
notify_backup_success() {
    local project_name="$1"
    local backup_type="$2"
    local duration="$3"
    local backup_size="$4"
    local backup_files="$5"
    
    local message="✅ <b>Бекап завершен успешно</b>

📦 <b>Проект:</b> ${project_name}
🔄 <b>Тип:</b> ${backup_type}
⏱️ <b>Длительность:</b> ${duration}
📏 <b>Размер:</b> ${backup_size}
📁 <b>Файлов:</b> ${backup_files}
⏰ <b>Завершено:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    
    send_telegram_message "$message"
}

# Уведомление об ошибке бекапа
notify_backup_error() {
    local project_name="$1"
    local backup_type="$2"
    local error_message="$3"
    local duration="$4"
    
    local message="❌ <b>Ошибка бекапа</b>

📦 <b>Проект:</b> ${project_name}
🔄 <b>Тип:</b> ${backup_type}
💥 <b>Ошибка:</b> ${error_message}
⏱️ <b>Длительность:</b> ${duration}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)

⚠️ <i>Требуется проверка логов</i>"
    
    send_telegram_message "$message"
}

# Уведомление о тестировании соединения
notify_connection_test() {
    local target="$1"
    local status="$2"
    local details="$3"
    
    local icon="✅"
    if [ "$status" != "success" ]; then
        icon="❌"
    fi
    
    local message="${icon} <b>Тест соединения</b>

🎯 <b>Цель:</b> ${target}
📊 <b>Статус:</b> ${status}
📝 <b>Детали:</b> ${details}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    
    send_telegram_message "$message"
}

# Уведомление о очистке старых бекапов
notify_cleanup() {
    local project_name="$1"
    local removed_count="$2"
    local freed_space="$3"
    
    local message="🧹 <b>Очистка завершена</b>

📦 <b>Проект:</b> ${project_name}
🗑️ <b>Удалено файлов:</b> ${removed_count}
💾 <b>Освобождено места:</b> ${freed_space}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    
    send_telegram_message "$message"
}

# Уведомление о восстановлении
notify_restore() {
    local project_name="$1"
    local backup_file="$2"
    local status="$3"
    local details="$4"
    
    local icon="✅"
    if [ "$status" != "success" ]; then
        icon="❌"
    fi
    
    local message="${icon} <b>Восстановление</b>

📦 <b>Проект:</b> ${project_name}
📁 <b>Файл бекапа:</b> ${backup_file}
📊 <b>Статус:</b> ${status}
📝 <b>Детали:</b> ${details}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)"
    
    send_telegram_message "$message"
}

# Тестовое сообщение
send_test_message() {
    local message="🧪 <b>Тестовое сообщение</b>

📱 Telegram уведомления настроены правильно!

📦 <b>Проект:</b> ${PROJECT_NAME:-Тест}
⏰ <b>Время:</b> $(date '+%Y-%m-%d %H:%M:%S')
🖥️ <b>Сервер:</b> $(hostname)

✅ <i>Система готова к работе</i>"
    
    send_telegram_message "$message"
}
