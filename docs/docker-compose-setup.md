# Docker Compose Setup Documentation

## Overview

This document describes the Docker Compose foundation for the hello-dd distributed tracing demonstration project. The setup provides a complete local development environment with PostgreSQL, Redis, and development tools.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Docker Compose Environment                 │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ API Gateway │  │  Inventory  │  │   Pricing   │         │
│  │   (Python)  │  │   Service   │  │   Service   │         │
│  │  Port 8000  │  │    (Java)   │  │    (Go)     │         │
│  └─────────────┘  │  Port 8001  │  │  Port 8002  │         │
│                   └─────────────┘  └─────────────┘         │
│                           │                │                 │
│  ┌────────────────────────┴────────────────┘                │
│  │                                                           │
│  │  ┌──────────────┐           ┌──────────────┐            │
│  └─▶│  PostgreSQL  │           │    Redis     │            │
│     │   Port 5432  │           │  Port 6379   │            │
│     └──────────────┘           └──────────────┘            │
│                                                              │
│  ┌──────────────┐           ┌──────────────┐               │
│  │   Adminer    │           │    Redis     │               │
│  │  Port 8080   │           │  Commander   │               │
│  │ (PostgreSQL) │           │  Port 8081   │               │
│  └──────────────┘           └──────────────┘               │
│                                                              │
│  Network: hello-dd-network (172.20.0.0/16)                  │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine installed
- Docker Compose v2.0+ (included with Docker Desktop)
- At least 4GB of available RAM
- Ports 5432, 6379, 8000-8002, 8080-8081 available

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd hello-dd
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   # Edit .env to customize settings if needed
   ```

3. **Start infrastructure services:**
   ```bash
   make setup
   # Or manually:
   docker compose up -d postgres redis
   ```

4. **Verify services are healthy:**
   ```bash
   make health
   ```

5. **Start development tools (optional):**
   ```bash
   make dev-tools
   ```

## Services

### Infrastructure Services

#### PostgreSQL (postgres:15-alpine)
- **Port:** 5432
- **Database:** inventory
- **Username:** postgres
- **Password:** postgres (configurable via .env)
- **Features:**
  - Health checks configured
  - Automatic initialization with schema and seed data
  - Persistent volume for data
  - Optimized for development with query logging

#### Redis (redis:7-alpine)
- **Port:** 6379
- **Features:**
  - Append-only persistence configured
  - Health checks enabled
  - Persistent volume for data
  - Verbose logging in development

### Application Services (Placeholders)

#### API Gateway (Python/FastAPI)
- **Port:** 8000
- **Status:** To be implemented
- **Dependencies:** inventory-service, pricing-service

#### Inventory Service (Java/Spring Boot)
- **Port:** 8001
- **Status:** To be implemented
- **Dependencies:** postgres

#### Pricing Service (Go/Gin)
- **Port:** 8002
- **Status:** To be implemented
- **Dependencies:** redis

### Development Tools

#### Adminer
- **URL:** http://localhost:8080
- **Purpose:** PostgreSQL web management interface
- **Login:**
  - System: PostgreSQL
  - Server: postgres
  - Username: postgres
  - Password: postgres
  - Database: inventory

#### Redis Commander
- **URL:** http://localhost:8081
- **Purpose:** Redis web management interface
- **Login:**
  - Username: admin
  - Password: admin

## Configuration

### Environment Variables

Key environment variables (see `.env.example` for full list):

```bash
# Database
POSTGRES_DB=inventory
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Service Ports
API_GATEWAY_PORT=8000
INVENTORY_SERVICE_PORT=8001
PRICING_SERVICE_PORT=8002

# Datadog (Phase 2)
DD_API_KEY=your_api_key_here
DD_SITE=datadoghq.com
```

### Docker Compose Files

- **docker-compose.yml:** Main configuration with all services
- **docker-compose.override.yml:** Development-specific overrides
- **.env:** Environment-specific configuration

### Volumes

Persistent data volumes:
- `postgres_data`: PostgreSQL database files
- `redis_data`: Redis persistence files

Development cache volumes:
- `maven_cache`: Java/Maven dependencies
- `pip_cache`: Python packages
- `go_cache`: Go modules

### Networks

Custom bridge network:
- Name: `hello-dd-network`
- Subnet: `172.20.0.0/16`

## Common Operations

### Using Make Commands

```bash
# View all available commands
make help

# Start all services
make up

# Stop all services
make down

# Restart services
make restart

# View logs
make logs
make logs-api    # API Gateway logs
make logs-inv    # Inventory Service logs
make logs-price  # Pricing Service logs

# Connect to databases
make psql        # PostgreSQL CLI
make redis-cli   # Redis CLI

# Clean everything (including data)
make clean
```

### Manual Docker Commands

```bash
# Start specific services
docker compose up -d postgres redis

# Stop services but keep data
docker compose down

# Stop and remove everything including volumes
docker compose down -v

# View service status
docker compose ps

# Follow logs
docker compose logs -f [service-name]

# Execute commands in containers
docker compose exec postgres psql -U postgres -d inventory
docker compose exec redis redis-cli
```

## Database Schema

The PostgreSQL database is initialized with:

### Tables
- **products**: Product catalog with inventory levels
- **stock_transactions**: Audit trail for stock movements

### Sample Data
10 sample products are seeded including:
- Electronics (laptops, phones, monitors)
- Books
- Furniture (chairs, desks)

### Access Patterns
```sql
-- Connect to database
psql -h localhost -U postgres -d inventory

-- Query products
SELECT * FROM inventory.products;

-- Check stock levels
SELECT sku, name, stock_level, reserved_stock
FROM inventory.products
WHERE stock_level > 0;
```

## Troubleshooting

### Services won't start

1. **Check port conflicts:**
   ```bash
   lsof -i :5432  # PostgreSQL
   lsof -i :6379  # Redis
   lsof -i :8080  # Adminer
   ```

2. **Check Docker daemon:**
   ```bash
   docker version
   docker compose version
   ```

3. **Check logs:**
   ```bash
   docker compose logs postgres
   docker compose logs redis
   ```

### Database connection issues

1. **Verify PostgreSQL is healthy:**
   ```bash
   docker compose exec postgres pg_isready
   ```

2. **Check credentials:**
   ```bash
   cat .env | grep POSTGRES
   ```

3. **Test connection:**
   ```bash
   docker compose exec postgres psql -U postgres -c "\l"
   ```

### Redis connection issues

1. **Verify Redis is healthy:**
   ```bash
   docker compose exec redis redis-cli ping
   ```

2. **Check Redis logs:**
   ```bash
   docker compose logs redis
   ```

### Clean slate reset

If you need to start fresh:

```bash
# Stop everything and remove volumes
make clean

# Remove .env file
rm .env

# Start over
make setup
```

## Development Workflow

### Phase 1: Infrastructure Setup ✅
- [x] Docker Compose configuration
- [x] PostgreSQL with initialization
- [x] Redis with persistence
- [x] Development tools
- [x] Health checks
- [x] Makefile commands

### Phase 2: Service Implementation (Next)
- [ ] Inventory Service (Java/Spring Boot)
- [ ] Pricing Service (Go/Gin)
- [ ] API Gateway (Python/FastAPI)

### Phase 3: Integration
- [ ] Inter-service communication
- [ ] Error handling
- [ ] Circuit breakers

### Phase 4: Observability
- [ ] Datadog Agent deployment
- [ ] APM instrumentation
- [ ] Distributed tracing

## Best Practices

1. **Always use .env for configuration** - Never commit secrets to git
2. **Check service health before testing** - Use `make health`
3. **Use profiles for optional services** - Dev tools use `--profile dev-tools`
4. **Clean volumes when switching branches** - Use `make clean`
5. **Monitor logs during development** - Use `make logs`

## Security Notes

- Default passwords are for development only
- Change all credentials before deploying to production
- Use secrets management for production deployments
- Never commit .env files with real credentials

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Redis Docker Image](https://hub.docker.com/_/redis)
- [Project README](../README.md)
- [Phase 1 Documentation](phases/phase-01-docker-compose-foundation.md)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs: `make logs`
3. Check GitHub issues
4. Contact the project maintainer