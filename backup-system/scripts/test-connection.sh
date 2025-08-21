#!/bin/bash

# ===========================================
# СКРИПТ ТЕСТИРОВАНИЯ СОЕДИНЕНИЙ
# ===========================================

set -euo pipefail

# Загрузка библиотек
source /app/scripts/lib/logger.sh
source /app/scripts/lib/config.sh
source /app/scripts/lib/telegram.sh

# Флаг общего результата
OVERALL_SUCCESS=true

# Тестирование соединения с базой данных
test_database_connection() {
    if [ "${DB_ENABLED:-false}" != "true" ]; then
        log_info "🗄️  Тестирование БД пропущено (отключено в конфигурации)"
        return 0
    fi
    
    log_step "Тестирование соединения с базой данных..."
    
    local test_result=""
    local connection_string=""
    
    case "${DB_TYPE:-postgresql}" in
        "postgresql")
            connection_string="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
            
            if [ "${DRY_RUN:-false}" = "true" ]; then
                log_info "🔍 [DRY-RUN] Тест PostgreSQL: $DB_HOST:$DB_PORT"
                test_result="success (dry-run)"
            else
                local start_time=$(date +%s)
                
                # Дополнительная проверка подключения
                if docker exec -e PGPASSWORD="$DB_PASSWORD" "$DB_HOST" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    test_result="success (${duration}s)"
                    log_success "PostgreSQL соединение установлено успешно"
                else
                    test_result="failed (authentication error)"
                    log_error "❌ Ошибка аутентификации PostgreSQL"
                    OVERALL_SUCCESS=false
                fi
         
            fi
            ;;
        *)
            log_error "❌ Неподдерживаемый тип базы данных: ${DB_TYPE}"
            test_result="failed (unsupported database type)"
            OVERALL_SUCCESS=false
            ;;
    esac
    
    log_info "🗄️  База данных ${DB_TYPE}: ${test_result}"
    
    # Уведомление в Telegram
    notify_connection_test \
        "База данных ${DB_TYPE} (${DB_HOST}:${DB_PORT})" \
        "$(echo "$test_result" | cut -d' ' -f1)" \
        "$test_result"
}

# Тестирование соединения с удаленным сервером
test_remote_connection() {
    if [ "${REMOTE_ENABLED:-false}" != "true" ]; then
        log_info "🌐 Тестирование удаленного сервера пропущено (отключено в конфигурации)"
        return 0
    fi
    
    log_step "Тестирование соединения с удаленным сервером..."
    
    local test_result=""
    local ssh_opts="-o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=no"
    
    # Добавление SSH ключа если указан
    if [ -n "${REMOTE_SSH_KEY:-}" ]; then
        ssh_opts="$ssh_opts -i $REMOTE_SSH_KEY"
    fi
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Тест SSH: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
        test_result="success (dry-run)"
    else
        local start_time=$(date +%s)
        
        # Тест SSH соединения
        if timeout 30 ssh $ssh_opts -p "${REMOTE_PORT:-22}" "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH connection test'" >/dev/null 2>&1; then
            
            # Тест создания директории
            if ssh $ssh_opts -p "${REMOTE_PORT:-22}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '$REMOTE_PATH' && test -w '$REMOTE_PATH'" >/dev/null 2>&1; then
                
                # Тест записи файла
                if ssh $ssh_opts -p "${REMOTE_PORT:-22}" "${REMOTE_USER}@${REMOTE_HOST}" "echo 'test' > '$REMOTE_PATH/.backup_test' && rm -f '$REMOTE_PATH/.backup_test'" >/dev/null 2>&1; then
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    test_result="success (${duration}s)"
                    log_success "SSH соединение и права записи проверены успешно"
                else
                    test_result="failed (write permission denied)"
                    log_error "❌ Нет прав записи в директорию: $REMOTE_PATH"
                    OVERALL_SUCCESS=false
                fi
            else
                test_result="failed (directory access denied)"
                log_error "❌ Не удается создать/получить доступ к директории: $REMOTE_PATH"
                OVERALL_SUCCESS=false
            fi
        else
            test_result="failed (ssh connection timeout)"
            log_error "❌ Не удается подключиться по SSH к $REMOTE_HOST"
            OVERALL_SUCCESS=false
        fi
    fi
    
    log_info "🌐 Удаленный сервер: ${test_result}"
    
    # Уведомление в Telegram
    notify_connection_test \
        "SSH ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}" \
        "$(echo "$test_result" | cut -d' ' -f1)" \
        "$test_result"
}

# Тестирование Docker volumes
test_docker_volumes() {
    if [ "${VOLUMES_ENABLED:-false}" != "true" ]; then
        log_info "📂 Тестирование Docker volumes пропущено (отключено в конфигурации)"
        return 0
    fi
    
    log_step "Тестирование доступности Docker volumes..."
    
    local volumes_list
    volumes_list=$(get_volumes_list)
    
    if [ -z "$volumes_list" ]; then
        log_warn "⚠️  Список volumes для бекапа пуст"
        return 0
    fi
    
    local total_volumes=0
    local accessible_volumes=0
    
    while IFS= read -r volume; do
        [ -z "$volume" ] && continue
        total_volumes=$((total_volumes + 1))
        
        log_debug "🔍 Проверка volume: $volume"
        
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "🔍 [DRY-RUN] Проверка volume: $volume"
            accessible_volumes=$((accessible_volumes + 1))
        else
            # Проверка существования volume
            if docker volume inspect "$volume" >/dev/null 2>&1; then
                log_success "Volume '$volume' доступен"
                accessible_volumes=$((accessible_volumes + 1))
            else
                log_error "❌ Volume '$volume' не найден"
                OVERALL_SUCCESS=false
            fi
        fi
    done <<< "$volumes_list"
    
    log_info "📂 Docker volumes: $accessible_volumes/$total_volumes доступно"
    
    # Уведомление в Telegram
    notify_connection_test \
        "Docker Volumes ($total_volumes шт.)" \
        "$([ $accessible_volumes -eq $total_volumes ] && echo "success" || echo "failed")" \
        "$accessible_volumes из $total_volumes volumes доступно"
}

# Тестирование Telegram уведомлений
test_telegram() {
    if [ "${TELEGRAM_ENABLED:-false}" != "true" ]; then
        log_info "📱 Тестирование Telegram пропущено (отключено в конфигурации)"
        return 0
    fi
    
    log_step "Тестирование Telegram уведомлений..."
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Отправка тестового Telegram сообщения"
        log_info "📱 Telegram: success (dry-run)"
    else
        if send_test_message; then
            log_success "Тестовое сообщение отправлено в Telegram"
            log_info "📱 Telegram: success"
        else
            log_error "❌ Ошибка отправки тестового сообщения в Telegram"
            log_info "📱 Telegram: failed"
            OVERALL_SUCCESS=false
        fi
    fi
}

# Основная функция
main() {
    log_info "🔌 Запуск проверки всех соединений для проекта: $PROJECT_NAME"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 Режим DRY-RUN активен - реальные подключения не выполняются"
    fi
    
    echo
    log_info "📋 Результаты тестирования соединений:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Запуск всех тестов
    test_database_connection
    echo
    test_remote_connection
    echo
    test_docker_volumes
    echo
    test_telegram
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Итоговый результат
    if [ "$OVERALL_SUCCESS" = "true" ]; then
        log_success "Все тесты соединений прошли успешно! ✅"
        exit 0
    else
        log_error "Обнаружены проблемы с соединениями! ❌"
        log_info "💡 Проверьте конфигурацию и сетевые настройки"
        exit 1
    fi
}

# Запуск основной функции
main "$@"
