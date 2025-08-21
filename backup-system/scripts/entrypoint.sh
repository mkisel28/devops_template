#!/bin/bash

# ===========================================
# УНИВЕРСАЛЬНАЯ СИСТЕМА БЕКАПОВ
# Автор: DevOps Engineer
# Версия: 1.0
# ===========================================

set -euo pipefail

# Загрузка библиотек
source /app/scripts/lib/logger.sh
source /app/scripts/lib/config.sh
source /app/scripts/lib/telegram.sh

# Инициализация
init_logger
load_config

log_info "🚀 Запуск системы бекапов для проекта: $PROJECT_NAME"
log_info "📝 Описание: $PROJECT_DESCRIPTION"

# Обработка аргументов командной строки
ACTION="${1:-backup}"

case "$ACTION" in
    "test-connection")
        log_info "🔌 Запуск проверки соединения с удаленным сервером..."
        /app/scripts/test-connection.sh
        ;;
    "backup")
        log_info "💾 Запуск процедуры бекапа..."
        /app/scripts/backup.sh "${@:2}"
        ;;
    "restore")
        log_info "🔄 Запуск процедуры восстановления..."
        /app/scripts/restore.sh "${@:2}"
        ;;
    "cleanup")
        log_info "🧹 Запуск очистки старых бекапов..."
        /app/scripts/cleanup.sh
        ;;
    "schedule")
        log_info "⏰ Запуск планировщика бекапов..."
        /app/scripts/scheduler.sh
        ;;
    "help"|"-h"|"--help")
        /app/scripts/help.sh
        ;;
    *)
        log_error "❌ Неизвестная команда: $ACTION"
        log_info "💡 Используйте 'help' для просмотра доступных команд"
        exit 1
        ;;
esac

log_info "✅ Выполнение завершено успешно"
