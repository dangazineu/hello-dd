.PHONY: help setup up down restart logs clean test health dev-tools

# Default target - show help
help:
	@echo "Hello-DD Project Makefile Commands"
	@echo "=================================="
	@echo ""
	@echo "Setup & Configuration:"
	@echo "  make setup        - Initial environment setup"
	@echo "  make env          - Copy .env.example to .env if not exists"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make up           - Start all services"
	@echo "  make down         - Stop all services"
	@echo "  make restart      - Restart all services"
	@echo "  make clean        - Stop services and remove volumes"
	@echo ""
	@echo "Service Management:"
	@echo "  make up-infra     - Start only infrastructure (PostgreSQL, Redis)"
	@echo "  make up-services  - Start application services"
	@echo "  make restart-api  - Restart API Gateway"
	@echo "  make restart-inv  - Restart Inventory Service"
	@echo "  make restart-price - Restart Pricing Service"
	@echo ""
	@echo "Monitoring & Logs:"
	@echo "  make logs         - Show logs for all services"
	@echo "  make logs-api     - Show API Gateway logs"
	@echo "  make logs-inv     - Show Inventory Service logs"
	@echo "  make logs-price   - Show Pricing Service logs"
	@echo "  make health       - Check health of all services"
	@echo ""
	@echo "Development Tools:"
	@echo "  make dev-tools    - Start Adminer and Redis Commander"
	@echo "  make psql         - Connect to PostgreSQL CLI"
	@echo "  make redis-cli    - Connect to Redis CLI"
	@echo ""
	@echo "Testing:"
	@echo "  make test         - Run tests for all services"
	@echo "  make test-api     - Run API Gateway tests"
	@echo "  make test-inv     - Run Inventory Service tests"
	@echo "  make test-price   - Run Pricing Service tests"
	@echo "  make load-test    - Run load tests"

# Initial setup
setup: env
	@echo "Setting up Hello-DD project..."
	@echo "Checking Docker installation..."
	@docker --version || (echo "Docker is not installed" && exit 1)
	@docker compose version || (echo "Docker Compose is not installed" && exit 1)
	@echo "Starting infrastructure services..."
	@docker compose up -d postgres redis
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@make health
	@echo "Setup complete! Infrastructure services are running."
	@echo "Run 'make dev-tools' to start development tools."

# Environment file setup
env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env file created from .env.example"; \
	else \
		echo ".env file already exists"; \
	fi

# Start all services
up:
	docker compose up -d

# Start only infrastructure services (PostgreSQL and Redis)
up-infra:
	docker compose up -d postgres redis

# Start application services
up-services:
	docker compose up -d api-gateway inventory-service pricing-service

# Stop all services
down:
	docker compose down

# Restart all services
restart:
	docker compose restart

# Restart individual services
restart-api:
	docker compose restart api-gateway

restart-inv:
	docker compose restart inventory-service

restart-price:
	docker compose restart pricing-service

# Show logs for all services
logs:
	docker compose logs -f

# Show logs for specific services
logs-api:
	docker compose logs -f api-gateway

logs-inv:
	docker compose logs -f inventory-service

logs-price:
	docker compose logs -f pricing-service

logs-db:
	docker compose logs -f postgres

logs-redis:
	docker compose logs -f redis

# Clean everything (including volumes)
clean:
	docker compose down -v
	@echo "All containers and volumes have been removed"

# Health check for all services
health:
	@echo "Checking service health..."
	@docker compose ps
	@echo ""
	@echo "PostgreSQL Health:"
	@docker compose exec -T postgres pg_isready -U postgres || echo "PostgreSQL is not healthy"
	@echo ""
	@echo "Redis Health:"
	@docker compose exec -T redis redis-cli ping || echo "Redis is not healthy"
	@echo ""
	@if docker compose ps | grep -q api-gateway; then \
		echo "API Gateway Health:"; \
		curl -s http://localhost:8000/health || echo "API Gateway is not responding"; \
		echo ""; \
	fi
	@if docker compose ps | grep -q inventory-service; then \
		echo "Inventory Service Health:"; \
		curl -s http://localhost:8001/actuator/health || echo "Inventory Service is not responding"; \
		echo ""; \
	fi
	@if docker compose ps | grep -q pricing-service; then \
		echo "Pricing Service Health:"; \
		curl -s http://localhost:8002/health || echo "Pricing Service is not responding"; \
		echo ""; \
	fi

# Start development tools (Adminer and Redis Commander)
dev-tools:
	docker compose --profile dev-tools up -d
	@echo "Development tools started:"
	@echo "  Adminer (PostgreSQL UI): http://localhost:8080"
	@echo "  Redis Commander: http://localhost:8081"
	@echo "    Username: admin"
	@echo "    Password: admin"

# Connect to PostgreSQL CLI
psql:
	docker compose exec postgres psql -U postgres -d inventory

# Connect to Redis CLI
redis-cli:
	docker compose exec redis redis-cli

# Run all tests
test:
	@echo "Running tests for all services..."
	@make test-api
	@make test-inv
	@make test-price

# Test individual services
test-api:
	@if [ -d "api-gateway" ] && [ -f "api-gateway/requirements.txt" ]; then \
		echo "Running API Gateway tests..."; \
		cd api-gateway && python -m pytest tests/ -v; \
	else \
		echo "API Gateway not yet implemented"; \
	fi

test-inv:
	@if [ -d "inventory-service" ] && [ -f "inventory-service/pom.xml" ]; then \
		echo "Running Inventory Service tests..."; \
		cd inventory-service && ./mvnw test; \
	else \
		echo "Inventory Service not yet implemented"; \
	fi

test-price:
	@if [ -d "pricing-service" ] && [ -f "pricing-service/go.mod" ]; then \
		echo "Running Pricing Service tests..."; \
		cd pricing-service && go test ./...; \
	else \
		echo "Pricing Service not yet implemented"; \
	fi

# Run load tests
load-test:
	@if [ -f "scripts/load-test.js" ]; then \
		k6 run scripts/load-test.js; \
	else \
		echo "Load test script not found at scripts/load-test.js"; \
	fi

# Build all services
build:
	docker compose build

# Build specific services
build-api:
	docker compose build api-gateway

build-inv:
	docker compose build inventory-service

build-price:
	docker compose build pricing-service

# Show Docker Compose configuration
config:
	docker compose config

# Remove dangling images and unused containers
prune:
	docker system prune -f

# Show service ports
ports:
	@echo "Service Ports:"
	@echo "  API Gateway:        http://localhost:8000"
	@echo "  Inventory Service:  http://localhost:8001"
	@echo "  Pricing Service:    http://localhost:8002"
	@echo "  PostgreSQL:         localhost:5432"
	@echo "  Redis:              localhost:6379"
	@echo "  Adminer:            http://localhost:8080"
	@echo "  Redis Commander:    http://localhost:8081"