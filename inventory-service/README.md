# Inventory Service

Minimal Java Spring Boot service for demonstrating distributed tracing with Datadog APM.

## Overview

This service manages product inventory and stock levels, providing a RESTful API for product operations. It's designed as a simple microservice that integrates with the API Gateway to demonstrate service-to-service communication patterns.

## Technology Stack

- **Framework**: Spring Boot 3.2.0
- **Language**: Java 21
- **Database**: H2 (in-memory)
- **Build Tool**: Maven 3.9
- **Container**: Docker with Eclipse Temurin JRE

## Features

- RESTful API for product management
- In-memory H2 database for simplicity
- Pre-populated sample data on startup
- Health check endpoints for container orchestration
- Lombok for reduced boilerplate code
- Spring Data JPA for database operations

## API Endpoints

### Health & Status

#### `GET /health`
Health check endpoint for container orchestration.

**Response:**
```json
{
    "status": "UP",
    "service": "inventory-service",
    "version": "1.0.0",
    "timestamp": "2025-10-18T03:27:00.000000"
}
```

#### `GET /`
Root endpoint returning service information.

**Response:**
```json
{
    "service": "inventory-service",
    "message": "Inventory Service is running",
    "version": "1.0.0"
}
```

### Product Operations

#### `GET /api/v1/products`
Get all products with optional filtering.

**Query Parameters:**
- `inStockOnly` (boolean, default=false): Filter to show only products in stock

**Response:**
```json
[
    {
        "id": "uuid",
        "sku": "LAPTOP-001",
        "name": "ThinkPad X1 Carbon",
        "description": "High-performance business laptop",
        "stockLevel": 50,
        "availableStock": 50,
        "price": 1299.99,
        "active": true
    }
]
```

#### `GET /api/v1/products/{id}`
Get a product by ID.

**Response:** Single product object or 404 if not found

#### `GET /api/v1/products/sku/{sku}`
Get a product by SKU.

**Response:** Single product object or 404 if not found

#### `GET /api/v1/products/{id}/stock`
Check stock availability for a product.

**Response:**
```json
{
    "productId": "uuid",
    "sku": "LAPTOP-001",
    "stockLevel": 50,
    "reservedStock": 0,
    "availableStock": 50,
    "inStock": true
}
```

#### `PUT /api/v1/products/{id}/stock`
Update stock level for a product.

**Request Body:**
```json
{
    "quantity": 10,
    "operation": "add"  // "add", "subtract", or "set"
}
```

**Response:** Updated product object

#### `GET /api/v1/products/low-stock`
Get products with low stock.

**Query Parameters:**
- `threshold` (int, default=10): Stock level threshold

**Response:** List of products below the threshold

## Quick Start

### Local Development

1. Ensure Java 21+ is installed:
```bash
java -version
```

2. Build the project:
```bash
cd inventory-service
./mvnw clean package
```

3. Run the service:
```bash
./mvnw spring-boot:run
```

The service will start on port 8001.

### Docker

Build and run with Docker:
```bash
docker build -t inventory-service:latest ./inventory-service
docker run -p 8001:8001 inventory-service:latest
```

### Docker Compose

Start all services including inventory:
```bash
docker-compose up -d
```

## Configuration

Configuration is managed through `application.properties`:

| Property | Description | Default |
|----------|-------------|---------|
| `server.port` | Service port | 8001 |
| `spring.datasource.url` | H2 database URL | jdbc:h2:mem:inventorydb |
| `spring.h2.console.enabled` | Enable H2 console | true |
| `spring.jpa.hibernate.ddl-auto` | Hibernate DDL mode | create-drop |
| `dd.service` | Datadog service name | inventory-service |
| `dd.env` | Datadog environment | development |
| `dd.version` | Service version | 1.0.0 |

## Database

The service uses an in-memory H2 database that's initialized with sample data on startup. The H2 console is available at `/h2-console` for debugging:

- **URL**: `http://localhost:8001/h2-console`
- **JDBC URL**: `jdbc:h2:mem:inventorydb`
- **Username**: `sa`
- **Password**: (empty)

## Sample Data

The service initializes with 13 sample products including:
- Electronics (laptops, phones, monitors)
- Office equipment (chairs, desks)
- Books and accessories
- One out-of-stock item for testing

## Testing

### Test Endpoints

```bash
# Health check
curl http://localhost:8001/health

# Get all products
curl http://localhost:8001/api/v1/products

# Get products in stock only
curl "http://localhost:8001/api/v1/products?inStockOnly=true"

# Get product by SKU
curl http://localhost:8001/api/v1/products/sku/LAPTOP-001

# Check stock for a product
curl http://localhost:8001/api/v1/products/{id}/stock

# Get low stock products
curl "http://localhost:8001/api/v1/products/low-stock?threshold=10"
```

## Monitoring & Observability

This service is designed for distributed tracing demonstrations:

1. **Health Checks**: Available at `/health` and `/actuator/health`
2. **Metrics**: Spring Boot Actuator metrics at `/actuator/metrics`
3. **Logging**: Structured logging with configurable levels
4. **Tracing Ready**: Prepared for Datadog APM instrumentation

## Next Steps

1. **Add Datadog APM**: Instrument with `dd-java-agent` for automatic tracing
2. **Connect to PostgreSQL**: Replace H2 with PostgreSQL for persistence
3. **Add Authentication**: Implement API key or OAuth2 security
4. **Enhance Error Handling**: Add global exception handlers
5. **Add Integration Tests**: Implement comprehensive test coverage

## Development Notes

- Service uses UUID for product IDs
- Stock management includes reserved stock concept
- Lombok reduces boilerplate (requires IDE plugin)
- H2 database resets on restart (intentional for demo)

## Issue Reference

This service was created as part of [Issue #53: Build Minimal Inventory Service](https://github.com/dangazineu/hello-dd/issues/53)