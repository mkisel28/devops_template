#!/bin/bash

# ===========================================
# БИБЛИОТЕКА ЛОГИРОВАНИЯ
# ===========================================

# Цвета для консольного вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Уровни логирования
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Текущий уровень логирования (по умолчанию INFO)
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Инициализация логгера
init_logger() {
    # Создание директории для логов
    mkdir -p "$(dirname "${LOG_FILE:-/app/logs/backup.log}")"
    
    # Установка уровня логирования
    case "${LOG_LEVEL:-INFO}" in
        "DEBUG") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "INFO")  CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "WARN")  CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "ERROR") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
    esac
    
    log_info "📋 Логгер инициализирован. Уровень: ${LOG_LEVEL:-INFO}"
}

# Функция для вывода лога с timestamp
_log() {
    local level="$1"
    local color="$2"
    local level_num="$3"
    local message="$4"
    
    # Проверка уровня логирования
    if [ "$level_num" -lt "$CURRENT_LOG_LEVEL" ]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"
    
    # Вывод в консоль с цветом
    echo -e "${color}${log_line}${NC}"
    
    # Запись в файл (если определен)
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$log_line" >> "$LOG_FILE"
        
        # Ротация логов если превышен размер
        if [ -f "$LOG_FILE" ] && [ -n "${MAX_LOG_SIZE:-}" ]; then
            local max_size_bytes=$(echo "${MAX_LOG_SIZE}" | sed 's/M/*1024*1024/g' | sed 's/K/*1024/g' | bc 2>/dev/null || echo "10485760")
            local current_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
            
            if [ "$current_size" -gt "$max_size_bytes" ]; then
                mv "$LOG_FILE" "${LOG_FILE}.old"
                echo "[$timestamp] [INFO] 🔄 Ротация лог-файла выполнена" > "$LOG_FILE"
            fi
        fi
    fi
}

# Функции логирования разных уровней
log_debug() {
    _log "DEBUG" "$CYAN" "$LOG_LEVEL_DEBUG" "$1"
}

log_info() {
    _log "INFO" "$GREEN" "$LOG_LEVEL_INFO" "$1"
}

log_warn() {
    _log "WARN" "$YELLOW" "$LOG_LEVEL_WARN" "$1"
}

log_error() {
    _log "ERROR" "$RED" "$LOG_LEVEL_ERROR" "$1"
}

log_success() {
    _log "SUCCESS" "$GREEN" "$LOG_LEVEL_INFO" "✅ $1"
}

log_step() {
    _log "STEP" "$BLUE" "$LOG_LEVEL_INFO" "🔄 $1"
}

# Функция для логирования выполнения команд
log_command() {
    local cmd="$1"
    local description="$2"
    
    log_debug "🖥️  Выполнение команды: $cmd"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "🔍 [DRY-RUN] $description"
        log_debug "🔍 [DRY-RUN] Команда: $cmd"
        return 0
    fi
    
    log_step "$description"
    
    if eval "$cmd"; then
        log_success "$description - завершено"
        return 0
    else
        local exit_code=$?
        log_error "$description - ошибка (код: $exit_code)"
        return $exit_code
    fi
}

# Функция для отображения прогресса
show_progress() {
    local current="$1"
    local total="$2"
    local operation="$3"
    
    local percent=$((current * 100 / total))
    local progress_bar=""
    local filled=$((percent / 2))
    
    for i in $(seq 1 50); do
        if [ $i -le $filled ]; then
            progress_bar="${progress_bar}█"
        else
            progress_bar="${progress_bar}░"
        fi
    done
    
    printf "\r${BLUE}[%s] %s %d%% (%d/%d)${NC}" "$progress_bar" "$operation" "$percent" "$current" "$total"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
        log_success "$operation завершено"
    fi
}
