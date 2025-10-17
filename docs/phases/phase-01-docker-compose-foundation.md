# Phase 1: Docker Compose Foundation

## Overview
Set up the foundational Docker Compose environment and project structure that will support rapid local development and testing throughout all phases. This establishes the development workflow and provides a framework for adding services incrementally.

## Objectives
- Create project structure and development environment
- Set up Docker Compose with service placeholders
- Establish networking and shared resources
- Create development tooling and scripts
- Prepare for incremental service addition

## Project Structure

```
hello-dd/
├── docker-compose.yml           # Main compose file
├── docker-compose.override.yml  # Local dev overrides
├── .env.example                 # Environment variables template
├── Makefile                     # Development commands
├── scripts/
│   ├── setup.sh                # Initial setup script
│   ├── health-check.sh         # Service health verification
│   └── clean.sh                # Cleanup script
├── api-gateway/                # Placeholder for Phase 6
│   └── Dockerfile.placeholder
├── inventory-service/          # Placeholder for Phase 2
│   └── Dockerfile.placeholder
├── pricing-service/            # Placeholder for Phase 4
│   └── Dockerfile.placeholder
├── k8s/                        # Kubernetes manifests (future phases)
├── infrastructure/             # Pulumi code (Phase 8)
└── docs/
    ├── phases/
    └── architecture/
```

## Docker Compose Base Configuration

### Main Compose File
```yaml
# docker-compose.yml
version: '3.8'

x-common-variables: &common-variables
  DD_ENV: ${DD_ENV:-dev}
  DD_VERSION: ${DD_VERSION:-1.0.0}
  LOG_LEVEL: ${LOG_LEVEL:-INFO}
  TZ: ${TZ:-UTC}

x-healthcheck-defaults: &healthcheck-defaults
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

services:
  # PostgreSQL Database (Ready from Phase 1)
  postgres:
    image: postgres:15-alpine
    container_name: inventory-db
    environment:
      POSTGRES_DB: inventory
      POSTGRES_USER: ${DB_USER:-inventory}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-inventory}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "5432:5432"
    networks:
      - hello-dd-network
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-inventory} -d inventory"]

  # Redis Cache (Ready from Phase 1)
  redis:
    image: redis:7-alpine
    container_name: cache
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - hello-dd-network
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "redis-cli", "ping"]

  # Placeholder for inventory-service (Phase 2)
  # inventory-service:
  #   build: ./inventory-service
  #   container_name: inventory-service
  #   environment:
  #     <<: *common-variables
  #     DB_HOST: postgres
  #     DB_NAME: inventory
  #   depends_on:
  #     postgres:
  #       condition: service_healthy
  #   networks:
  #     - hello-dd-network

  # Placeholder for pricing-service (Phase 4)
  # pricing-service:
  #   build: ./pricing-service
  #   container_name: pricing-service
  #   environment:
  #     <<: *common-variables
  #     REDIS_HOST: redis
  #   depends_on:
  #     redis:
  #       condition: service_healthy
  #   networks:
  #     - hello-dd-network

  # Placeholder for api-gateway (Phase 6)
  # api-gateway:
  #   build: ./api-gateway
  #   container_name: api-gateway
  #   environment:
  #     <<: *common-variables
  #   networks:
  #     - hello-dd-network

networks:
  hello-dd-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
```

### Development Override File
```yaml
# docker-compose.override.yml
version: '3.8'

services:
  postgres:
    ports:
      - "5432:5432"
    environment:
      POSTGRES_LOG_STATEMENT: all
      POSTGRES_LOG_DURATION: "on"

  redis:
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes --loglevel debug

  # Development tools
  adminer:
    image: adminer:latest
    container_name: adminer
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: postgres
    networks:
      - hello-dd-network
    profiles:
      - dev-tools

  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: redis-commander
    environment:
      REDIS_HOSTS: local:redis:6379
    ports:
      - "8081:8081"
    networks:
      - hello-dd-network
    profiles:
      - dev-tools
```

## Environment Configuration

### Environment Template
```bash
# .env.example
# Application Environment
DD_ENV=dev
DD_VERSION=1.0.0
LOG_LEVEL=INFO

# Database Configuration
DB_USER=inventory
DB_PASSWORD=inventory
DB_NAME=inventory
DB_PORT=5432

# Redis Configuration
REDIS_PORT=6379
REDIS_PASSWORD=

# Service Ports (for future phases)
API_GATEWAY_PORT=8000
INVENTORY_SERVICE_PORT=8001
PRICING_SERVICE_PORT=8002

# Datadog Configuration (Phase 10)
DD_API_KEY=
DD_APP_KEY=
DD_SITE=datadoghq.com

# AWS Configuration (Phase 8)
AWS_REGION=us-east-1
AWS_PROFILE=default

# Development Settings
COMPOSE_PROJECT_NAME=hello-dd
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
```

## Development Tooling

### Makefile
```makefile
# Makefile
.PHONY: help setup up down restart logs clean test health

# Default target
help:
	@echo "Available commands:"
	@echo "  make setup      - Initial project setup"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - Show service logs"
	@echo "  make clean      - Clean up everything"
	@echo "  make test       - Run integration tests"
	@echo "  make health     - Check service health"
	@echo "  make dev-tools  - Start development tools"

setup:
	@echo "Setting up development environment..."
	@cp .env.example .env
	@docker network create hello-dd-network 2>/dev/null || true
	@docker-compose pull
	@echo "Setup complete! Edit .env file and run 'make up'"

up:
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@make health

down:
	docker-compose down

restart: down up

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	docker network rm hello-dd-network 2>/dev/null || true
	rm -rf postgres_data redis_data

test:
	@echo "Running integration tests..."
	@./scripts/health-check.sh

health:
	@./scripts/health-check.sh

dev-tools:
	docker-compose --profile dev-tools up -d

# Service-specific commands (for future phases)
build-%:
	docker-compose build $*

logs-%:
	docker-compose logs -f $*

restart-%:
	docker-compose restart $*

exec-%:
	docker-compose exec $* /bin/sh
```

### Health Check Script
```bash
#!/bin/bash
# scripts/health-check.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_service() {
    local service=$1
    local port=$2
    local endpoint=${3:-/health}

    if nc -z localhost $port 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $service is running on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service is not accessible on port $port"
        return 1
    fi
}

echo "Checking service health..."
echo "========================="

# Check infrastructure services
check_service "PostgreSQL" 5432 ""
check_service "Redis" 6379 ""

# Check application services (will fail initially, that's expected)
# Uncomment as services are added in later phases
# check_service "Inventory Service" 8001 "/health"
# check_service "Pricing Service" 8002 "/health"
# check_service "API Gateway" 8000 "/health"

echo "========================="
echo "Infrastructure services ready!"
```

### Database Initialization
```sql
-- scripts/init-db.sql
-- Initial database setup for inventory service

CREATE SCHEMA IF NOT EXISTS inventory;

CREATE TABLE IF NOT EXISTS inventory.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    stock_level INTEGER NOT NULL DEFAULT 0,
    reserved_stock INTEGER NOT NULL DEFAULT 0,
    reorder_point INTEGER DEFAULT 10,
    unit_cost DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory.stock_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES inventory.products(id),
    transaction_type VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL,
    order_id VARCHAR(255),
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_products_sku ON inventory.products(sku);
CREATE INDEX idx_products_category ON inventory.products(category);
CREATE INDEX idx_transactions_product ON inventory.stock_transactions(product_id);
CREATE INDEX idx_transactions_order ON inventory.stock_transactions(order_id);

-- Insert sample data
INSERT INTO inventory.products (sku, name, description, category, stock_level, unit_cost)
VALUES
    ('LAPTOP-001', 'ThinkPad X1 Carbon', 'Business laptop', 'Electronics', 50, 1299.99),
    ('MOUSE-001', 'Logitech MX Master', 'Wireless mouse', 'Accessories', 100, 99.99),
    ('KEYBOARD-001', 'Mechanical Keyboard', 'RGB Gaming Keyboard', 'Accessories', 75, 149.99);
```

## Testing the Foundation

### Verify Docker Compose Setup
```bash
# Start the infrastructure
make setup
make up

# Verify services are running
docker-compose ps

# Check logs
make logs

# Test database connection
docker-compose exec postgres psql -U inventory -d inventory -c "\dt"

# Test Redis connection
docker-compose exec redis redis-cli ping

# Start development tools
make dev-tools
# Access Adminer at http://localhost:8080
# Access Redis Commander at http://localhost:8081
```

## Integration Points for Future Phases

### Adding a New Service
When adding services in future phases, follow this pattern:

1. Uncomment the service block in `docker-compose.yml`
2. Build the service: `make build-<service-name>`
3. Restart compose: `make restart`
4. Verify health: `make health`

### Environment Variables
Each service will use common environment variables plus service-specific ones:
- Common: `DD_ENV`, `DD_VERSION`, `LOG_LEVEL`
- Service-specific: Added to `.env` file as needed

## Success Criteria

- Docker Compose environment starts successfully
- PostgreSQL and Redis are accessible
- Development tools work (Adminer, Redis Commander)
- Makefile commands execute properly
- Health check script runs without errors
- Network connectivity verified between containers
- Volumes persist data across restarts
- Environment variables properly configured

## Foundation for Next Phases

This phase establishes:
- Local development environment
- Service orchestration framework
- Database and cache infrastructure
- Development tooling and scripts
- Network configuration

Ready for:
- Phase 2: Adding Inventory Service
- Incremental service additions
- Easy testing and debugging
- Kubernetes migration preparation