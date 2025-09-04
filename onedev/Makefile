ifneq (,$(wildcard .env))
    include .env
    export
endif

BACKUP_PROFILE=backup
.DEFAULT_GOAL := help

help: ## Показать список доступных команд
	@echo "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?##' Makefile | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-15s %s\n", $$1, $$2}'

up: ## Запуск OneDev (с профилем backup если ENABLE_BACKUP=true)
ifeq ($(ENABLE_BACKUP),true)
	docker compose --profile $(BACKUP_PROFILE) up -d
else
	docker compose up -d
endif

up-only: ## Запуск OneDev без backup
	docker compose up -d

up-with-backup: ## Запуск OneDev c профилем backup
	docker compose --profile $(BACKUP_PROFILE) up -d


down: ## Остановить и удалить контейнеры
	docker compose down

pull: ## Скачать последние образы
	docker compose pull

ps: ## Показать статус контейнеров
	docker compose ps

logs: ## Смотреть логи (пример: make logs service=onedev-backup)
	docker compose logs -f $(service)

restart: ## Перезапустить контейнеры
	$(MAKE) down
	$(MAKE) up
