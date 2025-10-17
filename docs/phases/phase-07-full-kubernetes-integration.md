# Phase 7: Full System Kubernetes Integration

## Overview
Deploy the complete three-service system to Kubernetes with API Gateway as the entry point. This phase integrates all services, adds Ingress routing, and implements production-ready features like HPA and optional service mesh.

## Objectives
- Deploy API Gateway to Kubernetes
- Configure Ingress for external access
- Implement full service discovery
- Add Horizontal Pod Autoscaling for all services
- Optional: Add Istio service mesh
- Validate complete system operation

## API Gateway Kubernetes Deployment

### API Gateway Deployment
```yaml
# k8s/api-gateway/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: hello-dd
  labels:
    app: api-gateway
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
        version: v1
    spec:
      containers:
      - name: api-gateway
        image: localhost:5000/api-gateway:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: INVENTORY_SERVICE_URL
          value: "http://inventory-service:8001"
        - name: PRICING_SERVICE_URL
          value: "http://pricing-service:8002"
        - name: SERVICE_TIMEOUT
          value: "30"
        - name: CIRCUIT_BREAKER_THRESHOLD
          value: "5"
        - name: CIRCUIT_BREAKER_TIMEOUT
          value: "60"
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
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: hello-dd
  labels:
    app: api-gateway
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    name: http
  selector:
    app: api-gateway
```

### Horizontal Pod Autoscalers
```yaml
# k8s/hpa/api-gateway-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: hello-dd
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
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
---
# k8s/hpa/inventory-service-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: inventory-service-hpa
  namespace: hello-dd
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: inventory-service
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Ingress Configuration

### NGINX Ingress
```yaml
# k8s/ingress/nginx-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-dd-ingress
  namespace: hello-dd
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
spec:
  ingressClassName: nginx
  rules:
  - host: api.hello-dd.local
    http:
      paths:
      - path: /()(.*)
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8000
  - host: inventory.hello-dd.local
    http:
      paths:
      - path: /()(.*)
        pathType: Prefix
        backend:
          service:
            name: inventory-service
            port:
              number: 8001
  - host: pricing.hello-dd.local
    http:
      paths:
      - path: /()(.*)
        pathType: Prefix
        backend:
          service:
            name: pricing-service
            port:
              number: 8002
```

## Service Mesh (Optional - Istio)

### Install Istio
```bash
#!/bin/bash
# scripts/install-istio.sh

# Download and install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile
istioctl install --set profile=demo -y

# Enable sidecar injection for namespace
kubectl label namespace hello-dd istio-injection=enabled

# Restart all deployments to inject sidecars
kubectl rollout restart deployment -n hello-dd
```

### Istio Traffic Management
```yaml
# k8s/istio/virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: hello-dd
spec:
  hosts:
  - api-gateway
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: api-gateway
        subset: canary
      weight: 100
  - route:
    - destination:
        host: api-gateway
        subset: stable
      weight: 90
    - destination:
        host: api-gateway
        subset: canary
      weight: 10

---
# k8s/istio/destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-gateway-dr
  namespace: hello-dd
spec:
  host: api-gateway
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: ROUND_ROBIN
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: stable
    labels:
      version: v1
  - name: canary
    labels:
      version: v2
```

### Istio Observability
```yaml
# k8s/istio/telemetry.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: hello-dd-metrics
  namespace: hello-dd
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: ALL_METRICS
      tagOverrides:
        destination_service_name:
          value: destination.workload.name | "unknown"
        request_protocol:
          value: request.protocol | "unknown"
```

## Network Policies

```yaml
# k8s/network-policies/api-gateway-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-gateway-policy
  namespace: hello-dd
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: inventory-service
    ports:
    - protocol: TCP
      port: 8001
  - to:
    - podSelector:
        matchLabels:
          app: pricing-service
    ports:
    - protocol: TCP
      port: 8002
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

## Deployment Script

```bash
#!/bin/bash
# scripts/deploy-full-system.sh

set -e

echo "Building and pushing all services..."

# Build and push API Gateway
cd api-gateway
docker build -t api-gateway:latest .
docker tag api-gateway:latest localhost:5000/api-gateway:latest
docker push localhost:5000/api-gateway:latest
cd ..

# Build and push Inventory Service
cd inventory-service
mvn clean package -DskipTests
docker build -t inventory-service:latest .
docker tag inventory-service:latest localhost:5000/inventory-service:latest
docker push localhost:5000/inventory-service:latest
cd ..

# Build and push Pricing Service
cd pricing-service
docker build -t pricing-service:latest .
docker tag pricing-service:latest localhost:5000/pricing-service:latest
docker push localhost:5000/pricing-service:latest
cd ..

echo "Deploying to Kubernetes..."

# Apply all configurations
kubectl apply -f k8s/config/
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/inventory-service/
kubectl apply -f k8s/pricing-service/
kubectl apply -f k8s/api-gateway/
kubectl apply -f k8s/hpa/
kubectl apply -f k8s/ingress/

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment --all -n hello-dd

echo "System deployed successfully!"
kubectl get all -n hello-dd
```

## Testing Complete System

### End-to-End Test Suite
```bash
#!/bin/bash
# scripts/test-full-system.sh

set -e

API_URL="http://api.hello-dd.local"

echo "Testing Full System Integration..."

# 1. Health checks
echo "1. Health Checks..."
curl -f $API_URL/health || exit 1
curl -f http://inventory.hello-dd.local/health || exit 1
curl -f http://pricing.hello-dd.local/health || exit 1

# 2. Create a product
echo "2. Creating product..."
PRODUCT=$(curl -s -X POST $API_URL/api/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "FULL-TEST-001",
    "name": "Full System Test Product",
    "stockLevel": 100,
    "unitCost": 99.99
  }')

PRODUCT_ID=$(echo $PRODUCT | jq -r '.id')
echo "Created product: $PRODUCT_ID"

# 3. Get product with price (aggregation)
echo "3. Getting product with price..."
curl -s $API_URL/api/v1/products/$PRODUCT_ID | jq .

# 4. Create order (orchestration)
echo "4. Creating order..."
ORDER=$(curl -s -X POST $API_URL/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"productId": "'$PRODUCT_ID'", "quantity": 2}
    ],
    "discountCodes": ["TEST10"]
  }')

echo "Order created: $(echo $ORDER | jq .)"

# 5. Bulk check
echo "5. Bulk product check..."
curl -s -X POST $API_URL/api/v1/products/bulk-check \
  -H "Content-Type: application/json" \
  -d '{
    "productIds": ["'$PRODUCT_ID'", "TEST-002", "TEST-003"]
  }' | jq .

echo "All tests passed!"
```

### Load Testing with K6
```javascript
// scripts/k6-full-system.js
import http from 'k6/http';
import { check, group } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up
    { duration: '5m', target: 50 },   // Steady state
    { duration: '2m', target: 100 },  // Spike
    { duration: '5m', target: 100 },  // High load
    { duration: '2m', target: 0 },    // Ramp down
  ],
};

const BASE_URL = 'http://api.hello-dd.local';

export default function() {
  group('API Gateway Tests', function() {
    // Test product aggregation
    let res1 = http.get(`${BASE_URL}/api/v1/products/TEST-001`);
    check(res1, {
      'product fetch status 200': (r) => r.status === 200,
      'has price field': (r) => JSON.parse(r.body).price !== undefined,
    });

    // Test order creation
    let orderPayload = JSON.stringify({
      items: [
        { productId: 'TEST-001', quantity: 1 },
      ],
    });

    let res2 = http.post(`${BASE_URL}/api/v1/orders`, orderPayload, {
      headers: { 'Content-Type': 'application/json' },
    });

    check(res2, {
      'order creation status 200/201': (r) => [200, 201].includes(r.status),
      'has orderId': (r) => JSON.parse(r.body).orderId !== undefined,
    });
  });
}
```

## Monitoring Dashboard

### Kubernetes Dashboard Access
```bash
# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create service account and get token
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
kubectl -n kubernetes-dashboard create token dashboard-admin

# Proxy to access dashboard
kubectl proxy
# Access at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Custom Monitoring Script
```bash
#!/bin/bash
# scripts/monitor-system.sh

while true; do
  clear
  echo "=== Hello-DD System Status ==="
  echo
  echo "Pods:"
  kubectl get pods -n hello-dd -o wide
  echo
  echo "Services:"
  kubectl get svc -n hello-dd
  echo
  echo "HPA Status:"
  kubectl get hpa -n hello-dd
  echo
  echo "Ingress:"
  kubectl get ingress -n hello-dd
  echo
  echo "Recent Events:"
  kubectl get events -n hello-dd --sort-by='.lastTimestamp' | tail -5
  sleep 10
done
```

## Troubleshooting

### Common Issues
1. **Ingress not working**
   - Add entries to /etc/hosts:
   ```
   127.0.0.1 api.hello-dd.local
   127.0.0.1 inventory.hello-dd.local
   127.0.0.1 pricing.hello-dd.local
   ```

2. **Service discovery failing**
   ```bash
   # Test DNS resolution
   kubectl run dns-test --image=busybox:1.28 -it --rm --restart=Never -- nslookup inventory-service.hello-dd.svc.cluster.local
   ```

3. **HPA not scaling**
   ```bash
   # Check metrics server
   kubectl top nodes
   kubectl top pods -n hello-dd
   ```

## Deliverables

1. **Complete System Deployment**
   - All three services running in Kubernetes
   - Ingress routing working
   - Service discovery functional
   - HPA configured for all services

2. **Production Features**
   - Circuit breakers active
   - Health checks passing
   - Metrics available
   - Optional: Service mesh integrated

3. **Testing**
   - End-to-end tests passing
   - Load tests successful
   - Scaling verified

## Success Criteria

- Complete system accessible via Ingress
- Service-to-service communication working
- HPA scaling under load
- Circuit breakers preventing cascades
- Zero downtime deployments possible
- Monitoring and observability ready
- Optional: Service mesh traffic management working

## Foundation for Next Phases

Ready for:
- AWS deployment (Phase 8)
- Advanced patterns (Phase 9)
- Full observability (Phase 10)