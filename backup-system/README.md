# 🛠️ Универсальная система бекапов

Модульная и гибкая система для создания бекапов баз данных PostgreSQL и Docker volumes с возможностью отправки на удаленный сервер и уведомлений в Telegram.

## 🚀 Особенности

- ✅ Бекап PostgreSQL баз данных
- ✅ Бекап Docker volumes  
- ✅ Отправка на удаленный сервер по SSH
- ✅ Telegram уведомления
- ✅ Автоматическая ротация бекапов
- ✅ Dry-run режим для тестирования
- ✅ Модульная архитектура
- ✅ Подробное логирование
- ✅ Планировщик задач
- ✅ Изоляция в Docker контейнере

## 📁 Структура проекта

```
backup-system/
├── Dockerfile                 # Образ для системы бекапов
├── scripts/
│   ├── entrypoint.sh         # Точка входа
│   ├── backup.sh             # Основной скрипт бекапа
│   ├── test-connection.sh    # Тестирование соединений
│   ├── cleanup.sh            # Очистка старых бекапов
│   ├── scheduler.sh          # Планировщик задач
│   ├── help.sh               # Справка
│   └── lib/
│       ├── logger.sh         # Библиотека логирования
│       ├── config.sh         # Работа с конфигурацией
│       └── telegram.sh       # Telegram уведомления
└── config/
    └── backup.env.example    # Пример конфигурации
```

## ⚙️ Настройка

### 1. Подготовка системы бекапов

```bash
# Сборка образа системы бекапов
cd backup-system
docker build -t backup-system .
```

### 2. Настройка проекта (на примере OneeDev)

```bash
# Создание директорий
mkdir -p onedev/backup/{config,logs,archives,ssh}

# Копирование конфигурации
cp backup-system/config/backup.env.example onedev/backup/config/backup.env

# Редактирование конфигурации
nano onedev/backup/config/backup.env
```

### 3. Настройка SSH ключей (для удаленного сервера)

```bash
# Генерация SSH ключа
ssh-keygen -t rsa -b 4096 -f onedev/backup/ssh/id_rsa -N ""

# Копирование публичного ключа на удаленный сервер
ssh-copy-id -i onedev/backup/ssh/id_rsa.pub backup@backup-server.example.com
```

### 4. Настройка Telegram бота

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен бота
3. Узнайте ваш chat_id: отправьте сообщение боту и проверьте через API:
   ```bash
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
   ```

## 🔧 Конфигурация

Основные параметры в файле `backup.env`:

```bash
# Настройки проекта
PROJECT_NAME=onedev
PROJECT_DESCRIPTION="OneDev Git Server"

# Компоненты бекапа
BACKUP_VOLUMES=true
BACKUP_DATABASE=true

# База данных
DB_ENABLED=true
DB_HOST=onedev-db
DB_NAME=onedev
DB_USER=onedev
DB_PASSWORD=your_password

# Volumes для бекапа
VOLUMES_LIST=onedev-data,onedev-db-data

# Удаленный сервер
REMOTE_ENABLED=true
REMOTE_HOST=backup-server.example.com
REMOTE_USER=backup
REMOTE_PATH=/backups/onedev

# Telegram
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# Ротация бекапов
RETENTION_DAYS=30

# Расписание (cron)
BACKUP_SCHEDULE="0 2 * * *"  # Каждый день в 2:00
```

## 🐳 Docker Compose

Добавьте в ваш `docker-compose.yml`:

```yaml
services:
  backup:
    build:
      context: ../backup-system
      dockerfile: Dockerfile
    container_name: onedev-backup
    restart: unless-stopped
    depends_on:
      onedev-db:
        condition: service_healthy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./backup/config:/app/config:ro
      - ./backup/logs:/app/logs
      - ./backup/archives:/backup/archives
      - ./backup/ssh:/app/config/ssh:ro
      - onedev-data:/backup-volumes/onedev-data:ro
      - onedev-db-data:/backup-volumes/onedev-db-data:ro
    networks:
      - onedev-net
    profiles:
      - backup
    command: schedule
```

## 📋 Использование

### Запуск с профилем backup

```bash
# Запуск сервисов с бекапом
docker compose --profile backup up -d

# Только система бекапов
docker compose up backup -d
```

### Команды управления

```bash
# Тестирование всех соединений
docker exec onedev-backup /app/scripts/entrypoint.sh test-connection

# Полный бекап в тестовом режиме
docker exec onedev-backup /app/scripts/entrypoint.sh backup --dry-run

# Бекап только базы данных
docker exec onedev-backup /app/scripts/entrypoint.sh backup --database-only

# Бекап только volumes
docker exec onedev-backup /app/scripts/entrypoint.sh backup --volumes-only

# Бекап без отправки на удаленный сервер
docker exec onedev-backup /app/scripts/entrypoint.sh backup --no-remote

# Очистка старых бекапов
docker exec onedev-backup /app/scripts/entrypoint.sh cleanup

# Справка
docker exec onedev-backup /app/scripts/entrypoint.sh help
```

### Просмотр логов

```bash
# Логи системы бекапов
docker logs onedev-backup

# Файл логов
tail -f onedev/backup/logs/backup.log

# Логи cron
docker exec onedev-backup tail -f /app/logs/cron.log
```

## 🔄 Автоматизация

### Планировщик в контейнере

По умолчанию контейнер запускается с командой `schedule`, которая:
- Настраивает cron задания
- Выполняет ежедневные бекапы
- Еженедельно проверяет соединения
- Ежемесячно очищает старые бекапы

### Внешний cron (альтернатива)

```bash
# Добавить в crontab хоста
crontab -e

# Ежедневный бекап в 2:00
0 2 * * * docker exec onedev-backup /app/scripts/entrypoint.sh backup

# Еженедельная проверка соединений
0 1 * * 0 docker exec onedev-backup /app/scripts/entrypoint.sh test-connection
```

## 🎯 Применение к другим проектам

### Для Registry

```bash
# Создание структуры
mkdir -p registry/backup/{config,logs,archives,ssh}

# Копирование и настройка конфигурации
cp backup-system/config/backup.env.example registry/backup/config/backup.env

# Редактирование для registry
sed -i 's/PROJECT_NAME=onedev/PROJECT_NAME=registry/' registry/backup/config/backup.env
sed -i 's/VOLUMES_LIST=onedev-data,onedev-db-data/VOLUMES_LIST=registry-data/' registry/backup/config/backup.env
```

### Для любого проекта

1. Скопируйте структуру `backup/`
2. Настройте `backup.env` под ваш проект
3. Добавьте сервис backup в docker-compose.yml
4. Укажите нужные volumes в конфигурации

## 🛠️ Устранение неисправностей

### Проверка конфигурации

```bash
# Тест всех соединений
docker exec onedev-backup /app/scripts/entrypoint.sh test-connection

# Просмотр конфигурации
docker exec onedev-backup cat /app/config/backup.env
```

### Отладка

```bash
# Включить подробные логи
echo "LOG_LEVEL=DEBUG" >> onedev/backup/config/backup.env

# Перезапуск с новой конфигурацией
docker compose restart backup
```

### Частые проблемы

1. **Ошибка подключения к БД**: Проверьте параметры подключения и доступность сервиса
2. **SSH ошибки**: Проверьте SSH ключи и доступность удаленного сервера
3. **Docker volumes**: Убедитесь что volumes существуют и доступны
4. **Telegram**: Проверьте токен бота и chat_id

## 📊 Мониторинг

- 📱 Telegram уведомления о статусе операций
- 📝 Подробные логи в файлах
- 🔍 Healthcheck контейнера
- 📈 Статистика размеров и времени выполнения

## 🔒 Безопасность

- Изоляция в отдельном контейнере
- SSH ключи для безопасного доступа
- Безопасное хранение паролей в переменных окружения
- Минимальные права доступа
- Логирование всех операций

## 🚀 Лучшие практики

1. **Тестирование**: Всегда используйте `--dry-run` перед настройкой автоматических бекапов
2. **Мониторинг**: Настройте Telegram уведомления для контроля статуса
3. **Ротация**: Настройте правильные параметры хранения бекапов
4. **Безопасность**: Используйте SSH ключи и ограничьте доступ к удаленному серверу
5. **Тестирование восстановления**: Регулярно проверяйте возможность восстановления из бекапов
