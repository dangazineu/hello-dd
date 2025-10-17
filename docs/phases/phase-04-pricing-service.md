# Phase 4: Pricing Service Implementation

## Overview
Build and integrate the Pricing Service into the Docker Compose environment. This creates a high-performance Go microservice that works alongside the Inventory Service locally before Kubernetes deployment.

## Objectives
- Implement Go Gin-based Pricing Service
- Integrate with Redis for caching
- Add to Docker Compose alongside Inventory Service
- Test inter-service communication locally
- Prepare for Kubernetes deployment (Phase 5)

## Service Implementation

### Project Structure
```
pricing-service/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── api/
│   │   ├── handlers/
│   │   │   ├── health.go
│   │   │   ├── pricing.go
│   │   │   └── discount.go
│   │   ├── middleware/
│   │   │   ├── cors.go
│   │   │   └── logging.go
│   │   └── routes.go
│   ├── domain/
│   │   ├── models/
│   │   │   ├── price.go
│   │   │   └── discount.go
│   │   └── services/
│   │       ├── pricing_service.go
│   │       └── discount_service.go
│   ├── cache/
│   │   └── redis_client.go
│   └── config/
│       └── config.go
├── pkg/
│   └── decimal/
│       └── decimal.go
├── Dockerfile
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### Core Implementation

#### Main Application
```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/helloddd/pricing/internal/api"
    "github.com/helloddd/pricing/internal/cache"
    "github.com/helloddd/pricing/internal/config"
)

func main() {
    // Load configuration
    cfg := config.Load()

    // Initialize Redis cache
    cacheClient := cache.NewRedisClient(cfg.Redis)

    // Create Gin router
    router := gin.New()
    router.Use(gin.Recovery())
    router.Use(gin.Logger())

    // Setup routes
    api.SetupRoutes(router, cacheClient, cfg)

    // Create server
    srv := &http.Server{
        Addr:    ":" + cfg.Port,
        Handler: router,
    }

    // Graceful shutdown
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Failed to start server: %v", err)
        }
    }()

    log.Printf("Pricing Service started on port %s", cfg.Port)

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}
```

#### Pricing Model
```go
// internal/domain/models/price.go
package models

import (
    "time"
    "github.com/shopspring/decimal"
)

type Price struct {
    ProductID    string          `json:"productId"`
    BasePrice    decimal.Decimal `json:"basePrice"`
    Currency     string          `json:"currency"`
    ValidFrom    time.Time       `json:"validFrom"`
    ValidUntil   time.Time       `json:"validUntil"`
    PriceType    PriceType       `json:"priceType"`
}

type PriceType string

const (
    StandardPrice    PriceType = "STANDARD"
    PromotionalPrice PriceType = "PROMOTIONAL"
    DynamicPrice     PriceType = "DYNAMIC"
)

type PriceCalculation struct {
    ProductID    string                     `json:"productId"`
    Quantity     int                        `json:"quantity"`
    BasePrice    decimal.Decimal            `json:"basePrice"`
    Discounts    []AppliedDiscount          `json:"discounts"`
    Tax          decimal.Decimal            `json:"tax"`
    FinalPrice   decimal.Decimal            `json:"finalPrice"`
    Currency     string                     `json:"currency"`
    Breakdown    map[string]decimal.Decimal `json:"breakdown"`
}
```

#### Pricing Handler
```go
// internal/api/handlers/pricing.go
package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/helloddd/pricing/internal/domain/services"
)

type PricingHandler struct {
    service *services.PricingService
}

func NewPricingHandler(service *services.PricingService) *PricingHandler {
    return &PricingHandler{service: service}
}

func (h *PricingHandler) GetPrice(c *gin.Context) {
    productID := c.Param("productId")

    price, err := h.service.GetProductPrice(c.Request.Context(), productID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Price not found"})
        return
    }

    c.JSON(http.StatusOK, price)
}

func (h *PricingHandler) CalculatePrice(c *gin.Context) {
    var request PriceCalculationRequest
    if err := c.ShouldBindJSON(&request); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    calculation, err := h.service.CalculatePrice(
        c.Request.Context(),
        request.ProductID,
        request.Quantity,
        request.DiscountCodes,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, calculation)
}

func (h *PricingHandler) BulkPrice(c *gin.Context) {
    var request BulkPriceRequest
    if err := c.ShouldBindJSON(&request); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    prices, err := h.service.GetBulkPrices(c.Request.Context(), request.ProductIDs)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, prices)
}
```

#### Redis Cache Implementation
```go
// internal/cache/redis_client.go
package cache

import (
    "context"
    "encoding/json"
    "time"

    "github.com/go-redis/redis/v8"
)

type RedisCache struct {
    client *redis.Client
}

func NewRedisClient(config RedisConfig) *RedisCache {
    client := redis.NewClient(&redis.Options{
        Addr:     config.Address,
        Password: config.Password,
        DB:       config.DB,
    })

    return &RedisCache{client: client}
}

func (r *RedisCache) Get(ctx context.Context, key string, dest interface{}) error {
    val, err := r.client.Get(ctx, key).Result()
    if err != nil {
        return err
    }

    return json.Unmarshal([]byte(val), dest)
}

func (r *RedisCache) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
    data, err := json.Marshal(value)
    if err != nil {
        return err
    }

    return r.client.Set(ctx, key, data, ttl).Err()
}

func (r *RedisCache) Delete(ctx context.Context, key string) error {
    return r.client.Del(ctx, key).Err()
}

func (r *RedisCache) Health(ctx context.Context) error {
    return r.client.Ping(ctx).Err()
}
```

### Configuration

#### Config Structure
```go
// internal/config/config.go
package config

import (
    "os"
    "strconv"
)

type Config struct {
    Port        string
    Environment string
    LogLevel    string
    Redis       RedisConfig
    Cache       CacheConfig
}

type RedisConfig struct {
    Address  string
    Password string
    DB       int
}

type CacheConfig struct {
    TTL             int // seconds
    MaxEntries      int
    CleanupInterval int // seconds
}

func Load() *Config {
    return &Config{
        Port:        getEnv("PORT", "8002"),
        Environment: getEnv("DD_ENV", "development"),
        LogLevel:    getEnv("LOG_LEVEL", "INFO"),
        Redis: RedisConfig{
            Address:  getEnv("REDIS_HOST", "localhost") + ":" + getEnv("REDIS_PORT", "6379"),
            Password: getEnv("REDIS_PASSWORD", ""),
            DB:       getEnvAsInt("REDIS_DB", 0),
        },
        Cache: CacheConfig{
            TTL:             getEnvAsInt("CACHE_TTL", 300),
            MaxEntries:      getEnvAsInt("CACHE_MAX_ENTRIES", 1000),
            CleanupInterval: getEnvAsInt("CACHE_CLEANUP_INTERVAL", 60),
        },
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    valueStr := getEnv(key, "")
    if value, err := strconv.Atoi(valueStr); err == nil {
        return value
    }
    return defaultValue
}
```

### Dockerfile
```dockerfile
# Multi-stage build
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o pricing-service cmd/server/main.go

# Final stage
FROM alpine:3.18

RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/pricing-service .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8002/health || exit 1

EXPOSE 8002

CMD ["./pricing-service"]
```

## Docker Compose Integration

### Update docker-compose.yml
```yaml
# Add to docker-compose.yml
services:
  # ... existing services ...

  pricing-service:
    build: ./pricing-service
    container_name: pricing-service
    environment:
      <<: *common-variables
      PORT: "8002"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      CACHE_TTL: "300"
      GIN_MODE: release
    ports:
      - "8002:8002"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - hello-dd-network
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost:8002/health"]
    restart: unless-stopped
```

## Testing

### Unit Tests
```go
// internal/domain/services/pricing_service_test.go
package services

import (
    "context"
    "testing"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

func TestPricingService_CalculatePrice(t *testing.T) {
    // Setup
    mockCache := new(MockCache)
    service := NewPricingService(mockCache)

    // Test data
    productID := "TEST-001"
    quantity := 5
    basePrice := decimal.NewFromFloat(29.99)

    // Mock cache response
    mockCache.On("Get", mock.Anything, mock.Anything, mock.Anything).Return(nil)

    // Execute
    result, err := service.CalculatePrice(context.Background(), productID, quantity, nil)

    // Assert
    assert.NoError(t, err)
    assert.Equal(t, productID, result.ProductID)
    assert.Equal(t, quantity, result.Quantity)
    assert.True(t, result.FinalPrice.GreaterThan(decimal.Zero))
}
```

### Integration Tests
```bash
#!/bin/bash
# scripts/test-pricing.sh

echo "Testing Pricing Service..."

# Health check
curl -f http://localhost:8002/health || exit 1

# Get price
curl -X GET http://localhost:8002/api/v1/prices/LAPTOP-001

# Calculate price with quantity
curl -X POST http://localhost:8002/api/v1/prices/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "LAPTOP-001",
    "quantity": 2,
    "discountCodes": ["SUMMER20"]
  }'

# Bulk pricing
curl -X POST http://localhost:8002/api/v1/prices/bulk \
  -H "Content-Type: application/json" \
  -d '{
    "productIds": ["LAPTOP-001", "MOUSE-001", "KEYBOARD-001"]
  }'

echo "Pricing Service tests completed!"
```

## Local Development

### Makefile
```makefile
# pricing-service/Makefile
.PHONY: build run test docker-build docker-run

build:
	go build -o bin/pricing-service cmd/server/main.go

run:
	go run cmd/server/main.go

test:
	go test -v ./...

test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out

docker-build:
	docker build -t pricing-service:latest .

docker-run:
	docker run -p 8002:8002 --env-file ../.env pricing-service:latest

lint:
	golangci-lint run

fmt:
	go fmt ./...

deps:
	go mod download
	go mod tidy
```

### Running Locally
```bash
# Build and run the service
cd pricing-service
make build
make run

# Or with Docker Compose (from root)
make build-pricing-service
make restart

# Test the service
curl http://localhost:8002/health
curl http://localhost:8002/api/v1/prices/TEST-001

# Run tests
cd pricing-service
make test
make test-coverage
```

## Deliverables

1. **Working Pricing Service**
   - Dynamic pricing calculations
   - Discount management system
   - Redis caching integration
   - Bulk pricing operations

2. **Docker Integration**
   - Service in Docker Compose
   - Communication with Redis
   - Health checks configured
   - Environment-based configuration

3. **Testing Suite**
   - Unit tests with mocks
   - Integration tests
   - Performance benchmarks
   - Load testing scripts

4. **Development Tools**
   - Makefile for common tasks
   - Hot reload with air
   - Linting configuration
   - API documentation

## Success Criteria

- Service builds and starts successfully
- All endpoints respond correctly
- Redis caching improves performance
- Discount calculations accurate
- Bulk operations efficient
- Health check returns UP
- Integration with Docker Compose working
- Can run alongside Inventory Service

## Preparation for Phase 5

This phase delivers:
- Second microservice in Go
- Redis integration patterns
- High-performance API design
- Caching strategies

Ready for:
- Kubernetes deployment (Phase 5)
- Multi-service orchestration
- Service discovery patterns
- Production deployment