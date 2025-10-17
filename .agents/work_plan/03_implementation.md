# Implementation Phase

Execute the implementation plan with iterative development, testing, and validation across all services.

## 1. Pre-Implementation Setup

- Review the implementation plan from `task_work/task_plan.md`
- Ensure all services are running in development mode
- Set up service logs monitoring in separate terminals:
  ```bash
  # Terminal 1: API Gateway logs
  docker-compose logs -f api-gateway

  # Terminal 2: Inventory Service logs
  docker-compose logs -f inventory-service

  # Terminal 3: Pricing Service logs
  docker-compose logs -f pricing-service
  ```

## 2. Service-by-Service Implementation

Follow the dependency order from your plan. For each service:

### A. Implement Core Functionality

#### Python (API Gateway)
- Start with request handlers
- Implement service client methods
- Add request/response transformations
- Include correlation ID generation/propagation
- Add comprehensive error handling

#### Java (Inventory Service)
- Create/modify controllers
- Implement service layer logic
- Update repository/DAO layers
- Add DTOs and mappers
- Implement transactional boundaries

#### Go (Pricing Service)
- Define handlers
- Implement business logic
- Add middleware for cross-cutting concerns
- Implement caching logic if needed
- Add proper context propagation

### B. Immediate Validation

After each component:
- Run service-specific tests
- Check for compilation/runtime errors
- Verify logs show expected behavior
- Test with curl or HTTP client

### C. Inter-Service Communication

For each service interaction:
1. **Implement client code**
   - HTTP client configuration
   - Request building
   - Response parsing
   - Error handling

2. **Add resilience patterns**
   - Timeouts
   - Retries with exponential backoff
   - Circuit breakers (if applicable)
   - Fallback responses

3. **Trace context propagation**
   - Add correlation ID headers
   - Propagate W3C Trace Context headers
   - Log correlation IDs for debugging

### D. Write Tests Immediately

#### Unit Tests
```python
# Python example
def test_endpoint_handler():
    # Test happy path
    # Test error cases
    # Test validation
```

```java
// Java example
@Test
public void testServiceMethod() {
    // Given
    // When
    // Then
}
```

```go
// Go example
func TestHandler(t *testing.T) {
    // Arrange
    // Act
    // Assert
}
```

#### Integration Tests
- Test actual HTTP calls between services
- Verify database state changes
- Check cache behavior
- Validate error propagation

## 3. Progressive Testing & Commits

### After Each Logical Unit

1. **Run Tests**
   ```bash
   # Python
   cd api-gateway && python -m pytest tests/ -v

   # Java
   cd inventory-service && ./mvnw test

   # Go
   cd pricing-service && go test ./... -v
   ```

2. **Manual Testing**
   ```bash
   # Test individual endpoints
   curl -X GET http://localhost:8000/api/v1/health

   # Test service interactions
   curl -X POST http://localhost:8000/api/v1/products \
     -H "Content-Type: application/json" \
     -d '{"name": "Test Product"}'
   ```

3. **Commit Progress**
   ```bash
   git add .
   git commit -m "feat(service): implement feature X for service Y"
   ```

## 4. End-to-End Flow Testing

### Test Complete Request Flows

1. **Simple Flow Test**
   ```bash
   # Test Product Query (Pattern 1)
   curl -X GET http://localhost:8000/api/v1/products/123
   ```

2. **Complex Flow Test**
   ```bash
   # Test Order Checkout (Pattern 2)
   curl -X POST http://localhost:8000/api/v1/orders \
     -H "Content-Type: application/json" \
     -d '{"items": [{"productId": "123", "quantity": 2}]}'
   ```

3. **Error Flow Test**
   ```bash
   # Test error propagation
   curl -X GET http://localhost:8000/api/v1/products/invalid
   ```

### Verify Distributed Behavior

- Check logs across all services for single request
- Verify correlation IDs match across services
- Confirm error messages propagate correctly
- Test timeout and retry behavior

## 5. Performance Validation

### Basic Load Testing
```bash
# Using curl in a loop
for i in {1..100}; do
  curl -X GET http://localhost:8000/api/v1/products/$i &
done
wait

# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8000/api/v1/products/123

# Using k6 if available
k6 run scripts/load-test.js
```

### Monitor During Load
- Service response times
- Memory usage
- CPU utilization
- Error rates
- Database connection pool stats

## 6. Docker Environment Testing

### Rebuild and Test
```bash
# Rebuild affected services
docker-compose build api-gateway inventory-service pricing-service

# Restart services
docker-compose down
docker-compose up -d

# Run smoke tests
./scripts/smoke-test.sh  # Create if doesn't exist
```

### Verify Inter-Container Communication
- Services can reach each other
- Database connections work
- Environment variables are set correctly
- Volumes are mounted properly

## 7. Implementation Checklist

For each feature/change:
- [ ] Core functionality implemented
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] Service communication works
- [ ] Error handling tested
- [ ] Trace context propagates
- [ ] Performance acceptable
- [ ] Docker environment works
- [ ] Documentation updated
- [ ] Code committed

## Common Issues and Solutions

### Service Communication Failures
- Check service discovery/URLs
- Verify network connectivity
- Check for port conflicts
- Review timeout settings

### Trace Context Loss
- Ensure headers are propagated
- Check middleware ordering
- Verify context extraction/injection

### Performance Problems
- Profile code for bottlenecks
- Check database query efficiency
- Review service call parallelization
- Consider caching strategies

## Key Requirements

- Never skip testing steps
- Fix issues immediately when discovered
- Maintain working state after each commit
- Keep distributed tracing in mind
- Document any deviations from plan