#!/bin/bash

# ===========================================
# ОСНОВНОЙ СКРИПТ БЕКАПА
# ===========================================

set -euo pipefail

# Загрузка библиотек
source /app/scripts/lib/logger.sh
source /app/scripts/lib/config.sh
source /app/scripts/lib/telegram.sh

init_logger
load_config

# Глобальные переменные
BACKUP_START_TIME=$(date +%s)
BACKUP_TEMP_DIR="/backup/temp/$(date +%Y%m%d_%H%M%S)"
BACKUP_ARCHIVE_DIR="/backup/archives"
BACKUP_FILES_CREATED=()
BACKUP_TOTAL_SIZE=0

# Очистка временных файлов при выходе
cleanup_on_exit() {
    local exit_code=$?
    
    if [ -d "$BACKUP_TEMP_DIR" ]; then
        log_debug "🧹 Очистка временных файлов: $BACKUP_TEMP_DIR"
        rm -rf "$BACKUP_TEMP_DIR" 2>/dev/null || true
    fi
    
    if [ $exit_code -ne 0 ]; then
        local duration=$(($(date +%s) - BACKUP_START_TIME))
        local duration_formatted=$(format_duration $duration)
        
        notify_backup_error \
            "${PROJECT_NAME:-unknown}" \
            "$(get_backup_type_description)" \
            "Процесс бекапа прерван с кодом $exit_code" \
            "$duration_formatted"
    fi
    
    exit $exit_code
}

trap cleanup_on_exit EXIT

# Форматирование времени
format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}ч ${minutes}м ${seconds}с"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}м ${seconds}с"
    else
        echo "${seconds}с"
    fi
}

# Получить описание типа бекапа
get_backup_type_description() {
    local types=()
    
    [ "${BACKUP_DATABASE:-false}" = "true" ] && types+=("База данных")
    [ "${BACKUP_VOLUMES:-false}" = "true" ] && types+=("Volumes")
    
    if [ ${#types[@]} -eq 0 ]; then
        echo "Нет активных компонентов"
    else
        local IFS=", "
        echo "${types[*]}"
    fi
}

# Создание директорий для бекапа
prepare_backup_directories() {
    log_step "Подготовка директорий для бекапа..."
    
    mkdir -p "$BACKUP_TEMP_DIR"
    mkdir -p "$BACKUP_ARCHIVE_DIR"
    
    log_debug "📁 Временная директория: $BACKUP_TEMP_DIR"
    log_debug "📁 Директория архивов: $BACKUP_ARCHIVE_DIR"
}

# Бекап базы данных PostgreSQL
backup_database() {
    if [ "${DB_ENABLED:-false}" != "true" ] || [ "${BACKUP_DATABASE:-false}" != "true" ]; then
        log_debug "🗄️  Бекап базы данных пропущен"
        return 0
    fi
    
    log_step "Создание бекапа базы данных PostgreSQL..."
    
    local db_backup_file="$BACKUP_TEMP_DIR/$(generate_backup_filename "db" "$DB_NAME")"
    local compression_cmd=$(get_compression_cmd)
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Бекап БД: $DB_NAME -> $db_backup_file"
        # Создаем пустой файл для тестирования
        touch "$db_backup_file"
    else
        log_debug "🗄️  Подключение к: $DB_HOST:$DB_PORT/$DB_NAME"
        
        # Создание бекапа через контейнер PostgreSQL
        log_debug "🐳 Использование контейнера PostgreSQL для создания бекапа..."
        
        if docker exec -e PGPASSWORD="$DB_PASSWORD" "$DB_HOST" pg_dump \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            --verbose \
            --format=plain \
            --encoding=UTF8 \
            --no-owner \
            --no-privileges \
            --clean \
            --if-exists | $compression_cmd > "$db_backup_file"; then
            
            log_success "Бекап базы данных создан: $(basename "$db_backup_file")"
        else
            log_error "❌ Ошибка создания бекапа базы данных"
            return 1
        fi
    fi
    
    # Проверка размера файла
    if [ -f "$db_backup_file" ]; then
        local file_size=$(stat -f%z "$db_backup_file" 2>/dev/null || stat -c%s "$db_backup_file" 2>/dev/null || echo "0")
        local file_size_mb=$((file_size / 1024 / 1024))
        
        if [ $file_size -gt 0 ]; then
            BACKUP_FILES_CREATED+=("$db_backup_file")
            BACKUP_TOTAL_SIZE=$((BACKUP_TOTAL_SIZE + file_size))
            log_info "📏 Размер бекапа БД: ${file_size_mb} MB"
        else
            log_error "❌ Созданный файл бекапа БД пуст"
        fi
    fi
}

# Бекап Docker volumes
backup_volumes() {
    if [ "${VOLUMES_ENABLED:-false}" != "true" ] || [ "${BACKUP_VOLUMES:-false}" != "true" ]; then
        log_debug "📂 Бекап volumes пропущен"
        return 0
    fi
    
    local volumes_list
    volumes_list=$(get_volumes_list)
    
    if [ -z "$volumes_list" ]; then
        log_warn "⚠️  Список volumes для бекапа пуст"
        return 0
    fi
    
    log_step "Создание бекапа Docker volumes..."
    
    local volume_count=0
    local total_volumes
    total_volumes=$(echo "$volumes_list" | wc -l)
    
    while IFS= read -r volume; do
        [ -z "$volume" ] && continue
        volume_count=$((volume_count + 1))
        
        show_progress $volume_count $total_volumes "Бекап volume '$volume'"
        
        local volume_backup_file="$BACKUP_TEMP_DIR/$(generate_backup_filename "volume" "$volume")"
        local compression_cmd=$(get_compression_cmd)
        
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_debug "🔍 [DRY-RUN] Бекап volume: $volume -> $volume_backup_file"
            # Создаем пустой файл для тестирования
            touch "$volume_backup_file"
        else
            log_debug "📂 Создание бекапа volume: $volume"
            
            # Проверяем что volume смонтирован
            local volume_path="/backup-volumes/$volume"
            if [ ! -d "$volume_path" ]; then
                log_error "❌ Volume '$volume' не найден по пути: $volume_path"
                return 1
            fi
            
            # Создание архива напрямую из смонтированного volume
            if cd "$volume_path" && tar czf "$volume_backup_file" . 2>/dev/null; then
                log_debug "✅ Volume '$volume' скопирован"
            else
                log_error "❌ Ошибка создания бекапа volume: $volume"
                return 1
            fi
        fi
        
        # Проверка размера файла
        if [ -f "$volume_backup_file" ]; then
            local file_size=$(stat -f%z "$volume_backup_file" 2>/dev/null || stat -c%s "$volume_backup_file" 2>/dev/null || echo "0")
            local file_size_mb=$((file_size / 1024 / 1024))
            
            if [ $file_size -gt 0 ]; then
                BACKUP_FILES_CREATED+=("$volume_backup_file")
                BACKUP_TOTAL_SIZE=$((BACKUP_TOTAL_SIZE + file_size))
                log_debug "📏 Размер бекапа volume '$volume': ${file_size_mb} MB"
            else
                log_warn "⚠️  Файл бекапа volume '$volume' пуст"
            fi
        fi
    done <<< "$volumes_list"
    
    log_success "Бекап всех volumes завершен"
}

# Архивирование и перемещение бекапов
archive_backups() {
    if [ ${#BACKUP_FILES_CREATED[@]} -eq 0 ]; then
        log_warn "⚠️  Нет файлов для архивирования"
        return 0
    fi
    
    log_step "Архивирование созданных бекапов..."
    
    local archive_name="${PROJECT_NAME}_full_$(date +%Y%m%d_%H%M%S).tar.gz"
    local archive_path="$BACKUP_ARCHIVE_DIR/$archive_name"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Создание архива: $archive_name"
    else
        # Создание итогового архива
        cd "$BACKUP_TEMP_DIR"
        if tar -czf "$archive_path" .; then
            log_success "Архив создан: $archive_name"
        else
            log_error "❌ Ошибка создания архива"
            return 1
        fi
    fi
    
    # Обновление списка созданных файлов
    BACKUP_FILES_CREATED=("$archive_path")
}

# Отправка бекапов на удаленный сервер
upload_to_remote() {
    if [ "${REMOTE_ENABLED:-false}" != "true" ]; then
        log_debug "🌐 Отправка на удаленный сервер отключена"
        return 0
    fi
    
    if [ ${#BACKUP_FILES_CREATED[@]} -eq 0 ]; then
        log_warn "⚠️  Нет файлов для отправки"
        return 0
    fi
    
    log_step "Отправка бекапов на удаленный сервер..."
    
    local ssh_opts="-o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=no"
    if [ -n "${REMOTE_SSH_KEY:-}" ]; then
        ssh_opts="$ssh_opts -i $REMOTE_SSH_KEY"
    fi
    
    # Создание директории на удаленном сервере
    local remote_project_dir="$REMOTE_PATH/$PROJECT_NAME"
    local remote_daily_dir="$remote_project_dir/$(date +%Y-%m-%d)"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Отправка на ${REMOTE_USER}@${REMOTE_HOST}:$remote_daily_dir"
    else
        log_debug "📁 Создание директории на удаленном сервере: $remote_daily_dir"
        ssh $ssh_opts -p "${REMOTE_PORT:-22}" "${REMOTE_USER}@${REMOTE_HOST}" \
            "mkdir -p '$remote_daily_dir'"
        
        # Отправка каждого файла
        for backup_file in "${BACKUP_FILES_CREATED[@]}"; do
            if [ -f "$backup_file" ]; then
                local filename=$(basename "$backup_file")
                log_debug "📤 Отправка файла: $filename"
                
                if rsync -avz --progress -e "ssh $ssh_opts -p ${REMOTE_PORT:-22}" \
                    "$backup_file" "${REMOTE_USER}@${REMOTE_HOST}:$remote_daily_dir/"; then
                    log_success "Файл отправлен: $filename"
                else
                    log_error "❌ Ошибка отправки файла: $filename"
                    return 1
                fi
            fi
        done
    fi
    
    log_success "Все бекапы отправлены на удаленный сервер"
}

# Очистка старых локальных бекапов
cleanup_local_backups() {
    log_step "Очистка старых локальных бекапов..."
    
    local retention_days="${RETENTION_DAYS:-30}"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] Очистка файлов старше $retention_days дней в $BACKUP_ARCHIVE_DIR"
    else
        local removed_count=0
        local removed_size=0
        
        # Поиск и удаление старых файлов
        if [ -d "$BACKUP_ARCHIVE_DIR" ]; then
            while IFS= read -r -d '' file; do
                local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                removed_count=$((removed_count + 1))
                removed_size=$((removed_size + file_size))
                rm -f "$file"
                log_debug "🗑️  Удален старый бекап: $(basename "$file")"
            done < <(find "$BACKUP_ARCHIVE_DIR" -name "${PROJECT_NAME}_*" -type f -mtime +$retention_days -print0 2>/dev/null)
        fi
        
        if [ $removed_count -gt 0 ]; then
            local removed_size_mb=$((removed_size / 1024 / 1024))
            log_success "Удалено $removed_count старых бекапов (${removed_size_mb} MB)"
        else
            log_info "Старых бекапов для удаления не найдено"
        fi
    fi
}

# Обработка аргументов командной строки
process_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_info "🔍 Включен режим DRY-RUN"
                ;;
            --volumes-only)
                BACKUP_DATABASE=false
                BACKUP_VOLUMES=true
                log_info "📂 Режим: только volumes"
                ;;
            --database-only)
                BACKUP_DATABASE=true
                BACKUP_VOLUMES=false
                log_info "🗄️  Режим: только база данных"
                ;;
            --no-remote)
                REMOTE_ENABLED=false
                log_info "🌐 Отправка на удаленный сервер отключена"
                ;;
            *)
                log_error "❌ Неизвестный аргумент: $1"
                exit 1
                ;;
        esac
        shift
    done
}

# Основная функция
main() {
    log_info "💾 Запуск процедуры бекапа для проекта: $PROJECT_NAME"
    
    # Обработка аргументов
    process_arguments "$@"
    
    # Показать конфигурацию
    show_config
    
    # Уведомление о начале
    notify_backup_start "$PROJECT_NAME" "$(get_backup_type_description)"
    
    echo
    log_info "🚀 Начало создания бекапа..."
    
    # Выполнение этапов бекапа
    prepare_backup_directories
    backup_database
    backup_volumes
    archive_backups
    upload_to_remote
    cleanup_local_backups
    
    # Подсчет итогов
    local end_time=$(date +%s)
    local duration=$((end_time - BACKUP_START_TIME))
    local duration_formatted=$(format_duration $duration)
    local total_size_mb=$((BACKUP_TOTAL_SIZE / 1024 / 1024))
    
    echo
    log_success "Бекап завершен успешно!"
    log_info "⏱️  Общее время: $duration_formatted"
    log_info "📏 Общий размер: ${total_size_mb} MB"
    log_info "📁 Файлов создано: ${#BACKUP_FILES_CREATED[@]}"
    
    # Уведомление об успехе
    notify_backup_success \
        "$PROJECT_NAME" \
        "$(get_backup_type_description)" \
        "$duration_formatted" \
        "${total_size_mb} MB" \
        "${#BACKUP_FILES_CREATED[@]}"
}

# Запуск основной функции
main "$@"
