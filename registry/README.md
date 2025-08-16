# Docker Registry with UI and Trivy Scanner

Полный Docker Compose setup для Docker Registry с веб-интерфейсом и сканнером безопасности Trivy.

## Компоненты

- **Docker Registry 2**: Основной registry для хранения Docker образов
- **Registry UI**: Веб-интерфейс для просмотра и управления образами
- **Trivy**: Сканнер безопасности для проверки уязвимостей
- **Nginx**: Reverse proxy для production окружения

## Быстрый старт

### Development окружение

```bash
cd registry
./manage.sh start dev
```

### Production окружение

```bash
cd registry
./manage.sh start prod
```

## Доступные сервисы

После запуска сервисы будут доступны по следующим адресам:

### Development
- Registry API: http://localhost:5000
- Registry UI: http://localhost:8080
- Trivy Scanner: http://localhost:8081

### Production (с Nginx)
- Registry API: http://localhost/v2/
- Registry UI: http://localhost:8080
- Trivy Scanner: http://localhost:8081
- Nginx Proxy: http://localhost

## Конфигурация

### Файлы окружения

- `.env.dev` - Настройки для development
- `.env.prod` - Настройки для production

### Основные параметры

```bash
# Порты сервисов
REGISTRY_PORT=5000
REGISTRY_UI_PORT=8080
TRIVY_PORT=8081

# Аутентификация
REGISTRY_USERNAME=admin
REGISTRY_PASSWORD=your-password

# SSL/TLS
SSL_ENABLED=true/false
REGISTRY_DOMAIN=your-domain.com
```

## Управление

Используйте скрипт `manage.sh` для управления сервисами:

```bash
# Запуск сервисов
./manage.sh start [dev|prod]

# Остановка сервисов
./manage.sh stop [dev|prod]

# Перезапуск сервисов
./manage.sh restart [dev|prod]

# Просмотр логов
./manage.sh logs

# Статус сервисов
./manage.sh status

# Тестирование (загрузка тестового образа)
./manage.sh test

# Очистка всех данных
./manage.sh clean

# Справка
./manage.sh help
```

## Работа с Registry

### Аутентификация

```bash


# Используйте учетные данные из .env файла
```

### Загрузка образа

```bash
# Тегирование образа
docker tag my-image localhost:5000/my-image:latest

# Загрузка в registry
docker push localhost:5000/my-image:latest
```

### Скачивание образа

```bash
docker pull localhost:5000/my-image:latest
```

## Сканирование безопасности с Trivy

### Сканирование локального образа

```bash
trivy image my-image:latest
```

### Сканирование образа из registry

```bash
trivy image localhost:5000/my-image:latest
```

### Использование Trivy сервера

```bash
# Сканирование через API
curl -X POST "http://localhost:8081/twirp/trivy.scanner.v1.Scanner/Scan" \
  -H "Content-Type: application/json" \
  -d '{"artifact_reference": "localhost:5000/my-image:latest"}'
```

## Структура проекта

```
registry/
├── docker-compose.yml          # Основной Docker Compose файл
├── .env.dev                    # Development конфигурация
├── .env.prod                   # Production конфигурация
├── manage.sh                   # Скрипт управления
├── config/
│   └── registry.yml            # Конфигурация Registry
├── auth/
│   └── htpasswd               # Файл аутентификации (создается автоматически)
├── certs/
│   ├── domain.crt             # SSL сертификат
│   └── domain.key             # SSL ключ
└── nginx/
    ├── nginx.conf             # Основная конфигурация Nginx
    ├── conf.d/
    │   └── registry.conf      # Конфигурация proxy для registry
    └── logs/                  # Логи Nginx
```

## Безопасность

### Development
- Используются самоподписанные сертификаты
- Базовая HTTP аутентификация
- Локальные домены (localhost)

### Production
- Необходимы настоящие SSL сертификаты
- Сильные пароли
- Правильная настройка доменов
- Firewall настройки

## Мониторинг

### Healthcheck

Registry имеет встроенный health endpoint:

```bash
curl http://localhost:5000/v2/
```

### Логи

```bash
# Все сервисы
./manage.sh logs

# Конкретный сервис
docker compose logs registry
docker compose logs registry-ui
docker compose logs trivy
```

## Troubleshooting

### Проблемы с сертификатами

```bash
# Пересоздание сертификатов
rm -rf certs/*
./manage.sh restart dev
```

### Проблемы с аутентификацией

```bash
# Пересоздание файла паролей
rm -rf auth/htpasswd
./manage.sh restart dev
```

### Очистка данных

```bash
# Полная очистка
./manage.sh clean dev
```

## Производительность

### Увеличение лимитов

- Настройка `client_max_body_size` в Nginx для больших образов
- Увеличение timeout'ов для медленных соединений
- Настройка кэширования для Trivy

### Масштабирование

- Использование внешнего storage (S3, GCS)
- Кластеризация registry
- Load balancing с несколькими экземплярами

## Backup

### Данные Registry

```bash
# Backup volume
docker run --rm -v registry_registry_data:/data -v $(pwd):/backup alpine tar czf /backup/registry-backup.tar.gz -C /data .

# Restore volume
docker run --rm -v registry_registry_data:/data -v $(pwd):/backup alpine tar xzf /backup/registry-backup.tar.gz -C /data
```

### Конфигурация

```bash
# Backup конфигурации
tar czf config-backup.tar.gz config/ auth/ certs/ nginx/ *.env
```
