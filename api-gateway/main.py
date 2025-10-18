"""
Minimal API Gateway Service for Datadog APM Demo
Fast track implementation with basic endpoints for distributed tracing
"""

import os
import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import random

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from contextlib import asynccontextmanager

import httpx
import redis
import asyncpg
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global connections
redis_client: Optional[redis.Redis] = None
db_pool: Optional[asyncpg.Pool] = None
http_client: Optional[httpx.AsyncClient] = None


# Pydantic models
class HealthResponse(BaseModel):
    status: str
    service: str = "api-gateway"
    timestamp: str
    version: str = "1.0.0"


class ProductResponse(BaseModel):
    id: int
    sku: str
    name: str
    stock_level: int
    price: float


class CacheTestResponse(BaseModel):
    key: str
    value: str
    ttl: int
    operation: str
    timestamp: str


class ServiceCallResponse(BaseModel):
    source: str = "api-gateway"
    target: str
    status: str
    data: Dict[str, Any]
    timestamp: str


# Lifecycle management
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle - startup and shutdown"""
    global redis_client, db_pool, http_client

    # Startup
    logger.info("Starting API Gateway...")

    # Initialize Redis connection
    try:
        redis_host = os.getenv("REDIS_HOST", "localhost")
        redis_port = int(os.getenv("REDIS_PORT", 6379))
        redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            decode_responses=True,
            socket_connect_timeout=5
        )
        redis_client.ping()
        logger.info(f"Connected to Redis at {redis_host}:{redis_port}")
    except Exception as e:
        logger.warning(f"Could not connect to Redis: {e}")
        redis_client = None

    # Initialize PostgreSQL connection pool
    try:
        db_url = (
            f"postgresql://"
            f"{os.getenv('POSTGRES_USER', 'postgres')}:"
            f"{os.getenv('POSTGRES_PASSWORD', 'postgres')}@"
            f"{os.getenv('POSTGRES_HOST', 'localhost')}:"
            f"{os.getenv('POSTGRES_PORT', 5432)}/"
            f"{os.getenv('POSTGRES_DB', 'inventory')}"
        )
        db_pool = await asyncpg.create_pool(
            db_url,
            min_size=2,
            max_size=10,
            command_timeout=10
        )
        logger.info("Connected to PostgreSQL")
    except Exception as e:
        logger.warning(f"Could not connect to PostgreSQL: {e}")
        db_pool = None

    # Initialize HTTP client for service-to-service calls
    http_client = httpx.AsyncClient(timeout=30.0)

    yield

    # Shutdown
    logger.info("Shutting down API Gateway...")

    if redis_client:
        redis_client.close()

    if db_pool:
        await db_pool.close()

    if http_client:
        await http_client.aclose()


# Create FastAPI app
app = FastAPI(
    title="API Gateway",
    description="Minimal API Gateway for Datadog APM Demo",
    version="1.0.0",
    lifespan=lifespan
)


# Endpoints
@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint"""
    return {
        "service": "api-gateway",
        "message": "Hello from API Gateway",
        "version": "1.0.0"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow().isoformat()
    )


@app.get("/test-db", response_model=Dict[str, Any])
async def test_database():
    """Test PostgreSQL connection and query sample data"""
    global db_pool

    if not db_pool:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection not available"
        )

    try:
        async with db_pool.acquire() as conn:
            # Test connection with a simple query
            version = await conn.fetchval("SELECT version()")

            # Try to fetch some products (if table exists)
            try:
                products = await conn.fetch(
                    "SELECT id, sku, name, stock_level, price "
                    "FROM inventory.products "
                    "LIMIT 5"
                )

                product_list = [
                    {
                        "id": str(p["id"]),
                        "sku": p["sku"],
                        "name": p["name"],
                        "stock_level": p["stock_level"],
                        "price": float(p["price"]) if p["price"] else 0
                    }
                    for p in products
                ]
            except Exception as e:
                logger.warning(f"Could not fetch products: {e}")
                product_list = []

            return {
                "status": "connected",
                "database": "PostgreSQL",
                "version": version,
                "sample_products": product_list,
                "product_count": len(product_list),
                "timestamp": datetime.utcnow().isoformat()
            }

    except Exception as e:
        logger.error(f"Database error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {str(e)}"
        )


@app.get("/test-redis", response_model=CacheTestResponse)
async def test_redis():
    """Test Redis connection and basic operations"""
    global redis_client

    if not redis_client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Redis connection not available"
        )

    try:
        # Generate test key and value
        test_key = f"test:api-gateway:{datetime.utcnow().timestamp()}"
        test_value = f"Hello from API Gateway at {datetime.utcnow().isoformat()}"

        # Set value with TTL
        redis_client.setex(test_key, 60, test_value)

        # Get value back
        retrieved_value = redis_client.get(test_key)
        ttl = redis_client.ttl(test_key)

        return CacheTestResponse(
            key=test_key,
            value=retrieved_value or "",
            ttl=ttl,
            operation="SET/GET",
            timestamp=datetime.utcnow().isoformat()
        )

    except Exception as e:
        logger.error(f"Redis error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Redis operation failed: {str(e)}"
        )


@app.get("/test-http/{service}", response_model=ServiceCallResponse)
async def test_http_call(service: str):
    """Test HTTP call to another service (for distributed tracing demo)"""
    global http_client

    if not http_client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="HTTP client not initialized"
        )

    # Define service endpoints (these would be real services in production)
    service_urls = {
        "inventory": os.getenv("INVENTORY_SERVICE_URL", "http://inventory-service:8001"),
        "pricing": os.getenv("PRICING_SERVICE_URL", "http://pricing-service:8002"),
        "external": "https://httpbin.org/json"  # External service for testing
    }

    if service not in service_urls:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown service: {service}. Available: {list(service_urls.keys())}"
        )

    try:
        # Make HTTP call to the service
        url = service_urls[service]

        # For demo purposes, if internal services aren't available, mock the response
        if service in ["inventory", "pricing"]:
            # Try to call the actual service
            try:
                response = await http_client.get(f"{url}/health", timeout=5.0)
                response_data = response.json()
                call_status = "success"
            except Exception:
                # Mock response if service isn't running
                response_data = {
                    "mocked": True,
                    "service": service,
                    "message": f"Mocked response from {service}",
                    "timestamp": datetime.utcnow().isoformat()
                }
                call_status = "mocked"
        else:
            # Call external service
            response = await http_client.get(url)
            response_data = response.json()
            call_status = "success"

        return ServiceCallResponse(
            target=service,
            status=call_status,
            data=response_data,
            timestamp=datetime.utcnow().isoformat()
        )

    except Exception as e:
        logger.error(f"HTTP call error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Service call failed: {str(e)}"
        )


@app.get("/products", response_model=Dict[str, Any])
async def get_products(limit: int = 10):
    """Get products with pricing (composite operation for tracing)"""
    global db_pool, redis_client

    result = {
        "products": [],
        "source": "database",
        "cached": False,
        "timestamp": datetime.utcnow().isoformat()
    }

    # Try cache first
    if redis_client:
        try:
            cache_key = f"products:list:{limit}"
            cached_data = redis_client.get(cache_key)
            if cached_data:
                import json
                result["products"] = json.loads(cached_data)
                result["source"] = "cache"
                result["cached"] = True
                return result
        except Exception as e:
            logger.warning(f"Cache read failed: {e}")

    # Fetch from database
    if db_pool:
        try:
            async with db_pool.acquire() as conn:
                products = await conn.fetch(
                    "SELECT id, sku, name, stock_level, price "
                    "FROM inventory.products "
                    "LIMIT $1",
                    limit
                )

                product_list = [
                    {
                        "id": str(p["id"]),
                        "sku": p["sku"],
                        "name": p["name"],
                        "stock_level": p["stock_level"],
                        "price": float(p["price"]) if p["price"] else 0,
                        # Add mock pricing calculation
                        "discounted_price": float(p["price"]) * 0.9 if p["price"] else 0
                    }
                    for p in products
                ]

                result["products"] = product_list

                # Cache the result
                if redis_client and product_list:
                    try:
                        import json
                        cache_key = f"products:list:{limit}"
                        redis_client.setex(
                            cache_key,
                            300,  # 5 minutes TTL
                            json.dumps(product_list)
                        )
                    except Exception as e:
                        logger.warning(f"Cache write failed: {e}")

        except Exception as e:
            logger.error(f"Database error: {e}")
            # Return mock data if database fails
            result["products"] = [
                {
                    "id": f"mock-{i}",
                    "sku": f"MOCK-{i:03d}",
                    "name": f"Mock Product {i}",
                    "stock_level": random.randint(0, 100),
                    "price": round(random.uniform(10, 1000), 2),
                    "discounted_price": round(random.uniform(9, 900), 2)
                }
                for i in range(1, min(limit + 1, 6))
            ]
            result["source"] = "mock"
    else:
        # No database connection, return mock data
        result["products"] = [
            {
                "id": f"mock-{i}",
                "sku": f"MOCK-{i:03d}",
                "name": f"Mock Product {i}",
                "stock_level": random.randint(0, 100),
                "price": round(random.uniform(10, 1000), 2),
                "discounted_price": round(random.uniform(9, 900), 2)
            }
            for i in range(1, min(limit + 1, 6))
        ]
        result["source"] = "mock"

    return result


@app.post("/order", response_model=Dict[str, Any])
async def create_order(product_id: str, quantity: int = 1):
    """Create an order (demonstrates distributed transaction)"""

    # This is a simplified order creation that would normally:
    # 1. Check inventory (call inventory service)
    # 2. Calculate price (call pricing service)
    # 3. Reserve stock
    # 4. Process payment
    # 5. Confirm order

    order = {
        "order_id": f"ORD-{datetime.utcnow().timestamp():.0f}",
        "product_id": product_id,
        "quantity": quantity,
        "status": "pending",
        "steps": []
    }

    # Simulate service calls with some latency
    steps = [
        ("inventory_check", 0.1),
        ("price_calculation", 0.05),
        ("stock_reservation", 0.15),
        ("payment_processing", 0.2),
        ("order_confirmation", 0.05)
    ]

    for step_name, delay in steps:
        await asyncio.sleep(delay)  # Simulate processing time
        order["steps"].append({
            "name": step_name,
            "status": "completed",
            "duration_ms": int(delay * 1000)
        })

    order["status"] = "confirmed"
    order["total_duration_ms"] = sum(s["duration_ms"] for s in order["steps"])
    order["timestamp"] = datetime.utcnow().isoformat()

    return order


@app.get("/error-test/{error_type}")
async def test_error(error_type: str):
    """Test error scenarios for APM error tracking"""

    if error_type == "400":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bad request error for testing"
        )
    elif error_type == "404":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resource not found for testing"
        )
    elif error_type == "500":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error for testing"
        )
    elif error_type == "timeout":
        await asyncio.sleep(35)  # Cause a timeout
        return {"message": "This should timeout"}
    elif error_type == "exception":
        # Raise an unhandled exception
        raise ValueError("Unhandled exception for testing APM error tracking")
    else:
        return {
            "message": "Unknown error type",
            "available": ["400", "404", "500", "timeout", "exception"]
        }


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")

    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=os.getenv("RELOAD", "false").lower() == "true",
        log_level=os.getenv("LOG_LEVEL", "info").lower()
    )