# 🚀 Быстрый старт - Система бекапов

## Для OneeDev (готовое решение)

```bash
# 1. Установка системы бекапов
cd onedev
./install-backup.sh

# 2. Настройка конфигурации
nano backup/config/backup.env
# Укажите:
# - DB_PASSWORD=ваш_пароль_БД
# - REMOTE_HOST=сервер.бекапов.ком
# - TELEGRAM_BOT_TOKEN=токен_бота
# - TELEGRAM_CHAT_ID=id_чата

# 3. Копирование SSH ключа на сервер бекапов
ssh-copy-id -i backup/ssh/id_rsa.pub backup@сервер.бекапов.ком

# 4. Запуск с бекапами
docker compose --profile backup up -d

# 5. Тестирование
docker exec onedev-backup /app/scripts/entrypoint.sh test-connection
docker exec onedev-backup /app/scripts/entrypoint.sh backup --dry-run
```

## Для других проектов (шаблон)

```bash
# 1. Скопируйте и настройте шаблон
cp backup-system/install-template.sh your-project/install-backup.sh

# 2. Отредактируйте переменные в начале файла:
nano your-project/install-backup.sh
# PROJECT_NAME="registry"
# PROJECT_DESCRIPTION="Docker Registry"
# PROJECT_VOLUMES="registry-data"
# PROJECT_DB_ENABLED="false"

# 3. Запустите установку
cd your-project
./install-backup.sh

# 4. Добавьте секцию backup в docker-compose.yml
# (содержимое будет в backup/docker-compose-backup.yml)

# 5. Настройте и запустите
nano backup/config/backup.env
docker compose --profile backup up -d
```

## Основные команды

```bash
# Тестирование соединений
docker exec <project>-backup /app/scripts/entrypoint.sh test-connection

# Бекап в тестовом режиме
docker exec <project>-backup /app/scripts/entrypoint.sh backup --dry-run

# Полный бекап
docker exec <project>-backup /app/scripts/entrypoint.sh backup

# Только база данных
docker exec <project>-backup /app/scripts/entrypoint.sh backup --database-only

# Только volumes
docker exec <project>-backup /app/scripts/entrypoint.sh backup --volumes-only

# Очистка старых бекапов
docker exec <project>-backup /app/scripts/entrypoint.sh cleanup

# Справка
docker exec <project>-backup /app/scripts/entrypoint.sh help
```

## Мониторинг

```bash
# Логи контейнера
docker logs <project>-backup

# Файл логов
tail -f <project>/backup/logs/backup.log

# Размер бекапов
du -h <project>/backup/archives/
```

## Настройка Telegram бота

1. Создайте бота: [@BotFather](https://t.me/BotFather) → `/newbot`
2. Получите токен бота
3. Узнайте chat_id:
   ```bash
   # Отправьте сообщение боту, затем:
   curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
   ```
4. Укажите в конфигурации:
   ```bash
   TELEGRAM_BOT_TOKEN=ваш_токен
   TELEGRAM_CHAT_ID=ваш_chat_id
   ```

## Планировщик

Контейнер автоматически создает cron задания:
- **Ежедневно в 2:00** - полный бекап
- **Воскресенье в 1:00** - проверка соединений  
- **1 число месяца в 3:00** - очистка старых бекапов

Для изменения расписания:
```bash
BACKUP_SCHEDULE="0 3 * * *"  # Каждый день в 3:00
```
