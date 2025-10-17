# Phase 6: API Gateway Implementation

## Overview
Build the API Gateway using Python FastAPI to orchestrate calls to Inventory and Pricing services. This phase completes the three-service architecture in Docker Compose before full Kubernetes deployment.

## Objectives
- Implement FastAPI-based API Gateway
- Create service orchestration patterns
- Add circuit breakers and retry logic
- Integrate with both backend services locally
- Prepare for Kubernetes deployment (Phase 7)

## Service Implementation

### Project Structure
```
api-gateway/
├── app/
│   ├── api/
│   │   ├── routes/
│   │   │   ├── products.py
│   │   │   ├── orders.py
│   │   │   ├── health.py
│   │   │   └── reports.py
│   │   └── deps.py
│   ├── core/
│   │   ├── config.py
│   │   ├── middleware.py
│   │   └── circuit_breaker.py
│   ├── models/
│   │   ├── requests.py
│   │   └── responses.py
│   ├── services/
│   │   ├── inventory_client.py
│   │   ├── pricing_client.py
│   │   └── orchestrator.py
│   ├── utils/
│   │   ├── correlation.py
│   │   └── logging_config.py
│   └── main.py
├── tests/
│   ├── unit/
│   └── integration/
├── requirements.txt
├── Dockerfile
├── .env.example
└── README.md
```

### Core Implementation

#### Main Application
```python
# app/main.py
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import httpx

from app.api.routes import products, orders, health, reports
from app.core.config import settings
from app.core.middleware import CorrelationIDMiddleware, LoggingMiddleware
from app.services.inventory_client import InventoryClient
from app.services.pricing_client import PricingClient

# Shared HTTP clients
clients = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    clients["inventory"] = InventoryClient(
        base_url=settings.INVENTORY_SERVICE_URL,
        timeout=settings.SERVICE_TIMEOUT
    )
    clients["pricing"] = PricingClient(
        base_url=settings.PRICING_SERVICE_URL,
        timeout=settings.SERVICE_TIMEOUT
    )
    yield
    # Shutdown
    await clients["inventory"].close()
    await clients["pricing"].close()

app = FastAPI(
    title="API Gateway",
    version="1.0.0",
    lifespan=lifespan
)

# Middleware
app.add_middleware(CorrelationIDMiddleware)
app.add_middleware(LoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(products.router, prefix="/api/v1", tags=["products"])
app.include_router(orders.router, prefix="/api/v1", tags=["orders"])
app.include_router(reports.router, prefix="/api/v1", tags=["reports"])

@app.get("/")
async def root():
    return {"message": "API Gateway", "version": "1.0.0"}
```

#### Service Clients

```python
# app/services/inventory_client.py
import httpx
from typing import Optional, List, Dict, Any
from app.core.circuit_breaker import CircuitBreaker

class InventoryClient:
    def __init__(self, base_url: str, timeout: float = 30.0):
        self.base_url = base_url
        self.client = httpx.AsyncClient(
            base_url=base_url,
            timeout=timeout,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=100)
        )
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=5,
            recovery_timeout=60,
            expected_exception=httpx.HTTPError
        )

    async def get_product(self, product_id: str, correlation_id: str) -> Optional[Dict[Any, Any]]:
        headers = {"X-Correlation-ID": correlation_id}

        async def call():
            response = await self.client.get(
                f"/api/v1/products/{product_id}",
                headers=headers
            )
            response.raise_for_status()
            return response.json()

        return await self.circuit_breaker.call(call)

    async def list_products(self, page: int = 1, size: int = 10, correlation_id: str = "") -> Dict[Any, Any]:
        headers = {"X-Correlation-ID": correlation_id}
        params = {"page": page, "size": size}

        async def call():
            response = await self.client.get(
                "/api/v1/products",
                headers=headers,
                params=params
            )
            response.raise_for_status()
            return response.json()

        return await self.circuit_breaker.call(call)

    async def reserve_stock(self, product_id: str, quantity: int, order_id: str, correlation_id: str) -> Dict[Any, Any]:
        headers = {"X-Correlation-ID": correlation_id}
        data = {
            "productId": product_id,
            "quantity": quantity,
            "orderId": order_id
        }

        async def call():
            response = await self.client.post(
                "/api/v1/stock/reserve",
                json=data,
                headers=headers
            )
            response.raise_for_status()
            return response.json()

        return await self.circuit_breaker.call(call)

    async def close(self):
        await self.client.aclose()
```

```python
# app/services/pricing_client.py
import httpx
from typing import Optional, List, Dict, Any
from app.core.circuit_breaker import CircuitBreaker

class PricingClient:
    def __init__(self, base_url: str, timeout: float = 30.0):
        self.base_url = base_url
        self.client = httpx.AsyncClient(
            base_url=base_url,
            timeout=timeout,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=100)
        )
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=5,
            recovery_timeout=60,
            expected_exception=httpx.HTTPError
        )

    async def get_price(self, product_id: str, correlation_id: str) -> Optional[Dict[Any, Any]]:
        headers = {"X-Correlation-ID": correlation_id}

        async def call():
            response = await self.client.get(
                f"/api/v1/prices/{product_id}",
                headers=headers
            )
            response.raise_for_status()
            return response.json()

        return await self.circuit_breaker.call(call)

    async def calculate_price(self, product_id: str, quantity: int, discount_codes: List[str], correlation_id: str) -> Dict[Any, Any]:
        headers = {"X-Correlation-ID": correlation_id}
        data = {
            "productId": product_id,
            "quantity": quantity,
            "discountCodes": discount_codes
        }

        async def call():
            response = await self.client.post(
                "/api/v1/prices/calculate",
                json=data,
                headers=headers
            )
            response.raise_for_status()
            return response.json()

        return await self.circuit_breaker.call(call)

    async def close(self):
        await self.client.aclose()
```

#### Orchestrator Service

```python
# app/services/orchestrator.py
import asyncio
from typing import Dict, Any, List, Optional
from app.services.inventory_client import InventoryClient
from app.services.pricing_client import PricingClient

class Orchestrator:
    def __init__(self, inventory_client: InventoryClient, pricing_client: PricingClient):
        self.inventory_client = inventory_client
        self.pricing_client = pricing_client

    async def get_product_with_price(self, product_id: str, correlation_id: str) -> Dict[Any, Any]:
        """Parallel aggregation pattern"""
        # Fetch inventory and pricing data in parallel
        inventory_task = self.inventory_client.get_product(product_id, correlation_id)
        pricing_task = self.pricing_client.get_price(product_id, correlation_id)

        inventory, pricing = await asyncio.gather(
            inventory_task,
            pricing_task,
            return_exceptions=True
        )

        # Handle partial failures
        result = {}
        if not isinstance(inventory, Exception):
            result.update(inventory)
        else:
            result["inventory_error"] = str(inventory)

        if not isinstance(pricing, Exception):
            result["price"] = pricing.get("basePrice")
            result["currency"] = pricing.get("currency")
        else:
            result["pricing_error"] = str(pricing)

        return result

    async def create_order(self, order_data: Dict[Any, Any], correlation_id: str) -> Dict[Any, Any]:
        """Sequential orchestration with compensation"""
        order_id = f"ORDER-{correlation_id[:8]}"
        reserved_items = []

        try:
            # Step 1: Reserve inventory for all items
            for item in order_data["items"]:
                reservation = await self.inventory_client.reserve_stock(
                    item["productId"],
                    item["quantity"],
                    order_id,
                    correlation_id
                )
                reserved_items.append(reservation)

            # Step 2: Calculate total price
            total_price = 0
            for item in order_data["items"]:
                price_calc = await self.pricing_client.calculate_price(
                    item["productId"],
                    item["quantity"],
                    order_data.get("discountCodes", []),
                    correlation_id
                )
                total_price += float(price_calc["finalPrice"])

            # Step 3: Create order response
            return {
                "orderId": order_id,
                "status": "CONFIRMED",
                "items": reserved_items,
                "totalPrice": total_price,
                "currency": "USD"
            }

        except Exception as e:
            # Compensation: Release reserved inventory
            for reservation in reserved_items:
                try:
                    await self.inventory_client.release_stock(
                        reservation["reservationId"],
                        correlation_id
                    )
                except:
                    pass  # Log but don't fail compensation

            raise Exception(f"Order creation failed: {str(e)}")

    async def bulk_product_check(self, product_ids: List[str], correlation_id: str) -> List[Dict[Any, Any]]:
        """Scatter-gather pattern"""
        tasks = []
        for product_id in product_ids:
            task = self.get_product_with_price(product_id, correlation_id)
            tasks.append(task)

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Format results
        formatted_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                formatted_results.append({
                    "productId": product_ids[i],
                    "error": str(result)
                })
            else:
                formatted_results.append(result)

        return formatted_results
```

#### Circuit Breaker

```python
# app/core/circuit_breaker.py
import asyncio
from datetime import datetime, timedelta
from enum import Enum
from typing import Callable, Any, Type, Optional

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        expected_exception: Type[Exception] = Exception,
        half_open_requests: int = 3
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        self.half_open_requests = half_open_requests

        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        self.half_open_request_count = 0

    async def call(self, func: Callable[[], Any]) -> Any:
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
                self.half_open_request_count = 0
            else:
                raise Exception("Circuit breaker is OPEN")

        try:
            result = await func()
            self._on_success()
            return result
        except self.expected_exception as e:
            self._on_failure()
            raise e

    def _should_attempt_reset(self) -> bool:
        if self.last_failure_time is None:
            return False
        return datetime.now() >= self.last_failure_time + timedelta(seconds=self.recovery_timeout)

    def _on_success(self):
        if self.state == CircuitState.HALF_OPEN:
            self.half_open_request_count += 1
            if self.half_open_request_count >= self.half_open_requests:
                self.state = CircuitState.CLOSED
                self.failure_count = 0
        else:
            self.failure_count = 0

    def _on_failure(self):
        self.failure_count += 1
        self.last_failure_time = datetime.now()

        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN
```

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ app/

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Docker Compose Integration

```yaml
# Update docker-compose.yml
services:
  # ... existing services ...

  api-gateway:
    build: ./api-gateway
    container_name: api-gateway
    environment:
      <<: *common-variables
      INVENTORY_SERVICE_URL: http://inventory-service:8001
      PRICING_SERVICE_URL: http://pricing-service:8002
      SERVICE_TIMEOUT: "30"
      CIRCUIT_BREAKER_THRESHOLD: "5"
      CIRCUIT_BREAKER_TIMEOUT: "60"
    ports:
      - "8000:8000"
    depends_on:
      inventory-service:
        condition: service_healthy
      pricing-service:
        condition: service_healthy
    networks:
      - hello-dd-network
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    restart: unless-stopped
```

## Testing

### Integration Tests
```python
# tests/integration/test_orchestration.py
import pytest
import httpx
import asyncio

@pytest.mark.asyncio
async def test_product_aggregation():
    async with httpx.AsyncClient() as client:
        response = await client.get("http://localhost:8000/api/v1/products/TEST-001")
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert "price" in data
        assert "stockLevel" in data

@pytest.mark.asyncio
async def test_order_creation():
    async with httpx.AsyncClient() as client:
        order_data = {
            "items": [
                {"productId": "TEST-001", "quantity": 2},
                {"productId": "TEST-002", "quantity": 1}
            ],
            "discountCodes": ["SUMMER20"]
        }
        response = await client.post(
            "http://localhost:8000/api/v1/orders",
            json=order_data
        )
        assert response.status_code in [200, 201]
        data = response.json()
        assert "orderId" in data
        assert "totalPrice" in data
```

## Deliverables

1. **Working API Gateway**
   - Service orchestration implemented
   - Circuit breakers protecting backends
   - Correlation ID propagation
   - All endpoints functional

2. **Docker Integration**
   - Three services running together
   - Inter-service communication working
   - Health checks passing
   - Environment configuration

3. **Resilience Features**
   - Circuit breakers tested
   - Retry logic implemented
   - Timeout handling
   - Partial failure handling

## Success Criteria

- API Gateway routes requests correctly
- Parallel aggregation working
- Sequential orchestration with compensation
- Circuit breakers prevent cascading failures
- All three services communicating
- Correlation IDs tracked throughout
- Docker Compose system fully functional

## Preparation for Phase 7

Ready for:
- Full Kubernetes deployment
- Ingress configuration
- Service mesh integration
- Production deployment patterns