FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    rsync \
    openssh-client \
    tar \
    gzip \
    jq \
    tzdata \
    dcron \
    bc \
    docker-cli


RUN mkdir -p /app/scripts /app/config /backup/temp /backup/archives /app/logs /app/ssh

COPY scripts/ /app/scripts/
COPY config/ /app/config/

RUN chmod +x /app/scripts/*.sh

# Создание группы docker с тем же GID, что и на хосте (обычно 999)
RUN addgroup -g 999 docker 2>/dev/null || addgroup docker

# Создание пользователя backup с доступом к docker
RUN addgroup -g 1001 backup 2>/dev/null || addgroup backup && \
    adduser -D -s /bin/bash -u 1001 -G backup backup && \
    adduser backup docker

RUN mkdir -p /var/spool/cron/crontabs && \
    chown -R backup:backup /var/spool/cron/crontabs && \
    chown -R backup:backup /app && \
    chown -R backup:backup /backup && \
    chmod 755 /app/logs

# Оставляем root для избежания проблем с правами
# USER backup

WORKDIR /app

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
