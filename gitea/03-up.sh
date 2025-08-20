#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Не запускайте этот скрипт от root. Перейдите под пользователем, добавленным в группу docker."
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker не найден в PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Пользователь не имеет доступа к Docker (группа docker?)."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose plugin не установлен."; exit 1; }


echo "Pull образов…"
docker compose pull

echo "Запуск…"
docker compose up -d

echo "Проверка статуса…"
docker compose ps

echo "
Стек запущен.

Gitea (HTTP за внешним Nginx):     http://127.0.0.1:${GITEA_HTTP_PORT:-3000}
Drone (HTTP за внешним Nginx):     http://127.0.0.1:${DRONE_HTTP_PORT:-8080}

Дальше:
1) Зайдите в Gitea, создайте первого администратора.
2) Создайте OAuth-приложение для Drone (Redirect URL: https://${DRONE_SERVER_HOST:-ci.example.com}/login).
3) Впишите DRONE_GITEA_CLIENT_ID / DRONE_GITEA_CLIENT_SECRET в .env и: docker compose up -d
4) После — закройте регистрацию в Gitea: GITEA_DISABLE_REGISTRATION=true и перезапустите.
"
