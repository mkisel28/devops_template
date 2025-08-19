#!/usr/bin/env bash
set -euo pipefail

# Проверка что скрипт запущен от root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Этот скрипт должен запускаться от root (sudo)."
    exit 1
fi

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }

# Определение пользователя
NEW_USER="${NEW_USER:-onedev}"

log "🔄 Обновление пакетов..."
apt update -y

log "📦 Установка зависимостей..."
apt install -y ca-certificates curl gnupg lsb-release rsync

# Установка Docker
log "🐳 Добавление репозитория Docker..."
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

log "📥 Установка Docker..."
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "🚀 Запуск Docker..."
systemctl enable --now docker

# Создание пользователя
log "👤 Настройка пользователя ${NEW_USER}..."
if ! id "${NEW_USER}" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "${NEW_USER}"
    ok "Создан пользователь ${NEW_USER}"
else
    log "Пользователь ${NEW_USER} уже существует"
fi

# Добавление в группу docker
groupadd -f docker
usermod -aG docker "${NEW_USER}"

# Генерация секретных ключей
log "🔐 Генерация секретных ключей..."
cd "$(dirname "$0")"

if [ ! -f .env ]; then
    cp .env.example .env
fi

# Генерация ключей если они пустые
for var in ONEDEV_DB_PASSWORD ONEDEV_ADMIN_PASSWORD ONEDEV_SERVER_UUID ONEDEV_HIBERNATE_KEY; do
    if ! grep -q "^$var=" .env || grep -Eq "^$var=[[:space:]]*$" .env; then
        case $var in
            *UUID*)
                value=$(cat /proc/sys/kernel/random/uuid)
                ;;
            *)
                value=$(openssl rand -hex 32)
                ;;
        esac
        sed -i "/^$var=/d" .env
        echo "$var=$value" >> .env
        ok "Сгенерирован $var"
    fi
done

ok "✅ Docker установлен и настроен"
ok "✅ Пользователь ${NEW_USER} добавлен в группу docker"
ok "✅ Секретные ключи сгенерированы"
