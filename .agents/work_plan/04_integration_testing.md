# Integration Testing Phase

Comprehensive testing across all services to verify distributed system behavior and tracing patterns.

## 1. Multi-Service Integration Tests

### Setup Test Environment
```bash
# Ensure all services are running
docker-compose up -d

# Wait for services to be healthy
./scripts/wait-for-services.sh  # Create helper script if needed

# Check service health endpoints
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health
```

## 2. Test Request Flow Patterns

### Pattern 1: Simple Product Query
Test parallel calls to Inventory and Pricing services:

```bash
# Create test script: test_product_query.sh
#!/bin/bash
PRODUCT_ID=123

echo "Testing Product Query for ID: $PRODUCT_ID"
response=$(curl -s -w "\n%{http_code}" http://localhost:8000/api/v1/products/$PRODUCT_ID)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo "✓ Product query successful"
    echo "Response: $body"

    # Verify response contains data from both services
    echo "$body" | jq '.inventory' > /dev/null && echo "✓ Inventory data present"
    echo "$body" | jq '.pricing' > /dev/null && echo "✓ Pricing data present"
else
    echo "✗ Product query failed with status: $http_code"
    echo "Response: $body"
fi
```

### Pattern 2: Order Checkout Flow
Test sequential service interactions with rollback:

```python
# Create test script: test_checkout_flow.py
import requests
import json
import time

def test_successful_checkout():
    """Test successful order checkout"""
    order_data = {
        "items": [
            {"productId": "123", "quantity": 2},
            {"productId": "456", "quantity": 1}
        ],
        "customerId": "cust-789"
    }

    response = requests.post(
        "http://localhost:8000/api/v1/orders",
        json=order_data
    )

    assert response.status_code == 201
    order = response.json()
    assert "orderId" in order
    assert "total" in order
    print(f"✓ Successful checkout: {order['orderId']}")

def test_checkout_with_insufficient_stock():
    """Test checkout failure due to insufficient stock"""
    order_data = {
        "items": [
            {"productId": "123", "quantity": 9999}
        ],
        "customerId": "cust-789"
    }

    response = requests.post(
        "http://localhost:8000/api/v1/orders",
        json=order_data
    )

    assert response.status_code == 400
    error = response.json()
    assert "error" in error
    print(f"✓ Correctly handled insufficient stock")

if __name__ == "__main__":
    test_successful_checkout()
    test_checkout_with_insufficient_stock()
```

### Pattern 3: Bulk Operations
Test batch processing and aggregation:

```bash
# Create test script: test_bulk_operations.sh
#!/bin/bash

echo "Testing Bulk Product Check"

# Create request with multiple product IDs
cat > /tmp/bulk_request.json <<EOF
{
    "productIds": ["123", "456", "789", "101", "202", "303", "404", "505"]
}
EOF

response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @/tmp/bulk_request.json \
    http://localhost:8000/api/v1/products/bulk-check)

echo "$response" | jq '.results | length' | {
    read count
    if [ "$count" -gt 0 ]; then
        echo "✓ Bulk check returned $count results"
    else
        echo "✗ Bulk check failed"
    fi
}
```

### Pattern 4: Async Processing
Test async job submission and status polling:

```python
# Create test script: test_async_processing.py
import requests
import time

def test_async_report_generation():
    """Test async report generation workflow"""

    # Submit report generation request
    report_request = {
        "reportType": "inventory_summary",
        "startDate": "2024-01-01",
        "endDate": "2024-12-31"
    }

    response = requests.post(
        "http://localhost:8000/api/v1/reports/generate",
        json=report_request
    )

    assert response.status_code == 202
    job = response.json()
    job_id = job["jobId"]
    print(f"Report job submitted: {job_id}")

    # Poll for completion
    max_attempts = 30
    for i in range(max_attempts):
        status_response = requests.get(
            f"http://localhost:8000/api/v1/reports/status/{job_id}"
        )

        status = status_response.json()
        print(f"Status: {status['status']}")

        if status["status"] == "completed":
            print(f"✓ Report generated successfully")
            return status["result"]
        elif status["status"] == "failed":
            print(f"✗ Report generation failed: {status.get('error')}")
            return None

        time.sleep(2)

    print(f"✗ Report generation timed out")
    return None

if __name__ == "__main__":
    test_async_report_generation()
```

## 3. Distributed Tracing Validation

### Correlation ID Tracking
```python
# Create test script: test_correlation_tracking.py
import requests
import uuid

def test_correlation_id_propagation():
    """Verify correlation ID propagates through all services"""

    correlation_id = str(uuid.uuid4())
    headers = {"X-Correlation-Id": correlation_id}

    response = requests.get(
        "http://localhost:8000/api/v1/products/123",
        headers=headers
    )

    # Check if correlation ID is returned
    response_correlation = response.headers.get("X-Correlation-Id")
    assert response_correlation == correlation_id
    print(f"✓ Correlation ID preserved: {correlation_id}")

    # Check service logs for correlation ID
    # This would require log parsing or log aggregation service
    print(f"Check logs for correlation ID: {correlation_id}")

if __name__ == "__main__":
    test_correlation_id_propagation()
```

### Error Propagation Testing
```bash
# Test error propagation through services
curl -X GET http://localhost:8000/api/v1/products/nonexistent -v

# Test service timeout handling
curl -X GET "http://localhost:8000/api/v1/health/cascade?failure_mode=timeout" -v

# Test circuit breaker activation
for i in {1..10}; do
    curl -X GET "http://localhost:8000/api/v1/health/cascade?failure_mode=inventory" &
done
wait
```

## 4. Load and Performance Testing

### Create k6 Load Test Script
```javascript
// scripts/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 10 },   // Ramp up
        { duration: '1m', target: 100 },   // Stay at 100 users
        { duration: '30s', target: 0 },    // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
        http_req_failed: ['rate<0.1'],    // Error rate under 10%
    },
};

export default function() {
    // Test different endpoints
    let responses = http.batch([
        ['GET', 'http://localhost:8000/api/v1/products/123'],
        ['GET', 'http://localhost:8000/api/v1/products/456'],
    ]);

    responses.forEach(response => {
        check(response, {
            'status is 200': (r) => r.status === 200,
            'response time < 500ms': (r) => r.timings.duration < 500,
        });
    });

    sleep(1);
}
```

### Run Load Tests
```bash
# Install k6 if not available
# brew install k6  # macOS
# Or use Docker: docker run -i loadimpact/k6 run - <scripts/load-test.js

# Run load test
k6 run scripts/load-test.js

# Monitor during test
docker-compose logs -f --tail=100
```

## 5. Chaos Testing

### Service Failure Simulation
```bash
# Stop individual services to test resilience
docker-compose stop inventory-service
curl -X GET http://localhost:8000/api/v1/products/123
docker-compose start inventory-service

# Introduce network delays
docker exec -it hello-dd_inventory-service_1 \
    tc qdisc add dev eth0 root netem delay 500ms

# Clear network delays
docker exec -it hello-dd_inventory-service_1 \
    tc qdisc del dev eth0 root
```

## 6. Observability Verification

### Check Metrics
```bash
# If Prometheus metrics endpoints are implemented
curl http://localhost:8000/metrics
curl http://localhost:8001/metrics
curl http://localhost:8002/metrics
```

### Verify Logging
```bash
# Check structured logging
docker-compose logs api-gateway | grep -i error
docker-compose logs inventory-service | grep -i warn
docker-compose logs pricing-service | grep correlation

# Verify log correlation
REQUEST_ID=$(uuidgen)
curl -H "X-Request-Id: $REQUEST_ID" http://localhost:8000/api/v1/products/123
docker-compose logs | grep $REQUEST_ID
```

## 7. Test Report Generation

Create `task_work/test_report.md`:
```markdown
# Integration Test Report

## Test Summary
- Total test cases: XX
- Passed: XX
- Failed: XX
- Skipped: XX

## Request Flow Patterns
- [ ] Simple Product Query
- [ ] Order Checkout Flow
- [ ] Bulk Operations
- [ ] Async Processing
- [ ] Circuit Breaker

## Distributed Tracing
- [ ] Correlation ID propagation
- [ ] Error propagation
- [ ] Timeout handling
- [ ] Retry behavior

## Performance Results
- Average latency: XXms
- P95 latency: XXms
- P99 latency: XXms
- Error rate: XX%
- Throughput: XX req/sec

## Issues Found
1. Issue description and resolution
2. ...

## Recommendations
- Performance improvements
- Resilience enhancements
- Observability gaps
```

## Key Verification Points

- [ ] All request patterns work correctly
- [ ] Services handle failures gracefully
- [ ] Correlation IDs propagate properly
- [ ] Performance meets requirements
- [ ] Error messages are informative
- [ ] Timeouts and retries work as expected
- [ ] Circuit breakers activate appropriately
- [ ] Logs are structured and correlated
- [ ] Metrics are exposed correctly

## Next Steps

If all tests pass:
- Proceed to finalization phase
- Prepare for code review

If issues found:
- Document failures
- Fix issues in implementation
- Re-run failed tests
- Update test report