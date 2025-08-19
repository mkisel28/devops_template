# Docker Registry (UI + Nginx)

Приватный Docker Registry с веб‑интерфейсом и реверс‑прокси Nginx. Аутентификация через htpasswd. Данные реестра сохраняются в volume.

## Состав
- registry: `registry:2.8.2` (порт 5000 внутри сети)
- UI: `joxit/docker-registry-ui` (доступ только через Nginx)
- nginx: реверс‑прокси к UI и /v2/ API (порт `${NGINX_HTTP_PORT}` наружу)
- авторизация: basic auth (файл `auth/htpasswd`), создаётся автоматически

## Подготовка
1. Скопируйте окружение и при необходимости поправьте значения:
   ```bash
   cp .env.example .env
   ```
   Важные переменные:
   - `REGISTRY_DOMAIN` — домен/хост, по которому будет доступен proxy (по умолчанию localhost)
   - `NGINX_HTTP_PORT` — внешний порт Nginx (по умолчанию 80)
   - `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` — логин/пароль для UI и Registry
   - `REGISTRY_SECURED` — `true`, если доступ к реестру через https‑прокси (переменная для UI)

2. Убедитесь, что установлены Docker и Docker Compose v2.

## Запуск и управление
Используйте скрипт `manage.sh` (он создаст `auth/htpasswd`, при необходимости установит `apache2-utils` для `htpasswd`).

```bash
./manage.sh start    # запуск
./manage.sh stop     # остановка
./manage.sh restart  # перезапуск
./manage.sh build    # сборка (если меняли образы)
./manage.sh test     # загрузка тестового образа (hello-world) в реестр
```

## Доступ
- UI через Nginx: `http://<REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>`
- Docker Registry API: `http://<REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>/v2/`

Авторизация: используйте `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` из `.env`.

## Использование Docker
Примеры с прокси‑портом Nginx (по умолчанию 80):

```bash
# вход
docker login <REGISTRY_DOMAIN>:<NGINX_HTTP_PORT> -u <USER> -p <PASS>

# тегирование и пуш
docker pull alpine:3.19
docker tag alpine:3.19 <REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>/alpine:3.19
docker push <REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>/alpine:3.19

# пулл
docker pull <REGISTRY_DOMAIN>:<NGINX_HTTP_PORT>/alpine:3.19
```

Примечание: если доступ по HTTP и не с `localhost`, добавьте адрес реестра в `insecure-registries` на Docker‑клиентах (файл `/etc/docker/daemon.json`), затем перезапустите Docker.

## Структура
- `docker-compose.yml` — сервисы: registry, registry-ui, nginx; volumes `registry_data`, `nginx-logs`
- `manage.sh` — управление запуском/остановкой, создание `auth/htpasswd`, тестовый пуш
- `config/registry.yml` — конфигурация Registry (включены delete и basic auth)
- `nginx/nginx.conf`, `nginx/conf.d/registry.conf` — конфигурация Nginx
- `auth/htpasswd` — файл паролей (создаётся автоматически)
- `.env`, `.env.example` — переменные окружения

## Остановка и очистка
```bash
./manage.sh stop
# Полная остановка с удалением томов (опционально):
docker compose --env-file .env down -v
```

Данные образов хранятся в volume `registry_data`.
