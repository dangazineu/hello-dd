# hello-dd: Distributed Tracing Demonstration

A multi-service application demonstrating distributed tracing patterns for Datadog APM automatic instrumentation testing.

## Project Overview

This repository contains a microservices architecture designed to explore Datadog's automatic instrumentation capabilities, particularly focusing on distributed tracing across multiple languages and runtime environments. The project intentionally starts without any instrumentation to test Datadog's Single Step APM and automatic instrumentation features.

## Architecture

### Services

#### 1. API Gateway Service (Python - FastAPI)
**Port:** 8000  
**Role:** Main entry point for all client requests

The API Gateway acts as the orchestration layer, receiving client requests and coordinating calls to downstream services based on request parameters. This service will demonstrate:
- Request routing and orchestration patterns
- Fan-out and fan-in communication patterns
- Error propagation and handling across service boundaries
- Async and sync communication methods

#### 2. Inventory Service (Java - Spring Boot)
**Port:** 8001  
**Role:** Product inventory and stock management

The Inventory Service manages product catalog and stock levels. It provides:
- Product catalog queries
- Stock level checks
- Inventory reservation/release operations
- Database interactions (PostgreSQL or H2 for simplicity)

#### 3. Pricing Service (Go - Gin/Echo)
**Port:** 8002  
**Role:** Dynamic pricing calculations and discount management

The Pricing Service handles all pricing logic including:
- Base price retrieval
- Dynamic pricing calculations based on demand/time
- Discount application and validation
- Currency conversion operations
- Cache interactions (Redis optional)

## Request Flow Patterns

### Pattern 1: Simple Product Query
**Endpoint:** `GET /api/v1/products/{id}`
**Flow:** 
1. API Gateway receives request
2. Parallel calls to:
   - Inventory Service: Get product details and stock level
   - Pricing Service: Get current price
3. API Gateway aggregates responses
4. Return consolidated product information

### Pattern 2: Order Checkout Flow
**Endpoint:** `POST /api/v1/orders`
**Flow:**
1. API Gateway receives order request
2. Sequential operations:
   - Inventory Service: Check stock availability for all items
   - Pricing Service: Calculate total with applicable discounts
   - Inventory Service: Reserve inventory (if available)
   - Pricing Service: Finalize pricing with taxes
3. API Gateway coordinates rollback on any failure
4. Return order confirmation or error

### Pattern 3: Bulk Operations
**Endpoint:** `POST /api/v1/products/bulk-check`
**Flow:**
1. API Gateway receives list of product IDs
2. Batched operations:
   - Split request into chunks
   - Parallel calls to Inventory Service for each chunk
   - Aggregate and sort results
   - Optional: Call Pricing Service for products in stock
3. Stream or paginate results back to client

### Pattern 4: Async Processing
**Endpoint:** `POST /api/v1/reports/generate`
**Flow:**
1. API Gateway accepts report request
2. Async workflow:
   - Queue report generation task
   - Inventory Service: Gather historical data
   - Pricing Service: Calculate analytics
   - Store results (simulate with delay)
3. Return job ID for status polling

### Pattern 5: Circuit Breaker Demonstration
**Endpoint:** `GET /api/v1/health/cascade`
**Parameters:** `?failure_mode={pricing|inventory|random}`
**Flow:**
1. API Gateway initiates health check cascade
2. Conditional failures:
   - Simulate service timeouts
   - Trigger circuit breakers
   - Demonstrate retry logic
   - Show fallback responses

## Non-Functional Requirements

### Instrumentation Approach
- **Phase 1:** No instrumentation - raw application
- **Phase 2:** Deploy Datadog Agent with Single Step APM
- **Phase 3:** Compare with manual SDK instrumentation
- **Phase 4:** Test OpenTelemetry instrumentation paths

### Observability Scenarios to Test
1. **Distributed Trace Correlation**: Verify trace continuity across all services
2. **Context Propagation**: Test W3C Trace Context headers
3. **Error Tracking**: Propagation of errors through call chain
4. **Performance Monitoring**: Latency attribution across services
5. **Service Dependencies**: Automatic service map generation
6. **Database Query Performance**: SQL query visibility
7. **HTTP Client Metrics**: External call instrumentation
8. **Custom Business Metrics**: Revenue, inventory levels, etc.

### Load Testing Scenarios
- Steady state: 100 req/sec across all endpoints
- Spike testing: 1000 req/sec burst for 30 seconds
- Soak testing: 50 req/sec for 1 hour
- Chaos testing: Random failures and latency injection

## Implementation Guidelines

### API Gateway (Python)
```python
# Core dependencies
- FastAPI or Flask
- httpx or requests for HTTP clients  
- asyncio for concurrent operations
- pydantic for request/response validation

# Key features to implement:
- Request routing based on path and parameters
- Request/response transformation
- Error aggregation and formatting
- Correlation ID generation and propagation
- Timeout management for downstream calls
- Basic rate limiting
```

### Inventory Service (Java)
```java
// Core dependencies
- Spring Boot 3.x
- Spring Data JPA
- H2 or PostgreSQL driver
- Lombok for boilerplate reduction

// Key features to implement:
- RESTful API endpoints
- Database entity management
- Transactional operations
- Optimistic locking for concurrent updates
- Bulk operation handling
- Basic caching with Spring Cache
```

### Pricing Service (Go)
```go
// Core dependencies
- Gin or Echo framework
- Built-in net/http for clients
- Optional: go-redis client
- goroutines for concurrent processing

// Key features to implement:
- RESTful pricing endpoints
- In-memory price catalog
- Dynamic pricing algorithms
- Discount rule engine
- Currency conversion
- Response caching strategies
```

## Development Phases

### Phase 1: Basic Service Implementation (Week 1)
- [ ] Scaffold all three services with basic health endpoints
- [ ] Implement core business logic without external dependencies
- [ ] Create docker-compose.yml for local development
- [ ] Add Makefile for common operations
- [ ] Verify inter-service communication works

### Phase 2: Enhanced Functionality (Week 2)
- [ ] Add database to Inventory Service
- [ ] Implement caching in Pricing Service
- [ ] Add all 5 request flow patterns
- [ ] Implement error handling and retries
- [ ] Add basic logging to all services

### Phase 3: Production Readiness (Week 3)
- [ ] Add configuration management (environment variables)
- [ ] Implement graceful shutdown
- [ ] Add metrics endpoints (Prometheus format)
- [ ] Create load testing scripts (k6 or locust)
- [ ] Document API with OpenAPI/Swagger

### Phase 4: Datadog Integration Testing (Week 4)
- [ ] Deploy Datadog Agent
- [ ] Test Single Step APM
- [ ] Verify automatic instrumentation coverage
- [ ] Identify instrumentation gaps
- [ ] Compare with manual SDK installation
- [ ] Test OpenTelemetry Collector integration

## Success Criteria

1. **Automatic Instrumentation Coverage**
   - All services appear in Datadog Service Map without manual SDK installation
   - Distributed traces show complete request flow
   - Database queries are automatically captured
   - HTTP client calls are instrumented

2. **Trace Continuity**
   - Single trace ID across all services for each request
   - Proper parent-child span relationships
   - No orphaned spans or broken traces

3. **Performance Visibility**
   - Service-level latency breakdown
   - Database query performance metrics
   - Network call durations
   - Error rates per endpoint

4. **OpenTelemetry Compatibility**
   - Services work with OTLP (OpenTelemetry Protocol)
   - W3C Trace Context properly propagated
   - Baggage headers handled correctly (when supported)

## Repository Structure

```
hello-dd/
├── api-gateway/           # Python FastAPI service
│   ├── src/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
├── inventory-service/     # Java Spring Boot service
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── pricing-service/       # Go Gin/Echo service
│   ├── cmd/
│   ├── internal/
│   ├── go.mod
│   └── Dockerfile
├── docker-compose.yml     # Local development environment
├── k8s/                  # Kubernetes manifests (optional)
│   ├── api-gateway.yaml
│   ├── inventory.yaml
│   └── pricing.yaml
├── scripts/              # Utility scripts
│   ├── load-test.js     # k6 load testing
│   └── setup.sh         # Environment setup
├── docs/                 # Additional documentation
│   ├── API.md
│   ├── TROUBLESHOOTING.md
│   └── DATADOG_SETUP.md
├── Makefile             # Build and run commands
└── README.md            # This file

```

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Java 17+ (for Inventory Service development)
- Python 3.11+ (for API Gateway development)  
- Go 1.21+ (for Pricing Service development)
- Datadog account and API key
- Optional: Kubernetes cluster for advanced testing

### Local Development

```bash
# Clone repository
git clone <repository-url>
cd hello-dd

# Start all services
docker-compose up

# Run individual services for development
make run-gateway    # Start API Gateway
make run-inventory  # Start Inventory Service
make run-pricing    # Start Pricing Service

# Run load tests
make load-test

# View logs
docker-compose logs -f [service-name]
```

### Kubernetes/EKS Deployment

For deploying to AWS EKS, see the comprehensive setup guides:

- **Quick Start:** [docs/QUICK_START_EKS.md](docs/QUICK_START_EKS.md) - Fast track to get your cluster running
- **Full Guide:** [docs/EKS_SETUP_GUIDE.md](docs/EKS_SETUP_GUIDE.md) - Detailed instructions and troubleshooting
- **ECR Setup:** [docs/ECR_SETUP_GUIDE.md](docs/ECR_SETUP_GUIDE.md) - Push Docker images to Amazon ECR

**Automated setup scripts:**
```bash
# 1. Create EKS cluster (15-20 minutes)
./scripts/create-eks-cluster.sh

# 2. Verify cluster health
./scripts/verify-eks-cluster.sh

# 3. Build and push Docker images to ECR
./scripts/push-to-ecr.sh

# 4. Deploy services (coming soon)
kubectl apply -f k8s/
```

**Prerequisites for EKS:**
- AWS CLI configured with credentials
- eksctl installed
- kubectl installed
- Docker installed (for building images)
- AWS account with appropriate permissions

See [docs/QUICK_START_EKS.md](docs/QUICK_START_EKS.md) for step-by-step tool installation instructions.

## Notes

This project is specifically designed to explore Datadog's automatic instrumentation capabilities and understand the gaps between Datadog native instrumentation and OpenTelemetry instrumentation. The architecture intentionally includes patterns that will exercise different aspects of distributed tracing:

- **Synchronous vs asynchronous communication**
- **Fan-out/fan-in patterns**  
- **Error propagation**
- **Database interactions**
- **Caching layers**
- **Circuit breakers and retries**

The lack of initial instrumentation is intentional - we want to see what Datadog can automatically discover and instrument versus what requires manual SDK integration.

## Related Documentation

- [Datadog Single Step APM](https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/single-step-apm/)
- [OpenTelemetry in Datadog](https://docs.datadoghq.com/opentelemetry/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Distributed Tracing Best Practices](https://docs.datadoghq.com/tracing/guide/distributed-tracing/)

---

**Project Owner:** Dan Gazineu  
**Purpose:** Datadog APM and OpenTelemetry Learning  
**Created:** October 2025