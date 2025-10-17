# Phase 5: Pricing Service Kubernetes Deployment

## Overview
Deploy the Pricing Service to the existing Kubernetes cluster alongside the Inventory Service. This phase demonstrates multi-service deployment patterns and service discovery in Kubernetes.

## Objectives
- Deploy Pricing Service to Kubernetes
- Add Redis to the cluster
- Configure service discovery between services
- Test multi-service communication
- Establish patterns for API Gateway deployment

## Kubernetes Manifests

### Redis Deployment
```yaml
# k8s/redis/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: hello-dd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - "--appendonly"
        - "yes"
        - "--maxmemory"
        - "256mb"
        - "--maxmemory-policy"
        - "allkeys-lru"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: hello-dd
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
```

### Pricing Service Deployment
```yaml
# k8s/pricing-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pricing-service
  namespace: hello-dd
  labels:
    app: pricing-service
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pricing-service
  template:
    metadata:
      labels:
        app: pricing-service
        version: v1
    spec:
      containers:
      - name: pricing-service
        image: localhost:5000/pricing-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8002
          name: http
        env:
        - name: PORT
          value: "8002"
        - name: REDIS_HOST
          value: redis
        - name: REDIS_PORT
          value: "6379"
        - name: DD_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: environment
        - name: DD_VERSION
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: version
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
        - name: CACHE_TTL
          value: "300"
        - name: GIN_MODE
          value: release
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8002
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8002
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: pricing-service
  namespace: hello-dd
  labels:
    app: pricing-service
spec:
  type: NodePort
  ports:
  - port: 8002
    targetPort: 8002
    nodePort: 30002
    name: http
  selector:
    app: pricing-service
```

### Horizontal Pod Autoscaler
```yaml
# k8s/pricing-service/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pricing-service-hpa
  namespace: hello-dd
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pricing-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
```

## Service Discovery Testing

### Test Inter-Service Communication
```yaml
# k8s/test/test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: hello-dd
spec:
  containers:
  - name: test
    image: curlimages/curl:latest
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done"]
```

### Test Commands
```bash
# Deploy test pod
kubectl apply -f k8s/test/test-pod.yaml

# Test service discovery
kubectl exec -it test-pod -n hello-dd -- sh

# Inside the pod:
# Test Inventory Service
curl http://inventory-service:8001/health
curl http://inventory-service:8001/api/v1/products

# Test Pricing Service
curl http://pricing-service:8002/health
curl http://pricing-service:8002/api/v1/prices/TEST-001

# Test Redis
nc -zv redis 6379
```

## Deployment Script

```bash
#!/bin/bash
# scripts/deploy-pricing.sh

set -e

echo "Building Pricing Service..."
cd pricing-service
go build -o bin/pricing-service cmd/server/main.go

echo "Building Docker image..."
docker build -t pricing-service:latest .

echo "Tagging for local registry..."
docker tag pricing-service:latest localhost:5000/pricing-service:latest

echo "Pushing to local registry..."
docker push localhost:5000/pricing-service:latest

echo "Deploying Redis to Kubernetes..."
kubectl apply -f ../k8s/redis/

echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n hello-dd --timeout=60s

echo "Deploying Pricing Service to Kubernetes..."
kubectl apply -f ../k8s/pricing-service/

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available \
  --timeout=120s \
  deployment/pricing-service \
  -n hello-dd

echo "Creating HPA..."
kubectl apply -f ../k8s/pricing-service/hpa.yaml

echo "Deployment complete!"
kubectl get pods -n hello-dd
kubectl get svc -n hello-dd
```

## Load Testing

### K6 Load Test Script
```javascript
// scripts/load-test-pricing.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 20 },   // Ramp up
    { duration: '3m', target: 20 },   // Stay at 20 users
    { duration: '1m', target: 100 },  // Spike to 100 users
    { duration: '3m', target: 100 },  // Stay at 100 users
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Error rate under 10%
  },
};

const BASE_URL = 'http://localhost:30002';

export default function() {
  // Test different endpoints
  let responses = http.batch([
    ['GET', `${BASE_URL}/health`],
    ['GET', `${BASE_URL}/api/v1/prices/LAPTOP-001`],
    ['POST', `${BASE_URL}/api/v1/prices/calculate`, JSON.stringify({
      productId: 'LAPTOP-001',
      quantity: Math.floor(Math.random() * 10) + 1,
    }), { headers: { 'Content-Type': 'application/json' }}],
  ]);

  // Check responses
  responses.forEach(response => {
    check(response, {
      'status is 200': (r) => r.status === 200,
      'response time < 500ms': (r) => r.timings.duration < 500,
    });
  });

  sleep(1);
}
```

### Run Load Test
```bash
# Install k6
brew install k6  # macOS
# or download from https://k6.io

# Run load test
k6 run scripts/load-test-pricing.js

# Watch HPA during load test
watch kubectl get hpa -n hello-dd

# Monitor pods
watch kubectl get pods -n hello-dd -l app=pricing-service
```

## Monitoring Setup

### Prometheus ServiceMonitor (Optional)
```yaml
# k8s/monitoring/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: pricing-service
  namespace: hello-dd
spec:
  selector:
    matchLabels:
      app: pricing-service
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

## Testing Multi-Service System

### End-to-End Test Script
```bash
#!/bin/bash
# scripts/test-multi-service.sh

echo "Testing Multi-Service Communication..."

# Test Inventory Service
echo "1. Testing Inventory Service..."
PRODUCT=$(curl -s -X POST http://localhost:30001/api/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "K8S-TEST-001",
    "name": "Test Product",
    "stockLevel": 100,
    "unitCost": 49.99
  }')

PRODUCT_ID=$(echo $PRODUCT | jq -r '.id')
echo "Created product: $PRODUCT_ID"

# Test Pricing Service
echo "2. Testing Pricing Service..."
curl -X GET http://localhost:30002/api/v1/prices/$PRODUCT_ID

# Test Cache Hit
echo "3. Testing Cache (should be faster)..."
time curl -X GET http://localhost:30002/api/v1/prices/$PRODUCT_ID

echo "Multi-service tests completed!"
```

## Troubleshooting

### Common Issues and Solutions

1. **Redis Connection Issues**
```bash
# Check Redis pod
kubectl describe pod -l app=redis -n hello-dd

# Test Redis connectivity
kubectl run redis-test --image=redis:alpine -it --rm --restart=Never -- redis-cli -h redis ping
```

2. **Service Discovery Not Working**
```bash
# Check service endpoints
kubectl get endpoints -n hello-dd

# DNS resolution test
kubectl run dns-test --image=busybox:1.28 -it --rm --restart=Never -- nslookup pricing-service.hello-dd.svc.cluster.local
```

3. **HPA Not Scaling**
```bash
# Check metrics server
kubectl top pods -n hello-dd

# Check HPA status
kubectl describe hpa pricing-service-hpa -n hello-dd
```

## Deliverables

1. **Multi-Service Kubernetes Deployment**
   - Pricing Service running with 3 replicas
   - Redis deployed and accessible
   - Service discovery working
   - HPA configured and tested

2. **Load Testing**
   - K6 scripts created
   - Performance baselines established
   - Auto-scaling validated

3. **Inter-Service Communication**
   - Services can discover each other
   - Cache integration working
   - Network policies (if needed)

4. **Operational Readiness**
   - Health checks passing
   - Logs accessible
   - Metrics available
   - Scaling tested

## Success Criteria

- Pricing Service pods healthy
- Redis cache operational
- Service discovery working via DNS
- HPA scales based on load
- Load tests pass thresholds
- No errors in cross-service communication
- Cache hit rate improving performance
- Rolling updates work without downtime

## Foundation for Next Phases

This phase establishes:
- Multi-service Kubernetes patterns
- Service discovery and networking
- Horizontal scaling strategies
- Cache integration in Kubernetes

Ready for:
- Phase 6: API Gateway implementation
- Phase 7: Full system integration
- Advanced networking patterns
- Service mesh considerations