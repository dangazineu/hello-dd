# API Gateway Service

Minimal API Gateway implementation for Datadog APM distributed tracing demonstration.

## Overview

This service acts as the entry point for the distributed application, demonstrating:
- Service-to-service communication patterns
- Database and cache interactions
- Error handling and monitoring
- Distributed tracing scenarios

## Technology Stack

- **Framework**: FastAPI (Python 3.11)
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **HTTP Client**: httpx for async service calls

## Quick Start

### Local Development

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Set environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Run the service:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api-gateway

# Stop services
docker-compose down
```

## API Endpoints

### Health & Status

#### `GET /`
Root endpoint returning service information.

**Response:**
```json
{
    "service": "api-gateway",
    "message": "Hello from API Gateway",
    "version": "1.0.0"
}
```

#### `GET /health`
Health check endpoint for container orchestration.

**Response:**
```json
{
    "status": "healthy",
    "service": "api-gateway",
    "timestamp": "2025-10-18T03:27:00.000000",
    "version": "1.0.0"
}
```

### Database Operations

#### `GET /test-db`
Test PostgreSQL connection and fetch sample products.

**Response:**
```json
{
    "status": "connected",
    "database": "PostgreSQL",
    "version": "PostgreSQL 15.14...",
    "sample_products": [...],
    "product_count": 5,
    "timestamp": "2025-10-18T03:27:03.000000"
}
```

### Cache Operations

#### `GET /test-redis`
Test Redis connection with set/get operations.

**Response:**
```json
{
    "key": "test:api-gateway:1760758027",
    "value": "Hello from API Gateway at ...",
    "ttl": 60,
    "operation": "SET/GET",
    "timestamp": "2025-10-18T03:27:07.000000"
}
```

### Service Communication

#### `GET /test-http/{service}`
Test HTTP calls to other services for distributed tracing.

**Parameters:**
- `service`: One of `inventory`, `pricing`, or `external`

**Response:**
```json
{
    "source": "api-gateway",
    "target": "external",
    "status": "success",
    "data": {...},
    "timestamp": "2025-10-18T03:27:12.000000"
}
```

### Business Operations

#### `GET /products`
Fetch products with caching demonstration.

**Query Parameters:**
- `limit` (int, default=10): Number of products to return

**Response:**
```json
{
    "products": [
        {
            "id": "b18076c3-8ac0-4700-b41f-b1b17a9618eb",
            "sku": "LAPTOP-001",
            "name": "ThinkPad X1 Carbon",
            "stock_level": 50,
            "price": 1299.99,
            "discounted_price": 1169.99
        }
    ],
    "source": "database",  // or "cache" if cached
    "cached": false,
    "timestamp": "2025-10-18T03:27:16.000000"
}
```

#### `POST /order`
Create an order demonstrating distributed transaction flow.

**Query Parameters:**
- `product_id` (string): Product SKU or ID
- `quantity` (int, default=1): Order quantity

**Response:**
```json
{
    "order_id": "ORD-1760758045",
    "product_id": "LAPTOP-001",
    "quantity": 2,
    "status": "confirmed",
    "steps": [
        {
            "name": "inventory_check",
            "status": "completed",
            "duration_ms": 100
        },
        {
            "name": "price_calculation",
            "status": "completed",
            "duration_ms": 50
        },
        {
            "name": "stock_reservation",
            "status": "completed",
            "duration_ms": 150
        },
        {
            "name": "payment_processing",
            "status": "completed",
            "duration_ms": 200
        },
        {
            "name": "order_confirmation",
            "status": "completed",
            "duration_ms": 50
        }
    ],
    "total_duration_ms": 550,
    "timestamp": "2025-10-18T03:27:25.000000"
}
```

### Error Testing

#### `GET /error-test/{error_type}`
Test error scenarios for APM error tracking.

**Parameters:**
- `error_type`: One of `400`, `404`, `500`, `timeout`, or `exception`

**Response varies based on error type:**
- `400`: Returns HTTP 400 Bad Request
- `404`: Returns HTTP 404 Not Found
- `500`: Returns HTTP 500 Internal Server Error
- `timeout`: Causes request timeout (35s delay)
- `exception`: Raises unhandled exception

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Service host | 0.0.0.0 |
| `PORT` | Service port | 8000 |
| `LOG_LEVEL` | Logging level | INFO |
| `POSTGRES_HOST` | PostgreSQL host | localhost |
| `POSTGRES_PORT` | PostgreSQL port | 5432 |
| `POSTGRES_DB` | Database name | inventory |
| `POSTGRES_USER` | Database user | postgres |
| `POSTGRES_PASSWORD` | Database password | postgres |
| `REDIS_HOST` | Redis host | localhost |
| `REDIS_PORT` | Redis port | 6379 |
| `INVENTORY_SERVICE_URL` | Inventory service URL | http://localhost:8001 |
| `PRICING_SERVICE_URL` | Pricing service URL | http://localhost:8002 |
| `DD_SERVICE` | Datadog service name | api-gateway |
| `DD_ENV` | Datadog environment | development |
| `DD_VERSION` | Service version | 1.0.0 |

## Monitoring & Observability

This service is designed to demonstrate distributed tracing patterns:

1. **Database Traces**: All PostgreSQL operations are traceable
2. **Cache Traces**: Redis operations show cache hit/miss patterns
3. **HTTP Traces**: Service-to-service calls create distributed traces
4. **Error Tracking**: Different error types for APM error monitoring
5. **Performance Metrics**: Response times and operation durations

## Next Steps

1. **Add Datadog APM**: Instrument with `ddtrace` for automatic tracing
2. **Deploy to EKS**: Use Kubernetes manifests for AWS deployment
3. **Add Other Services**: Implement inventory and pricing services
4. **Enable Datadog Agent**: Configure for metrics and log collection

## Development Notes

- Service includes fallback responses when dependencies are unavailable
- Mock data is returned if database/cache connections fail
- Health checks are configured for container orchestration
- Non-root user runs the application in Docker for security

## Testing

```bash
# Test all endpoints
curl http://localhost:8000/health
curl http://localhost:8000/test-db
curl http://localhost:8000/test-redis
curl http://localhost:8000/products?limit=5
curl -X POST "http://localhost:8000/order?product_id=LAPTOP-001&quantity=1"
curl http://localhost:8000/test-http/external
curl http://localhost:8000/error-test/404
```

## Issue Reference

This service was created as part of [Issue #52: Fast Track: Build Minimal API Gateway Service](https://github.com/dangazineu/hello-dd/issues/52)