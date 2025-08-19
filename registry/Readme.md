# Docker Registry (UI + Nginx)

Приватный Docker Registry с веб‑интерфейсом и реверс‑прокси Nginx. Аутентификация через htpasswd. Данные реестра сохраняются в volume.

## Состав
- registry: `registry:2.8.2` (порт 5000 внутри сети)
- UI: `joxit/docker-registry-ui` (доступ только через Nginx)
- nginx: реверс‑прокси к UI и /v2/ API (порт `${NGINX_HTTP_PORT}` наружу)
- авторизация: basic auth (файл `auth/htpasswd`), создаётся автоматически

## Быстрая установка

### Автоматическая установка
Для автоматической установки Docker Registry с настройкой пользователя и всех зависимостей:

```bash
# Запуск от обычного пользователя с sudo правами
./install.sh
```

Скрипт автоматически:
- Установит Docker и Docker Compose
- Создаст пользователя `registry` и добавит его в группу docker
- Установит необходимые зависимости (apache2-utils для htpasswd)
- Скопирует файлы в `/home/registry/registry/`
- Создаст файл `.env` из шаблона
- Сгенерирует секретные ключи
- Запустит систему

### Ручная настройка
Если нужна ручная настройка окружения:

1. Скопируйте окружение и при необходимости поправьте значения:
   ```bash
   cp .env.example .env
   ```
   
2. Отредактируйте важные переменные в `.env`:
   - `REGISTRY_DOMAIN` — домен/хост, по которому будет доступен proxy (по умолчанию localhost)
   - `NGINX_HTTP_PORT` — внешний порт Nginx (по умолчанию 80)
   - `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` — логин/пароль для UI и Registry
   - `REGISTRY_SECURED` — `true`, если доступ к реестру через https‑прокси (переменная для UI)

3. Убедитесь, что установлены Docker и Docker Compose v2.

## Структура скриптов

### `install.sh` - Главный скрипт установки
- Устанавливает Docker и все зависимости
- Создает пользователя `registry`
- Автоматически запускает систему

### `02-check-install-docker.sh` - Установка Docker (вызывается автоматически)
- Устанавливает Docker и Docker Compose plugin
- Настраивает пользователя для работы с Docker
- Генерирует секретные ключи

### `03-up.sh` - Запуск системы (вызывается автоматически)
- Проверяет зависимости
- Настраивает аутентификацию
- Запускает все сервисы
- Проверяет готовность системы

### `manage.sh` - Управление запущенной системой
- Простое управление уже установленной системой
- Должен запускаться от пользователя `registry`

## Управление системой

### После установки
После успешной автоматической установки переключитесь на пользователя `registry`:

```bash
sudo -iu registry
cd ~/registry
```

### Команды управления
```bash
./manage.sh start    # запуск сервисов
./manage.sh stop     # остановка сервисов  
./manage.sh restart  # перезапуск сервисов
./manage.sh build    # сборка образов (если меняли конфигурацию)
./manage.sh test     # загрузка тестового образа (hello-world) в реестр
./manage.sh help     # справка по командам
```

### Альтернативный запуск
Если система уже установлена, можно запустить напрямую:

```bash
# От пользователя registry
./03-up.sh
```

## Доступ
- **Web UI**: `http://<REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>`
- **Docker Registry API**: `http://<REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>/v2/`
- **Авторизация**: используйте `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` из `.env`

По умолчанию:
- Web UI: http://localhost:80
- Username: registry  
- Password: генерируется автоматически при установке

## Использование Docker

### Авторизация в registry
```bash
docker login localhost:80 -u registry -p <GENERATED_PASSWORD>
```

### Работа с образами
```bash
# Пример с alpine
docker pull alpine:3.19
docker tag alpine:3.19 localhost:80/alpine:3.19  
docker push localhost:80/alpine:3.19

# Загрузка образа из registry
docker pull localhost:80/alpine:3.19
```

### Тестирование
```bash
# Автоматический тест загрузки hello-world образа
./manage.sh test
```

## Безопасность

### HTTP vs HTTPS
⚠️ **Внимание**: По умолчанию registry работает по HTTP. Для production окружения:

1. Настройте HTTPS на уровне Nginx
2. Обновите `REGISTRY_SECURED=true` в `.env`
3. Для HTTP доступа не с localhost добавьте registry в insecure-registries:

```json
// /etc/docker/daemon.json
{
  "insecure-registries": ["your-registry-host:port"]
}
```

Затем перезапустите Docker: `sudo systemctl restart docker`

### Управление пользователями
Для добавления новых пользователей в htpasswd:

```bash
# От пользователя registry
htpasswd -B auth/htpasswd newuser
# или через Docker если htpasswd не установлен
docker run --rm httpd:2.4-alpine htpasswd -Bbn newuser newpassword >> auth/htpasswd
```

## Мониторинг и логи

### Проверка статуса
```bash
# Статус контейнеров
docker compose ps

# Логи всех сервисов
docker compose logs

# Логи конкретного сервиса
docker compose logs registry
docker compose logs registry-ui  
docker compose logs nginx
```

### Проверка работоспособности
```bash
# Проверка API registry
curl http://localhost:80/v2/

# Проверка каталога образов
curl -u registry:password http://localhost:80/v2/_catalog
```

## Структура файлов
```
registry/
├── install.sh                    # Главный скрипт установки
├── 02-check-install-docker.sh   # Установка Docker и зависимостей  
├── 03-up.sh                     # Запуск системы
├── manage.sh                    # Управление сервисами
├── docker-compose.yml           # Конфигурация сервисов
├── .env.example                 # Шаблон переменных окружения
├── .env                         # Переменные окружения (создается автоматически)
├── config/
│   └── registry.yml            # Конфигурация Registry
├── nginx/
│   ├── nginx.conf              # Основная конфигурация Nginx
│   └── conf.d/
│       └── registry.conf       # Конфигурация прокси для registry
└── auth/
    └── htpasswd                # Файл паролей (создается автоматически)
```

## Остановка и очистка

### Остановка сервисов
```bash
./manage.sh stop
```

### Полная очистка
```bash
# Остановка с удалением всех данных
docker compose down -v

# Удаление образов (опционально)
docker system prune -a
```

### Удаление пользователя (опционально)
```bash
# Если нужно полностью удалить установку
sudo userdel -r registry
```

## Устранение неполадок

### Частые проблемы

1. **Ошибка доступа к Docker**
   ```bash
   # Проверить группу docker
   groups
   # Если нет группы docker, добавить пользователя
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Порт уже занят**
   ```bash
   # Изменить NGINX_HTTP_PORT в .env
   nano .env
   ```

3. **Проблемы с аутентификацией**
   ```bash
   # Пересоздать htpasswd файл
   rm auth/htpasswd
   ./manage.sh start
   ```

4. **Недостаточно места**
   ```bash
   # Очистка неиспользуемых образов
   docker system prune
   ```

### Логи для диагностики
```bash
# Подробные логи установки
./install.sh 2>&1 | tee install.log

# Логи сервисов
docker compose logs --follow
```
