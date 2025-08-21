#!/bin/bash

# ===========================================
# СПРАВКА ПО СИСТЕМЕ БЕКАПОВ
# ===========================================

cat << 'EOF'
🛠️  УНИВЕРСАЛЬНАЯ СИСТЕМА БЕКАПОВ
====================================

📖 ОПИСАНИЕ:
  Модульная система для создания бекапов баз данных PostgreSQL и Docker volumes
  с возможностью отправки на удаленный сервер и уведомлений в Telegram.

🚀 ОСНОВНЫЕ КОМАНДЫ:

  backup                    - Создать полный бекап (БД + volumes)
  test-connection          - Проверить все соединения
  cleanup                  - Очистить старые бекапы
  restore                  - Восстановить из бекапа
  schedule                 - Запустить планировщик
  help                     - Показать эту справку

🔧 ОПЦИИ КОМАНДЫ BACKUP:

  --dry-run               - Тестовый режим (не выполнять реальные операции)
  --volumes-only          - Создать бекап только volumes
  --database-only         - Создать бекап только базы данных
  --no-remote            - Не отправлять на удаленный сервер

📋 ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:

  # Полный бекап в тестовом режиме
  docker exec backup-container /app/scripts/entrypoint.sh backup --dry-run

  # Бекап только базы данных
  docker exec backup-container /app/scripts/entrypoint.sh backup --database-only

  # Проверка соединений
  docker exec backup-container /app/scripts/entrypoint.sh test-connection

  # Бекап только volumes без отправки на удаленный сервер
  docker exec backup-container /app/scripts/entrypoint.sh backup --volumes-only --no-remote

⚙️  КОНФИГУРАЦИЯ:

  Основной файл конфигурации: /app/config/backup.env
  
  Основные параметры:
  - PROJECT_NAME           - Имя проекта
  - BACKUP_VOLUMES         - Включить бекап volumes (true/false)
  - BACKUP_DATABASE        - Включить бекап БД (true/false)
  - REMOTE_ENABLED         - Включить отправку на удаленный сервер
  - TELEGRAM_ENABLED       - Включить Telegram уведомления
  - DRY_RUN               - Тестовый режим по умолчанию

📂 СТРУКТУРА ДИРЕКТОРИЙ:

  /backup/temp/           - Временные файлы
  /backup/archives/       - Локальные архивы
  /app/logs/             - Файлы логов
  /app/config/           - Конфигурационные файлы
  /app/scripts/          - Исполняемые скрипты

🔐 БЕЗОПАСНОСТЬ:

  • SSH ключи для доступа к удаленному серверу
  • Изоляция в отдельном контейнере
  • Логирование всех операций
  • Безопасное хранение паролей в переменных окружения

📱 TELEGRAM УВЕДОМЛЕНИЯ:

  Для настройки уведомлений:
  1. Создайте Telegram бота через @BotFather
  2. Получите токен бота
  3. Узнайте ваш chat_id (отправьте сообщение боту и проверьте через API)
  4. Укажите TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID в конфигурации

🔄 АВТОМАТИЗАЦИЯ:

  Для автоматического выполнения бекапов настройте cron:
  
  # Ежедневно в 2:00
  0 2 * * * docker exec backup-container /app/scripts/entrypoint.sh backup

  # Еженедельная проверка соединений
  0 1 * * 0 docker exec backup-container /app/scripts/entrypoint.sh test-connection

📊 МОНИТОРИНГ:

  • Логи доступны в /app/logs/backup.log
  • Telegram уведомления о статусе операций
  • Возврат кодов ошибок для интеграции с мониторингом

🆘 УСТРАНЕНИЕ НЕИСПРАВНОСТЕЙ:

  1. Проверьте конфигурацию: show-config
  2. Проверьте соединения: test-connection
  3. Запустите в режиме отладки: LOG_LEVEL=DEBUG
  4. Проверьте логи: /app/logs/backup.log

📧 ПОДДЕРЖКА:

  При возникновении проблем:
  1. Проверьте логи системы
  2. Убедитесь в правильности конфигурации
  3. Проверьте сетевые соединения
  4. Проверьте права доступа к volumes и удаленному серверу

EOF
