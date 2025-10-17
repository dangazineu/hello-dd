# Phase 2: Inventory Service Implementation

## Overview
Build and integrate the Inventory Service into the Docker Compose environment established in Phase 1. This creates the first fully functional microservice that can be tested locally before deployment.

## Objectives
- Implement Java Spring Boot Inventory Service
- Integrate with PostgreSQL from Phase 1
- Add service to Docker Compose environment
- Implement comprehensive testing
- Prepare service for Kubernetes deployment (Phase 3)

## Service Implementation

### Project Structure
```
inventory-service/
├── src/
│   ├── main/
│   │   ├── java/com/helloddd/inventory/
│   │   │   ├── controller/
│   │   │   │   ├── ProductController.java
│   │   │   │   └── StockController.java
│   │   │   ├── service/
│   │   │   │   ├── InventoryService.java
│   │   │   │   └── StockManagementService.java
│   │   │   ├── repository/
│   │   │   │   ├── ProductRepository.java
│   │   │   │   └── StockTransactionRepository.java
│   │   │   ├── model/
│   │   │   │   ├── Product.java
│   │   │   │   └── StockTransaction.java
│   │   │   ├── dto/
│   │   │   │   ├── ProductRequest.java
│   │   │   │   ├── ProductResponse.java
│   │   │   │   └── StockReservationRequest.java
│   │   │   ├── exception/
│   │   │   │   ├── ProductNotFoundException.java
│   │   │   │   └── InsufficientStockException.java
│   │   │   ├── config/
│   │   │   │   └── DatabaseConfig.java
│   │   │   └── InventoryApplication.java
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-docker.yml
│   │       └── db/migration/
│   │           └── V1__Initial_schema.sql
├── src/test/
│   └── java/com/helloddd/inventory/
│       ├── unit/
│       └── integration/
├── Dockerfile
├── pom.xml
└── README.md
```

### Core Implementation Files

#### Main Application
```java
// InventoryApplication.java
package com.helloddd.inventory;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling  // For reservation expiration
public class InventoryApplication {
    public static void main(String[] args) {
        SpringApplication.run(InventoryApplication.class, args);
    }
}
```

#### Product Model
```java
// model/Product.java
package com.helloddd.inventory.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "products", schema = "inventory")
@Data
public class Product {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false, length = 100)
    private String sku;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    private String category;

    @Column(name = "stock_level", nullable = false)
    private Integer stockLevel = 0;

    @Column(name = "reserved_stock", nullable = false)
    private Integer reservedStock = 0;

    @Column(name = "reorder_point")
    private Integer reorderPoint = 10;

    @Column(name = "unit_cost", precision = 10, scale = 2)
    private BigDecimal unitCost;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Version
    private Long version;  // For optimistic locking

    public Integer getAvailableStock() {
        return stockLevel - reservedStock;
    }
}
```

#### Controller Implementation
```java
// controller/ProductController.java
package com.helloddd.inventory.controller;

import com.helloddd.inventory.dto.ProductRequest;
import com.helloddd.inventory.dto.ProductResponse;
import com.helloddd.inventory.service.InventoryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
@Tag(name = "Products", description = "Product management endpoints")
public class ProductController {

    private final InventoryService inventoryService;

    @GetMapping
    @Operation(summary = "List all products")
    public Page<ProductResponse> listProducts(Pageable pageable) {
        return inventoryService.getAllProducts(pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get product by ID")
    public ProductResponse getProduct(@PathVariable UUID id) {
        return inventoryService.getProductById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create new product")
    public ProductResponse createProduct(@Validated @RequestBody ProductRequest request) {
        return inventoryService.createProduct(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update product")
    public ProductResponse updateProduct(
            @PathVariable UUID id,
            @Validated @RequestBody ProductRequest request) {
        return inventoryService.updateProduct(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete product")
    public void deleteProduct(@PathVariable UUID id) {
        inventoryService.deleteProduct(id);
    }

    @GetMapping("/{id}/stock")
    @Operation(summary = "Get stock information")
    public StockInfo getStock(@PathVariable UUID id) {
        return inventoryService.getStockInfo(id);
    }
}
```

### Configuration Files

#### Application Configuration
```yaml
# application.yml
spring:
  application:
    name: inventory-service

  datasource:
    url: jdbc:postgresql://localhost:5432/inventory
    username: inventory
    password: inventory
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        default_schema: inventory
    show-sql: false

  flyway:
    enabled: true
    baseline-on-migrate: true
    locations: classpath:db/migration

server:
  port: 8001
  shutdown: graceful

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: always

logging:
  level:
    com.helloddd.inventory: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"

# Application-specific properties
app:
  reservation:
    expiration-minutes: 15
    cleanup-interval-minutes: 5
```

#### Docker-specific Configuration
```yaml
# application-docker.yml
spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/inventory
    username: ${DB_USER:inventory}
    password: ${DB_PASSWORD:inventory}

logging:
  level:
    root: INFO
    com.helloddd.inventory: INFO
```

### Dockerfile
```dockerfile
# Multi-stage build for optimal size
FROM maven:3.9-openjdk-17 AS builder

WORKDIR /app

# Cache dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Build application
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:17-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

# Copy artifact from builder
COPY --from=builder --chown=appuser:appuser /app/target/inventory-service*.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/actuator/health || exit 1

USER appuser

EXPOSE 8001

ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "app.jar"]
```

## Docker Compose Integration

### Update docker-compose.yml
```yaml
# Add to docker-compose.yml
services:
  # ... existing services ...

  inventory-service:
    build: ./inventory-service
    container_name: inventory-service
    environment:
      <<: *common-variables
      SPRING_PROFILES_ACTIVE: docker
      DB_HOST: postgres
      DB_NAME: inventory
      DB_USER: ${DB_USER:-inventory}
      DB_PASSWORD: ${DB_PASSWORD:-inventory}
      JAVA_OPTS: -Xmx512m -Xms256m
    ports:
      - "8001:8001"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - hello-dd-network
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost:8001/actuator/health"]
    restart: unless-stopped
```

## Testing Strategy

### Unit Tests
```java
// test/unit/InventoryServiceTest.java
@ExtendWith(MockitoExtension.class)
class InventoryServiceTest {

    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private InventoryService inventoryService;

    @Test
    void testReserveStock_Success() {
        // Given
        Product product = createTestProduct();
        product.setStockLevel(100);
        product.setReservedStock(10);

        when(productRepository.findById(any())).thenReturn(Optional.of(product));
        when(productRepository.save(any())).thenReturn(product);

        // When
        StockReservation result = inventoryService.reserveStock(
            product.getId(), 20, "ORDER-123"
        );

        // Then
        assertThat(result.isSuccessful()).isTrue();
        assertThat(product.getReservedStock()).isEqualTo(30);
    }
}
```

### Integration Tests with Docker
```java
// test/integration/InventoryIntegrationTest.java
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class InventoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
            .withDatabaseName("inventory")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testCreateAndRetrieveProduct() throws Exception {
        String productJson = """
            {
                "sku": "TEST-001",
                "name": "Test Product",
                "stockLevel": 100,
                "unitCost": 29.99
            }
            """;

        MvcResult result = mockMvc.perform(post("/api/v1/products")
                .contentType(MediaType.APPLICATION_JSON)
                .content(productJson))
                .andExpect(status().isCreated())
                .andReturn();

        String id = JsonPath.read(result.getResponse().getContentAsString(), "$.id");

        mockMvc.perform(get("/api/v1/products/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sku").value("TEST-001"));
    }
}
```

## Local Development and Testing

### Build and Run Locally
```bash
# Build the service
cd inventory-service
mvn clean package

# Run with Docker Compose
cd ..
make build-inventory-service
make restart

# Verify the service is running
curl http://localhost:8001/actuator/health

# Test API endpoints
curl http://localhost:8001/api/v1/products

# Check logs
make logs-inventory-service

# Run tests
cd inventory-service
mvn test
```

### API Testing with curl
```bash
# Create a product
curl -X POST http://localhost:8001/api/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "LAPTOP-002",
    "name": "Dell XPS 15",
    "description": "High-performance laptop",
    "category": "Electronics",
    "stockLevel": 25,
    "unitCost": 1899.99
  }'

# Reserve stock
curl -X POST http://localhost:8001/api/v1/stock/reserve \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "<product-uuid>",
    "quantity": 5,
    "orderId": "ORDER-001"
  }'
```

## Deliverables

1. **Working Inventory Service**
   - Full CRUD operations for products
   - Stock management with reservations
   - Optimistic locking for concurrency
   - Integrated with PostgreSQL

2. **Docker Integration**
   - Service running in Docker Compose
   - Health checks configured
   - Proper networking with database

3. **Testing Suite**
   - Unit tests with 80%+ coverage
   - Integration tests with Testcontainers
   - API documentation with Swagger

4. **Development Tools**
   - Maven build configuration
   - Hot reload with Spring DevTools
   - Database migrations with Flyway

## Success Criteria

- Service builds and starts successfully
- All API endpoints respond correctly
- Database persistence working
- Stock reservation logic prevents overselling
- Concurrent updates handled properly
- Health endpoint returns UP status
- Service integrates with Docker Compose
- Tests pass in CI environment

## Preparation for Phase 3

This phase delivers:
- First working microservice
- Database integration patterns
- Testing methodology
- Docker containerization

Ready for:
- Kubernetes deployment (Phase 3)
- Service mesh integration
- Production deployment patterns