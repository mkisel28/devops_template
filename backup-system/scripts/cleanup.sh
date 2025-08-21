#!/bin/bash

# ===========================================
# СКРИПТ ОЧИСТКИ СТАРЫХ БЕКАПОВ
# ===========================================

set -euo pipefail

# Загрузка библиотек
source /app/scripts/lib/logger.sh
source /app/scripts/lib/config.sh
source /app/scripts/lib/telegram.sh

# Инициализация
init_logger
load_config

log_info "🧹 Запуск очистки старых бекапов для проекта: $PROJECT_NAME"

# Очистка локальных бекапов
cleanup_local_backups() {
    log_step "Очистка локальных бекапов..."
    
    local retention_days="${RETENTION_DAYS:-30}"
    local backup_dir="/backup/archives"
    local removed_count=0
    local removed_size=0
    
    if [ ! -d "$backup_dir" ]; then
        log_warn "⚠️  Директория бекапов не найдена: $backup_dir"
        return 0
    fi
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Поиск файлов старше $retention_days дней в $backup_dir"
        
        find "$backup_dir" -name "${PROJECT_NAME}_*" -type f -mtime +$retention_days -print0 2>/dev/null | while IFS= read -r -d '' file; do
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local file_size_mb=$((file_size / 1024 / 1024))
            log_info "🔍 [DRY-RUN] Будет удален: $(basename "$file") (${file_size_mb} MB)"
            removed_count=$((removed_count + 1))
            removed_size=$((removed_size + file_size))
        done
    else
        # Реальное удаление файлов
        find "$backup_dir" -name "${PROJECT_NAME}_*" -type f -mtime +$retention_days -print0 2>/dev/null | while IFS= read -r -d '' file; do
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local filename=$(basename "$file")
            
            if rm -f "$file"; then
                removed_count=$((removed_count + 1))
                removed_size=$((removed_size + file_size))
                log_debug "🗑️  Удален: $filename"
            else
                log_error "❌ Ошибка удаления файла: $filename"
            fi
        done
    fi
    
    local removed_size_mb=$((removed_size / 1024 / 1024))
    
    if [ $removed_count -gt 0 ]; then
        log_success "Локально удалено $removed_count файлов (${removed_size_mb} MB)"
    else
        log_info "Локальных файлов для удаления не найдено"
    fi
    
    echo "$removed_count $removed_size"
}

# Очистка удаленных бекапов
cleanup_remote_backups() {
    if [ "${REMOTE_ENABLED:-false}" != "true" ]; then
        log_debug "🌐 Очистка удаленных бекапов отключена"
        return 0
    fi
    
    log_step "Очистка удаленных бекапов..."
    
    local retention_days="${RETENTION_DAYS:-30}"
    local ssh_opts="-o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=no"
    local remote_removed_count=0
    local remote_removed_size=0
    
    if [ -n "${REMOTE_SSH_KEY:-}" ]; then
        ssh_opts="$ssh_opts -i $REMOTE_SSH_KEY"
    fi
    
    local remote_project_dir="$REMOTE_PATH/$PROJECT_NAME"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Очистка удаленных бекапов старше $retention_days дней"
        log_info "🔍 [DRY-RUN] Путь: ${REMOTE_USER}@${REMOTE_HOST}:$remote_project_dir"
    else
        # Создание скрипта очистки на удаленном сервере
        local cleanup_script="
            #!/bin/bash
            removed_count=0
            removed_size=0
            
            if [ -d '$remote_project_dir' ]; then
                find '$remote_project_dir' -name '${PROJECT_NAME}_*' -type f -mtime +$retention_days -print0 2>/dev/null | while IFS= read -r -d '' file; do
                    file_size=\$(stat -c%s \"\$file\" 2>/dev/null || echo \"0\")
                    if rm -f \"\$file\"; then
                        removed_count=\$((removed_count + 1))
                        removed_size=\$((removed_size + file_size))
                        echo \"Удален: \$(basename \"\$file\")\"
                    fi
                done
                
                # Удаление пустых директорий
                find '$remote_project_dir' -type d -empty -delete 2>/dev/null || true
            fi
            
            echo \"CLEANUP_STATS: \$removed_count \$removed_size\"
        "
        
        # Выполнение скрипта на удаленном сервере
        local output
        output=$(ssh $ssh_opts -p "${REMOTE_PORT:-22}" "${REMOTE_USER}@${REMOTE_HOST}" "$cleanup_script" 2>/dev/null || echo "ERROR")
        
        if [ "$output" != "ERROR" ]; then
            # Извлечение статистики
            local stats_line=$(echo "$output" | grep "CLEANUP_STATS:" | tail -1)
            if [ -n "$stats_line" ]; then
                remote_removed_count=$(echo "$stats_line" | cut -d' ' -f2)
                remote_removed_size=$(echo "$stats_line" | cut -d' ' -f3)
            fi
            
            local remote_removed_size_mb=$((remote_removed_size / 1024 / 1024))
            
            if [ "$remote_removed_count" -gt 0 ]; then
                log_success "Удаленно удалено $remote_removed_count файлов (${remote_removed_size_mb} MB)"
            else
                log_info "Удаленных файлов для удаления не найдено"
            fi
        else
            log_error "❌ Ошибка выполнения очистки на удаленном сервере"
        fi
    fi
    
    echo "$remote_removed_count $remote_removed_size"
}

# Основная функция
main() {
    log_info "🧹 Начало процедуры очистки старых бекапов"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 Режим DRY-RUN активен - файлы не будут удалены"
    fi
    
    # Показать настройки ротации
    log_info "📋 Настройки ротации:"
    log_info "   📅 Хранить дней: ${RETENTION_DAYS:-30}"
    log_info "   📁 Локальная директория: /backup/archives"
    if [ "${REMOTE_ENABLED:-false}" = "true" ]; then
        log_info "   🌐 Удаленная директория: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${PROJECT_NAME}"
    fi
    
    echo
    
    # Выполнение очистки
    local start_time=$(date +%s)
    
    # Очистка локальных бекапов
    local local_stats
    local_stats=$(cleanup_local_backups)
    local local_removed_count=$(echo "$local_stats" | cut -d' ' -f1)
    local local_removed_size=$(echo "$local_stats" | cut -d' ' -f2)
    
    echo
    
    # Очистка удаленных бекапов
    local remote_stats
    remote_stats=$(cleanup_remote_backups)
    local remote_removed_count=$(echo "$remote_stats" | cut -d' ' -f1)
    local remote_removed_size=$(echo "$remote_stats" | cut -d' ' -f2)
    
    # Подсчет итогов
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local total_removed=$((local_removed_count + remote_removed_count))
    local total_size=$((local_removed_size + remote_removed_size))
    local total_size_mb=$((total_size / 1024 / 1024))
    
    echo
    log_info "📊 Итоги очистки:"
    log_info "   🗑️  Всего удалено файлов: $total_removed"
    log_info "   💾 Всего освобождено места: ${total_size_mb} MB"
    log_info "   📍 Локально: $local_removed_count файлов"
    log_info "   🌐 Удаленно: $remote_removed_count файлов"
    log_info "   ⏱️  Время выполнения: ${duration}с"
    
    # Уведомление в Telegram
    if [ $total_removed -gt 0 ]; then
        notify_cleanup "$PROJECT_NAME" "$total_removed" "${total_size_mb} MB"
        log_success "Очистка завершена успешно!"
    else
        log_info "Файлов для удаления не найдено"
    fi
}

# Запуск основной функции
main "$@"
