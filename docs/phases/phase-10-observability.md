# Phase 10: Observability and APM Integration

## Overview
Integrate Datadog for comprehensive observability including APM, distributed tracing, metrics, and logs. This phase tests automatic instrumentation, compares with manual instrumentation, and validates OpenTelemetry compatibility.

## Objectives
- Deploy Datadog Agent in Kubernetes/EKS
- Test Single Step APM automatic instrumentation
- Compare automatic vs manual SDK instrumentation
- Validate OpenTelemetry integration
- Create dashboards and monitors
- Implement SLOs and alerting

## Datadog Agent Deployment

### Kubernetes DaemonSet
```yaml
# k8s/datadog/datadog-agent.yaml
apiVersion: v1
kind: Secret
metadata:
  name: datadog-secret
  namespace: hello-dd
type: Opaque
data:
  api-key: <base64-api-key>
  app-key: <base64-app-key>

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: datadog-agent
  namespace: hello-dd
spec:
  selector:
    matchLabels:
      app: datadog-agent
  template:
    metadata:
      labels:
        app: datadog-agent
    spec:
      serviceAccountName: datadog-agent
      containers:
      - name: datadog-agent
        image: gcr.io/datadoghq/agent:latest
        env:
        - name: DD_API_KEY
          valueFrom:
            secretKeyRef:
              name: datadog-secret
              key: api-key
        - name: DD_SITE
          value: "datadoghq.com"
        - name: DD_KUBERNETES_KUBELET_HOST
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: DD_ENV
          value: "production"
        - name: DD_APM_ENABLED
          value: "true"
        - name: DD_APM_NON_LOCAL_TRAFFIC
          value: "true"
        - name: DD_LOGS_ENABLED
          value: "true"
        - name: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL
          value: "true"
        - name: DD_PROCESS_AGENT_ENABLED
          value: "true"
        - name: DD_DOGSTATSD_NON_LOCAL_TRAFFIC
          value: "true"
        ports:
        - containerPort: 8125
          name: dogstatsd
          protocol: UDP
        - containerPort: 8126
          name: apm
          protocol: TCP
        volumeMounts:
        - name: dockersocket
          mountPath: /var/run/docker.sock
        - name: logpath
          mountPath: /var/log/pods
          readOnly: true
      volumes:
      - name: dockersocket
        hostPath:
          path: /var/run/docker.sock
      - name: logpath
        hostPath:
          path: /var/log/pods
```

## Single Step APM Testing

### Automatic Instrumentation with Admission Controller
```yaml
# k8s/datadog/admission-controller.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datadog-admission-controller
  namespace: hello-dd
data:
  auto-instrumentation: |
    {
      "java": {
        "image": "gcr.io/datadoghq/dd-lib-java-init:latest",
        "env": {
          "DD_PROFILING_ENABLED": "true",
          "DD_LOGS_INJECTION": "true",
          "DD_RUNTIME_METRICS_ENABLED": "true"
        }
      },
      "python": {
        "image": "gcr.io/datadoghq/dd-lib-python-init:latest",
        "env": {
          "DD_LOGS_INJECTION": "true",
          "DD_PROFILING_ENABLED": "true"
        }
      },
      "nodejs": {
        "image": "gcr.io/datadoghq/dd-lib-js-init:latest",
        "env": {
          "DD_LOGS_INJECTION": "true"
        }
      }
    }
```

### Service Annotations for Auto-Instrumentation
```yaml
# k8s/inventory-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: hello-dd
spec:
  template:
    metadata:
      labels:
        tags.datadoghq.com/env: "production"
        tags.datadoghq.com/service: "inventory-service"
        tags.datadoghq.com/version: "1.0.0"
      annotations:
        admission.datadoghq.com/enabled: "true"
        admission.datadoghq.com/java-lib.version: "latest"
```

## Manual Instrumentation Comparison

### Java Manual Instrumentation
```java
// inventory-service - Manual instrumentation
import datadog.trace.api.Trace;
import datadog.trace.api.DDTags;
import io.opentracing.Span;
import io.opentracing.util.GlobalTracer;

@RestController
public class ProductController {

    @Trace(operationName = "inventory.get_product", resourceName = "GET /products/{id}")
    @GetMapping("/api/v1/products/{id}")
    public ProductResponse getProduct(@PathVariable String id) {
        Span span = GlobalTracer.get().activeSpan();
        if (span != null) {
            span.setTag("product.id", id);
            span.setTag(DDTags.SERVICE_NAME, "inventory-service");
            span.setTag("business.team", "inventory-team");
        }

        try {
            Product product = productService.findById(id);
            if (span != null) {
                span.setTag("product.found", true);
                span.setTag("product.stock_level", product.getStockLevel());
            }
            return ProductResponse.from(product);
        } catch (NotFoundException e) {
            if (span != null) {
                span.setTag("product.found", false);
                span.setTag(DDTags.ERROR_MSG, e.getMessage());
            }
            throw e;
        }
    }
}
```

### Python Manual Instrumentation
```python
# api-gateway - Manual instrumentation
from ddtrace import tracer, patch_all
from ddtrace.contrib.fastapi import patch as fastapi_patch

# Auto-patch supported libraries
patch_all()
fastapi_patch()

@app.get("/api/v1/products/{product_id}")
async def get_product_with_price(product_id: str):
    with tracer.trace("gateway.aggregate_product") as span:
        span.set_tag("product.id", product_id)
        span.set_tag("aggregation.type", "parallel")

        # Trace inventory call
        with tracer.trace("gateway.call_inventory") as inv_span:
            inv_span.set_tag("target.service", "inventory-service")
            inventory_data = await inventory_client.get_product(product_id)

        # Trace pricing call
        with tracer.trace("gateway.call_pricing") as price_span:
            price_span.set_tag("target.service", "pricing-service")
            pricing_data = await pricing_client.get_price(product_id)

        # Business metrics
        span.set_metric("product.price", pricing_data.get("price", 0))
        span.set_tag("product.available", inventory_data.get("stockLevel", 0) > 0)

        return aggregate_response(inventory_data, pricing_data)
```

### Go Manual Instrumentation
```go
// pricing-service - Manual instrumentation
import (
    "gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"
    "gopkg.in/DataDog/dd-trace-go.v1/contrib/gin-gonic/gin"
)

func main() {
    tracer.Start(
        tracer.WithService("pricing-service"),
        tracer.WithEnv("production"),
        tracer.WithServiceVersion("1.0.0"),
        tracer.WithProfilerEnabled(true),
    )
    defer tracer.Stop()

    r := gin.New()
    r.Use(gintrace.Middleware("pricing-service"))

    r.GET("/api/v1/prices/:id", getPriceHandler)
}

func getPriceHandler(c *gin.Context) {
    span, ctx := tracer.StartSpanFromContext(
        c.Request.Context(),
        "pricing.calculate",
        tracer.ResourceName("GET /prices/{id}"),
    )
    defer span.Finish()

    productID := c.Param("id")
    span.SetTag("product.id", productID)

    // Check cache
    cacheSpan := tracer.StartSpan("cache.get", tracer.ChildOf(span.Context()))
    price, found := cache.Get(ctx, productID)
    cacheSpan.SetTag("cache.hit", found)
    cacheSpan.Finish()

    if !found {
        // Calculate price
        calcSpan := tracer.StartSpan("price.calculate", tracer.ChildOf(span.Context()))
        price = calculateDynamicPrice(productID)
        calcSpan.SetMetric("calculated.price", price)
        calcSpan.Finish()

        // Update cache
        cache.Set(ctx, productID, price)
    }

    span.SetMetric("final.price", price)
    c.JSON(200, gin.H{"price": price})
}
```

## OpenTelemetry Integration

### OTLP Collector Configuration
```yaml
# k8s/otel/otel-collector.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: hello-dd
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch:
        timeout: 10s
      resource:
        attributes:
        - key: deployment.environment
          value: production
          action: upsert

    exporters:
      datadog:
        api:
          site: datadoghq.com
          key: ${DD_API_KEY}
        metrics:
          resource_attributes_as_tags: true
        traces:
          span_name_as_resource_name: true

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [datadog]
        metrics:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [datadog]
```

## Custom Business Metrics

### StatsD Metrics
```python
# api-gateway/app/core/business_metrics.py
from datadog import initialize, statsd

initialize(
    statsd_host="datadog-agent",
    statsd_port=8125
)

class BusinessMetrics:
    @staticmethod
    def record_order(order_data):
        # Revenue metrics
        statsd.histogram(
            'business.order.value',
            order_data['total'],
            tags=[
                f"payment_method:{order_data['payment_method']}",
                f"customer_segment:{order_data['customer_segment']}"
            ]
        )

        # Order count
        statsd.increment(
            'business.orders.created',
            tags=[f"status:{order_data['status']}"]
        )

        # Items per order
        statsd.histogram(
            'business.order.items_count',
            len(order_data['items'])
        )

    @staticmethod
    def record_inventory_operation(operation, product_id, quantity):
        statsd.increment(
            f'business.inventory.{operation}',
            tags=[f"product:{product_id}"]
        )

        statsd.gauge(
            'business.inventory.movement',
            quantity,
            tags=[
                f"operation:{operation}",
                f"product:{product_id}"
            ]
        )
```

## Log Aggregation and Correlation

### Structured Logging with Trace Correlation
```python
# Python service logging
import logging
import json
from ddtrace import tracer

class DatadogJSONFormatter(logging.Formatter):
    def format(self, record):
        span = tracer.current_span()

        log_record = {
            "timestamp": record.created,
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "dd.trace_id": span.trace_id if span else 0,
            "dd.span_id": span.span_id if span else 0,
            "dd.service": "api-gateway",
            "dd.env": "production",
            "dd.version": "1.0.0"
        }

        if record.exc_info:
            log_record["error.stack"] = self.formatException(record.exc_info)

        return json.dumps(log_record)
```

## Dashboards and Monitors

### Service Dashboard JSON
```json
{
  "title": "Hello-DD Production Dashboard",
  "widgets": [
    {
      "definition": {
        "type": "servicemap",
        "title": "Service Dependencies",
        "filters": ["env:production"]
      }
    },
    {
      "definition": {
        "type": "timeseries",
        "title": "Request Rate",
        "requests": [
          {
            "q": "sum:trace.servlet.request.hits{env:production} by {service}.as_rate()",
            "display_type": "line"
          }
        ]
      }
    },
    {
      "definition": {
        "type": "timeseries",
        "title": "P95 Latency",
        "requests": [
          {
            "q": "p95:trace.servlet.request{env:production} by {service}",
            "display_type": "line"
          }
        ]
      }
    },
    {
      "definition": {
        "type": "timeseries",
        "title": "Error Rate",
        "requests": [
          {
            "q": "sum:trace.servlet.request.errors{env:production} by {service}.as_rate()",
            "display_type": "bars"
          }
        ]
      }
    }
  ]
}
```

### SLO Configuration
```yaml
# datadog/slos.yaml
slos:
  - name: "API Gateway Availability"
    type: metric
    description: "99.9% availability for API Gateway"
    thresholds:
      - timeframe: 7d
        target: 99.9
    query:
      numerator: sum:trace.servlet.request.hits{service:api-gateway,!status:error}
      denominator: sum:trace.servlet.request.hits{service:api-gateway}

  - name: "Order Processing Latency"
    type: metric
    description: "95% of orders processed under 2 seconds"
    thresholds:
      - timeframe: 30d
        target: 95
    query:
      numerator: count:trace.servlet.request{service:api-gateway,resource:POST_/orders,duration:<2000}
      denominator: count:trace.servlet.request{service:api-gateway,resource:POST_/orders}
```

## Monitors and Alerts

### Monitor Configurations
```python
# scripts/create-monitors.py
from datadog import initialize, api

monitors = [
    {
        "name": "High Error Rate on API Gateway",
        "type": "metric alert",
        "query": "avg(last_5m):sum:trace.servlet.request.errors{service:api-gateway} by {env}.as_rate() > 0.05",
        "message": "Error rate is above 5% on API Gateway @pagerduty",
        "thresholds": {
            "critical": 0.05,
            "warning": 0.02
        }
    },
    {
        "name": "Database Connection Pool Exhausted",
        "type": "metric alert",
        "query": "avg(last_5m):avg:jvm.jdbc.connections.active{service:inventory-service} / avg:jvm.jdbc.connections.max{service:inventory-service} > 0.9",
        "message": "Database connection pool is above 90% utilized"
    },
    {
        "name": "Saga Compensation Rate High",
        "type": "metric alert",
        "query": "avg(last_10m):sum:custom.saga.compensations{*} by {saga_type}.as_rate() > 0.1",
        "message": "Saga compensation rate above 10%"
    }
]

for monitor in monitors:
    api.Monitor.create(**monitor)
```

## Testing Instrumentation Coverage

### Validation Script
```bash
#!/bin/bash
# scripts/validate-instrumentation.sh

echo "Validating Datadog Instrumentation..."

# 1. Check agent status
kubectl exec -it daemonset/datadog-agent -n hello-dd -- agent status

# 2. Verify APM traces
echo "Checking APM traces..."
curl -X GET "https://api.datadoghq.com/api/v1/traces" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}"

# 3. Test trace continuity
TRACE_ID=$(curl -s http://api.hello-dd.local/api/v1/products/TEST-001 \
  -H "X-Datadog-Trace-Id: 12345" | grep -o 'trace_id=[0-9]*' | cut -d= -f2)

echo "Trace ID: $TRACE_ID"

# 4. Verify service map
echo "Services discovered:"
curl -X GET "https://api.datadoghq.com/api/v1/service_map" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" | jq '.services[].service_name'

echo "Instrumentation validation complete!"
```

## Performance Impact Analysis

### Benchmark Script
```bash
#!/bin/bash
# scripts/benchmark-instrumentation.sh

echo "Benchmarking instrumentation overhead..."

# Baseline without instrumentation
kubectl set env deployment/api-gateway DD_TRACE_ENABLED=false -n hello-dd
sleep 30
ab -n 10000 -c 100 http://api.hello-dd.local/health > baseline.txt

# With automatic instrumentation
kubectl set env deployment/api-gateway DD_TRACE_ENABLED=true -n hello-dd
sleep 30
ab -n 10000 -c 100 http://api.hello-dd.local/health > auto-instrumentation.txt

# Compare results
echo "Baseline:"
grep "Requests per second" baseline.txt
grep "Time per request" baseline.txt

echo "With Auto-Instrumentation:"
grep "Requests per second" auto-instrumentation.txt
grep "Time per request" auto-instrumentation.txt
```

## Deliverables

1. **Datadog Integration**
   - Agent deployed and running
   - APM traces flowing
   - Logs aggregated with correlation
   - Custom metrics tracked
   - Dashboards created

2. **Instrumentation Analysis**
   - Coverage report for automatic instrumentation
   - Performance impact measured
   - Gap analysis documented
   - Best practices identified

3. **Monitoring Setup**
   - SLOs configured
   - Alerts configured
   - Dashboards created
   - Runbooks documented

## Success Criteria

- All services visible in service map
- Distributed traces showing complete flow
- Automatic instrumentation working without code changes
- Logs correlated with trace IDs
- Custom business metrics tracked
- Performance overhead < 5%
- SLOs and monitors active
- OpenTelemetry compatibility verified

## Key Findings to Document

- Automatic vs manual instrumentation coverage comparison
- Performance impact analysis
- Language-specific instrumentation gaps
- OpenTelemetry vs native Datadog comparison
- Production best practices
- Cost optimization strategies