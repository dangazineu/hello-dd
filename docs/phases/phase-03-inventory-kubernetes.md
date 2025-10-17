# Phase 3: Inventory Service Kubernetes Deployment

## Overview
Deploy the Inventory Service from Phase 2 to a local Kubernetes cluster using Kind. This phase establishes Kubernetes deployment patterns that will be reused for all subsequent services.

## Objectives
- Set up local Kubernetes cluster with Kind
- Create Kubernetes manifests for Inventory Service
- Deploy PostgreSQL to Kubernetes
- Implement ConfigMaps and Secrets
- Set up local image registry
- Establish deployment patterns for future services

## Kubernetes Cluster Setup

### Kind Configuration
```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: hello-dd
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      # Inventory Service
      - containerPort: 30001
        hostPort: 8001
        protocol: TCP
      # Future services
      - containerPort: 30002
        hostPort: 8002
        protocol: TCP
      - containerPort: 30000
        hostPort: 8000
        protocol: TCP
      # PostgreSQL (for development)
      - containerPort: 30432
        hostPort: 5433
        protocol: TCP
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
      endpoint = ["http://kind-registry:5000"]
```

### Local Registry Setup
```yaml
# kind-registry.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kind-registry
  labels:
    app: kind-registry
spec:
  containers:
  - name: registry
    image: registry:2
    ports:
    - containerPort: 5000
      hostPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: kind-registry
spec:
  selector:
    app: kind-registry
  ports:
  - port: 5000
    targetPort: 5000
```

### Cluster Setup Script
```bash
#!/bin/bash
# scripts/setup-kind.sh

set -e

echo "Creating Kind cluster..."
kind create cluster --config kind-config.yaml

echo "Setting up local registry..."
docker run -d --restart=always -p 5000:5000 --name kind-registry registry:2

echo "Connecting registry to Kind network..."
docker network connect kind kind-registry || true

echo "Installing NGINX Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "Creating hello-dd namespace..."
kubectl create namespace hello-dd

echo "Cluster setup complete!"
kubectl cluster-info
```

## Kubernetes Manifests

### Namespace and Common Resources
```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hello-dd
  labels:
    name: hello-dd
    environment: development
```

### PostgreSQL Deployment
```yaml
# k8s/postgres/postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: hello-dd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: inventory
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
              - pg_isready
              - -U
              - inventory
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
              - pg_isready
              - -U
              - inventory
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: init-script
        configMap:
          name: postgres-init
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: hello-dd
spec:
  type: NodePort
  ports:
  - port: 5432
    targetPort: 5432
    nodePort: 30432
  selector:
    app: postgres
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: hello-dd
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### Inventory Service Deployment
```yaml
# k8s/inventory-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: hello-dd
  labels:
    app: inventory-service
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inventory-service
  template:
    metadata:
      labels:
        app: inventory-service
        version: v1
    spec:
      containers:
      - name: inventory-service
        image: localhost:5000/inventory-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8001
          name: http
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: kubernetes
        - name: SPRING_DATASOURCE_URL
          value: jdbc:postgresql://postgres:5432/inventory
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
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
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8001
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8001
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  namespace: hello-dd
  labels:
    app: inventory-service
spec:
  type: NodePort
  ports:
  - port: 8001
    targetPort: 8001
    nodePort: 30001
    name: http
  selector:
    app: inventory-service
```

### Configuration Management
```yaml
# k8s/config/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: hello-dd
data:
  environment: "development"
  version: "1.0.0"
  log_level: "INFO"

---
# k8s/config/postgres-init.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
  namespace: hello-dd
data:
  init.sql: |
    CREATE SCHEMA IF NOT EXISTS inventory;

    CREATE TABLE IF NOT EXISTS inventory.products (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sku VARCHAR(100) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        category VARCHAR(100),
        stock_level INTEGER NOT NULL DEFAULT 0,
        reserved_stock INTEGER NOT NULL DEFAULT 0,
        reorder_point INTEGER DEFAULT 10,
        unit_cost DECIMAL(10,2),
        version BIGINT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Sample data
    INSERT INTO inventory.products (sku, name, description, category, stock_level, unit_cost)
    VALUES
        ('K8S-001', 'Kubernetes Book', 'Learn Kubernetes', 'Books', 100, 39.99),
        ('K8S-002', 'Docker Guide', 'Docker Deep Dive', 'Books', 75, 29.99);
```

### Secrets
```yaml
# k8s/config/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: hello-dd
type: Opaque
data:
  # Base64 encoded: inventory
  username: aW52ZW50b3J5
  # Base64 encoded: inventory123
  password: aW52ZW50b3J5MTIz
```

## Application Configuration for Kubernetes

### Kubernetes Profile
```yaml
# inventory-service/src/main/resources/application-kubernetes.yml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5

management:
  endpoint:
    health:
      probes:
        enabled: true
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true

server:
  shutdown: graceful

logging:
  level:
    root: ${LOG_LEVEL:INFO}
  pattern:
    console: "%d{ISO8601} [%thread] %-5level %logger{36} - %msg%n"
```

## Deployment Scripts

### Build and Deploy Script
```bash
#!/bin/bash
# scripts/deploy-inventory.sh

set -e

echo "Building Inventory Service..."
cd inventory-service
mvn clean package -DskipTests

echo "Building Docker image..."
docker build -t inventory-service:latest .

echo "Tagging for local registry..."
docker tag inventory-service:latest localhost:5000/inventory-service:latest

echo "Pushing to local registry..."
docker push localhost:5000/inventory-service:latest

echo "Deploying to Kubernetes..."
kubectl apply -f ../k8s/config/
kubectl apply -f ../k8s/postgres/
kubectl apply -f ../k8s/inventory-service/

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available \
  --timeout=120s \
  deployment/inventory-service \
  -n hello-dd

echo "Deployment complete!"
kubectl get pods -n hello-dd
```

### Makefile Additions
```makefile
# Additional Makefile targets for Kubernetes

.PHONY: k8s-setup k8s-deploy-inventory k8s-logs-inventory k8s-test

k8s-setup:
	./scripts/setup-kind.sh

k8s-deploy-inventory:
	./scripts/deploy-inventory.sh

k8s-logs-inventory:
	kubectl logs -f deployment/inventory-service -n hello-dd

k8s-port-forward:
	kubectl port-forward -n hello-dd svc/inventory-service 8001:8001

k8s-test:
	@echo "Testing Inventory Service in Kubernetes..."
	curl http://localhost:8001/actuator/health
	curl http://localhost:8001/api/v1/products

k8s-clean:
	kubectl delete namespace hello-dd
	kind delete cluster --name hello-dd
	docker stop kind-registry && docker rm kind-registry
```

## Testing Kubernetes Deployment

### Verification Steps
```bash
# 1. Setup cluster
make k8s-setup

# 2. Deploy inventory service
make k8s-deploy-inventory

# 3. Check pods status
kubectl get pods -n hello-dd

# 4. Check service endpoints
kubectl get svc -n hello-dd

# 5. Test service directly via NodePort
curl http://localhost:8001/actuator/health
curl http://localhost:8001/api/v1/products

# 6. Check logs
kubectl logs -f deployment/inventory-service -n hello-dd

# 7. Test database connection
kubectl exec -it deployment/postgres -n hello-dd -- \
  psql -U inventory -d inventory -c "SELECT * FROM inventory.products;"

# 8. Scale the deployment
kubectl scale deployment/inventory-service --replicas=3 -n hello-dd
```

### Troubleshooting Commands
```bash
# Describe pods for issues
kubectl describe pod -l app=inventory-service -n hello-dd

# Get events
kubectl get events -n hello-dd --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n hello-dd

# Get deployment status
kubectl rollout status deployment/inventory-service -n hello-dd

# Access pod shell
kubectl exec -it deployment/inventory-service -n hello-dd -- /bin/sh
```

## Monitoring and Observability

### Basic Metrics with kubectl
```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View resource usage
kubectl top nodes
kubectl top pods -n hello-dd
```

### Service Health Dashboard
```bash
# Simple monitoring script
#!/bin/bash
# scripts/monitor.sh

while true; do
  clear
  echo "=== Inventory Service Health ==="
  echo
  kubectl get pods -n hello-dd | grep inventory
  echo
  echo "=== Resource Usage ==="
  kubectl top pod -n hello-dd | grep inventory
  echo
  echo "=== Recent Events ==="
  kubectl get events -n hello-dd --field-selector involvedObject.name=inventory-service
  sleep 5
done
```

## Deliverables

1. **Kubernetes Deployment**
   - Kind cluster configured and running
   - Inventory Service deployed with 2 replicas
   - PostgreSQL running in cluster
   - ConfigMaps and Secrets configured

2. **Local Registry**
   - Registry running and accessible
   - Images pushed successfully
   - Pull working from cluster

3. **Networking**
   - Services accessible via NodePort
   - Inter-service communication working
   - Database connection established

4. **Operations**
   - Health checks passing
   - Logs accessible
   - Scaling working
   - Updates deployable

## Success Criteria

- Kind cluster running successfully
- Inventory Service pods healthy
- Database accessible from service
- API endpoints responding
- Service survives pod deletion
- Configuration changes without rebuild
- Local registry working
- Health probes functioning correctly

## Foundation for Next Phases

This phase establishes:
- Kubernetes deployment patterns
- Local development workflow
- Configuration management approach
- Service discovery basics

Ready for:
- Phase 4: Pricing Service implementation
- Phase 5: Pricing Service Kubernetes deployment
- Reusable patterns for all services