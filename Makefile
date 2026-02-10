.PHONY: dev dev-build dev-down prod prod-build prod-down clean logs-dev logs-prod help

help:
	@echo "Valentine App - Docker Commands"
	@echo ""
	@echo "Development:"
	@echo "  make dev          - Start dev server (hot reload)"
	@echo "  make dev-build    - Rebuild and start dev server"
	@echo "  make dev-down     - Stop dev server"
	@echo "  make logs-dev     - View dev container logs"
	@echo ""
	@echo "Production:"
	@echo "  make prod         - Start production server"
	@echo "  make prod-build   - Rebuild and start production server"
	@echo "  make prod-down    - Stop production server"
	@echo "  make logs-prod    - View production container logs"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean        - Stop all containers and remove images"
	@echo "  make help         - Show this help message"

dev:
	docker compose --profile dev up

dev-build:
	docker compose --profile dev up --build

dev-down:
	docker compose --profile dev down

prod:
	docker compose --profile prod up -d

prod-build:
	docker compose --profile prod up --build -d

prod-down:
	docker compose --profile prod down

logs-dev:
	docker compose --profile dev logs -f

logs-prod:
	docker compose --profile prod logs -f

clean:
	docker compose --profile dev --profile prod down --rmi local
