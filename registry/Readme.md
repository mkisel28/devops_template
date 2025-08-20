# Docker Registry

Приватный Docker registry с веб-интерфейсом.

## Компоненты

- Docker Registry - хранение образов
- Registry UI - веб-интерфейс управления
- Nginx - прокси с аутентификацией

## Установка

1. Настройте конфигурацию:
```bash
cp .env.example .env
# отредактируйте .env
```

2. Запустите установку:
```bash
sudo ./install.sh
```

Или вручную:
```bash
./02-check-install-docker.sh
./03-up.sh
```

## Настройка

В `.env` укажите:
- `REGISTRY_DOMAIN` - домен или IP
- `NGINX_HTTP_PORT` - порт доступа (по умолчанию 80)
- `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` - учетные данные

## Использование

Веб-интерфейс: http://localhost (или ваш домен:порт)

Работа с образами:
```bash
# Авторизация
docker login localhost

# Загрузка
docker tag myimage localhost/myimage:tag
docker push localhost/myimage:tag

# Скачивание
docker pull localhost/myimage:tag
```

## Управление

```bash
./manage.sh test  # проверка
./manage.sh help  # справка
```
