# Phase 9: Advanced Distributed Patterns

## Overview
Implement advanced distributed system patterns including saga orchestration, event-driven architecture, distributed caching, and chaos engineering. These patterns make the system production-ready and resilient.

## Objectives
- Implement saga pattern for distributed transactions
- Add event-driven communication with message queues
- Implement distributed caching strategies
- Add chaos engineering for resilience testing
- Implement advanced monitoring and alerting

## Saga Pattern Implementation

### Saga Orchestrator Service
```python
# api-gateway/app/services/saga_orchestrator.py
from typing import Dict, Any, List
from enum import Enum
import asyncio
import uuid

class SagaState(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPENSATING = "compensating"
    COMPLETED = "completed"
    FAILED = "failed"

class OrderSaga:
    def __init__(self, inventory_client, pricing_client, payment_client):
        self.inventory_client = inventory_client
        self.pricing_client = pricing_client
        self.payment_client = payment_client
        self.saga_log = []

    async def execute_order(self, order_data: Dict[Any, Any]) -> Dict[Any, Any]:
        saga_id = str(uuid.uuid4())
        compensations = []

        try:
            # Step 1: Validate inventory
            inventory_check = await self._validate_inventory(order_data["items"])
            self.saga_log.append({"step": "validate_inventory", "status": "success"})

            # Step 2: Reserve inventory
            reservations = await self._reserve_inventory(order_data["items"], saga_id)
            compensations.append(("release_inventory", reservations))
            self.saga_log.append({"step": "reserve_inventory", "status": "success"})

            # Step 3: Calculate pricing
            total_price = await self._calculate_total(order_data["items"], order_data.get("discounts"))
            self.saga_log.append({"step": "calculate_price", "status": "success"})

            # Step 4: Process payment
            payment = await self._process_payment(total_price, order_data["payment_method"])
            compensations.append(("refund_payment", payment))
            self.saga_log.append({"step": "process_payment", "status": "success"})

            # Step 5: Confirm order
            order = await self._confirm_order(saga_id, reservations, payment)
            self.saga_log.append({"step": "confirm_order", "status": "success"})

            return {
                "sagaId": saga_id,
                "orderId": order["id"],
                "status": "completed",
                "total": total_price
            }

        except Exception as e:
            # Execute compensating transactions
            await self._compensate(compensations)
            self.saga_log.append({"step": "compensation", "status": "executed"})

            return {
                "sagaId": saga_id,
                "status": "failed",
                "error": str(e),
                "compensations": len(compensations)
            }

    async def _compensate(self, compensations: List[tuple]):
        for action, data in reversed(compensations):
            try:
                if action == "release_inventory":
                    await self.inventory_client.release_reservations(data)
                elif action == "refund_payment":
                    await self.payment_client.refund(data)
            except Exception as e:
                # Log compensation failure for manual intervention
                print(f"Compensation failed: {action} - {e}")
```

## Event-Driven Architecture

### Message Queue Integration (AWS SQS/SNS)
```python
# api-gateway/app/services/event_publisher.py
import boto3
import json
from typing import Dict, Any

class EventPublisher:
    def __init__(self, topic_arn: str):
        self.sns_client = boto3.client('sns')
        self.topic_arn = topic_arn

    async def publish_order_event(self, event_type: str, order_data: Dict[Any, Any]):
        message = {
            "eventType": event_type,
            "timestamp": datetime.utcnow().isoformat(),
            "data": order_data
        }

        self.sns_client.publish(
            TopicArn=self.topic_arn,
            Message=json.dumps(message),
            MessageAttributes={
                'eventType': {
                    'DataType': 'String',
                    'StringValue': event_type
                }
            }
        )

# inventory-service/src/main/java/com/helloddd/inventory/events/EventConsumer.java
@Component
public class EventConsumer {

    @SqsListener("${app.sqs.queue-name}")
    public void processOrderEvent(String message) {
        OrderEvent event = parseMessage(message);

        switch(event.getEventType()) {
            case "ORDER_CREATED":
                handleOrderCreated(event);
                break;
            case "ORDER_CANCELLED":
                handleOrderCancelled(event);
                break;
        }
    }
}
```

## Distributed Caching Strategies

### Cache-Aside Pattern with Redis
```go
// pricing-service/internal/cache/distributed_cache.go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/go-redis/redis/v8"
)

type DistributedCache struct {
    client *redis.Client
    ttl    time.Duration
}

func (dc *DistributedCache) GetOrSet(
    ctx context.Context,
    key string,
    loader func() (interface{}, error),
) (interface{}, error) {
    // Try to get from cache
    val, err := dc.client.Get(ctx, key).Result()
    if err == nil {
        var result interface{}
        json.Unmarshal([]byte(val), &result)
        return result, nil
    }

    // Cache miss - load data
    data, err := loader()
    if err != nil {
        return nil, err
    }

    // Store in cache
    jsonData, _ := json.Marshal(data)
    dc.client.Set(ctx, key, jsonData, dc.ttl)

    // Publish cache invalidation event
    dc.client.Publish(ctx, "cache:invalidation", key)

    return data, nil
}

// Cache invalidation listener
func (dc *DistributedCache) ListenForInvalidation(ctx context.Context) {
    pubsub := dc.client.Subscribe(ctx, "cache:invalidation")
    defer pubsub.Close()

    for msg := range pubsub.Channel() {
        // Invalidate local cache if exists
        dc.invalidateLocal(msg.Payload)
    }
}
```

## Chaos Engineering

### Litmus Chaos Experiments
```yaml
# k8s/chaos/pod-delete-experiment.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: inventory-chaos
  namespace: hello-dd
spec:
  appinfo:
    appns: hello-dd
    applabel: app=inventory-service
    appkind: deployment
  chaosServiceAccount: litmus-admin
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
        - name: TOTAL_CHAOS_DURATION
          value: '60'
        - name: CHAOS_INTERVAL
          value: '10'
        - name: FORCE
          value: 'false'
```

### Fault Injection in Code
```python
# api-gateway/app/core/chaos.py
import random
import asyncio
from functools import wraps

class ChaosMonkey:
    def __init__(self, enabled: bool = False):
        self.enabled = enabled
        self.failure_rate = 0.1  # 10% failure rate
        self.latency_min = 1  # seconds
        self.latency_max = 5  # seconds

    def inject_failure(self, func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            if not self.enabled:
                return await func(*args, **kwargs)

            # Random failure
            if random.random() < self.failure_rate:
                raise Exception("Chaos Monkey: Injected failure")

            # Random latency
            if random.random() < 0.2:  # 20% chance
                delay = random.uniform(self.latency_min, self.latency_max)
                await asyncio.sleep(delay)

            return await func(*args, **kwargs)
        return wrapper

    def inject_network_partition(self, service_name: str):
        if self.enabled and random.random() < 0.05:  # 5% chance
            raise ConnectionError(f"Network partition: Cannot reach {service_name}")
```

## Advanced Monitoring

### Custom Metrics with Prometheus
```python
# api-gateway/app/core/metrics.py
from prometheus_client import Counter, Histogram, Gauge, generate_latest

# Business metrics
order_created_total = Counter(
    'business_orders_created_total',
    'Total number of orders created',
    ['status', 'payment_method']
)

order_value_histogram = Histogram(
    'business_order_value_dollars',
    'Order value distribution',
    buckets=[10, 50, 100, 500, 1000, 5000]
)

inventory_stock_gauge = Gauge(
    'business_inventory_stock_total',
    'Total stock across all products',
    ['category']
)

saga_duration_histogram = Histogram(
    'saga_execution_duration_seconds',
    'Saga execution time',
    ['saga_type', 'status']
)

# Circuit breaker metrics
circuit_breaker_state = Gauge(
    'circuit_breaker_state',
    'Circuit breaker state (0=closed, 1=open, 2=half-open)',
    ['service']
)
```

### Distributed Tracing Enhancements
```java
// inventory-service/src/main/java/com/helloddd/inventory/tracing/TracingAspect.java
@Aspect
@Component
public class TracingAspect {

    @Around("@annotation(Traced)")
    public Object trace(ProceedingJoinPoint joinPoint) throws Throwable {
        Span span = tracer.nextSpan()
            .name(joinPoint.getSignature().getName())
            .start();

        try (Tracer.SpanInScope ws = tracer.withSpanInScope(span)) {
            // Add custom tags
            span.tag("service", "inventory");
            span.tag("operation", joinPoint.getSignature().getName());

            // Add method parameters as tags
            Object[] args = joinPoint.getArgs();
            for (int i = 0; i < args.length; i++) {
                span.tag("param." + i, String.valueOf(args[i]));
            }

            Object result = joinPoint.proceed();

            // Add result info
            span.tag("result.type", result.getClass().getSimpleName());

            return result;
        } catch (Exception e) {
            span.tag("error", e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
}
```

## Rate Limiting and Throttling

### API Gateway Rate Limiter
```python
# api-gateway/app/core/rate_limiter.py
from typing import Dict, Optional
import time
import asyncio

class TokenBucket:
    def __init__(self, rate: int, capacity: int):
        self.rate = rate  # tokens per second
        self.capacity = capacity
        self.tokens = capacity
        self.last_refill = time.time()
        self.lock = asyncio.Lock()

    async def consume(self, tokens: int = 1) -> bool:
        async with self.lock:
            await self._refill()

            if self.tokens >= tokens:
                self.tokens -= tokens
                return True
            return False

    async def _refill(self):
        now = time.time()
        elapsed = now - self.last_refill
        tokens_to_add = elapsed * self.rate

        self.tokens = min(self.capacity, self.tokens + tokens_to_add)
        self.last_refill = now

class RateLimiter:
    def __init__(self):
        self.buckets: Dict[str, TokenBucket] = {}

    async def check_rate_limit(
        self,
        key: str,
        rate: int = 100,
        capacity: int = 100
    ) -> bool:
        if key not in self.buckets:
            self.buckets[key] = TokenBucket(rate, capacity)

        return await self.buckets[key].consume()
```

## Testing Chaos and Resilience

### Chaos Test Suite
```bash
#!/bin/bash
# scripts/chaos-test.sh

echo "Starting Chaos Engineering Tests..."

# 1. Network latency injection
echo "1. Injecting network latency..."
kubectl exec -it deployment/api-gateway -n hello-dd -- \
    tc qdisc add dev eth0 root netem delay 300ms

# Run tests
./scripts/test-full-system.sh

# Remove latency
kubectl exec -it deployment/api-gateway -n hello-dd -- \
    tc qdisc del dev eth0 root

# 2. Pod deletion
echo "2. Testing pod deletion resilience..."
kubectl delete pod -l app=inventory-service -n hello-dd --wait=false

# Run tests while pod is recovering
./scripts/test-full-system.sh

# 3. Resource exhaustion
echo "3. Testing resource limits..."
kubectl run stress --image=progrium/stress -n hello-dd -- \
    --cpu 2 --io 1 --vm 2 --vm-bytes 128M --timeout 60s

# Monitor and test
./scripts/test-full-system.sh

echo "Chaos tests completed!"
```

## Deliverables

1. **Advanced Patterns**
   - Saga orchestration implemented
   - Event-driven architecture working
   - Distributed caching operational
   - Chaos engineering framework

2. **Resilience Features**
   - Circuit breakers enhanced
   - Rate limiting active
   - Fault injection available
   - Compensation logic tested

3. **Monitoring**
   - Custom metrics exposed
   - Distributed tracing enhanced
   - Business KPIs tracked

## Success Criteria

- Sagas handle failures with compensation
- Events published and consumed correctly
- Cache improves performance significantly
- System survives chaos experiments
- Rate limiting prevents overload
- Monitoring provides actionable insights
- Recovery is automatic for most failures

## Preparation for Phase 10

Ready for:
- Full observability integration
- APM deployment
- Production monitoring