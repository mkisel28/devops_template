#!/usr/bin/env bash
set -euo pipefail

# Проверка root
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт нужно запускать от root (sudo)."
  exit 1
fi

apt update -y
apt install -y ca-certificates curl gnupg lsb-release


install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# Создание пользователя (если нужно)
NEW_USER="${NEW_USER:-ci}"
if ! id "${NEW_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${NEW_USER}"
fi

# Доступ к Docker без root
groupadd -f docker
usermod -aG docker "${NEW_USER}"


for var in DRONE_RPC_SECRET GITEA_SECRET_KEY GITEA_INTERNAL_TOKEN GITEA_OAUTH2_JWT_SECRET; do
  if ! grep -q "^$var=" .env || grep -Eq "^$var=[[:space:]]*$" .env; then
    sed -i "/^$var=/d" .env
    echo "$var=$(openssl rand -hex 32)" >> .env
    echo "Сгенерирован $var."
  fi
done



echo "Docker установлен. Пользователь ${NEW_USER} добавлен в группу docker."