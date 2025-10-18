# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the hello-dd services to EKS.

## Quick Start

### Deploy API Gateway

```bash
kubectl apply -f k8s/api-gateway.yaml
```

### Check Deployment Status

```bash
# Check pods
kubectl get pods -l app=api-gateway

# Check service and get LoadBalancer URL
kubectl get service api-gateway

# Get LoadBalancer URL directly
kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Test the Deployment

```bash
# Get the LoadBalancer URL
LB_URL=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$LB_URL/health

# Test root endpoint
curl http://$LB_URL/

# Test products endpoint
curl http://$LB_URL/products?limit=5

# Test order creation
curl -X POST "http://$LB_URL/order?product_id=TEST-001&quantity=2"
```

## Manifests

### api-gateway.yaml

Deploys the API Gateway service with:
- **Deployment**: 2 replicas for high availability
- **Service**: LoadBalancer type for external access
- **Probes**: Liveness and readiness probes for health checking
- **Resources**: CPU and memory limits for resource management
- **Environment**: Configured for PostgreSQL and Redis (optional)
- **Datadog Tags**: Pre-configured for APM instrumentation

**Key Features:**
- Graceful degradation: Works without PostgreSQL/Redis
- Auto-scaling ready: Can add HPA later
- Health checks: Ensures pods are healthy before routing traffic
- LoadBalancer: Provides external access via AWS ELB

## Architecture

```
Internet
   ↓
AWS ELB (LoadBalancer)
   ↓
api-gateway Service (ClusterIP internally exposed as LoadBalancer)
   ↓
api-gateway Pods (2 replicas)
```

## Environment Variables

The API Gateway supports these environment variables:

### Application Configuration
- `PORT`: Application port (default: 8000)
- `HOST`: Bind host (default: 0.0.0.0)
- `LOG_LEVEL`: Logging level (default: info)

### Database Configuration (Optional)
- `POSTGRES_HOST`: PostgreSQL hostname
- `POSTGRES_PORT`: PostgreSQL port (default: 5432)
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `POSTGRES_DB`: Database name

### Cache Configuration (Optional)
- `REDIS_HOST`: Redis hostname
- `REDIS_PORT`: Redis port (default: 6379)

### Service URLs
- `INVENTORY_SERVICE_URL`: Inventory service endpoint
- `PRICING_SERVICE_URL`: Pricing service endpoint

### Datadog Configuration
- `DD_ENV`: Environment (dev, staging, prod)
- `DD_SERVICE`: Service name
- `DD_VERSION`: Service version

## Resource Requirements

### API Gateway
- **Requests**: 100m CPU, 128Mi memory
- **Limits**: 500m CPU, 512Mi memory

These are conservative defaults suitable for demo purposes. Adjust based on load testing results.

## Scaling

### Manual Scaling

```bash
# Scale to 3 replicas
kubectl scale deployment api-gateway --replicas=3

# Verify
kubectl get pods -l app=api-gateway
```

### Auto-Scaling (Future)

```bash
# Create HPA (requires metrics-server)
kubectl autoscale deployment api-gateway \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

## Monitoring

### View Logs

```bash
# All pods
kubectl logs -l app=api-gateway --tail=100 -f

# Specific pod
kubectl logs <pod-name> -f
```

### Describe Resources

```bash
# Deployment
kubectl describe deployment api-gateway

# Service
kubectl describe service api-gateway

# Pods
kubectl describe pod -l app=api-gateway
```

### Events

```bash
# Watch events
kubectl get events --sort-by='.lastTimestamp' | grep api-gateway
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -l app=api-gateway

# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### LoadBalancer Not Getting External IP

```bash
# Check service
kubectl describe service api-gateway

# AWS ELB can take 2-3 minutes to provision
# Wait and check again
kubectl get service api-gateway -w
```

### Cannot Access Service

```bash
# Verify pods are running
kubectl get pods -l app=api-gateway

# Check service endpoints
kubectl get endpoints api-gateway

# Test from within cluster
kubectl run test-pod --rm -it --image=curlimages/curl -- /bin/sh
# Then: curl http://api-gateway/health
```

### Health Check Failures

```bash
# Check pod logs
kubectl logs <pod-name>

# Describe pod to see probe failures
kubectl describe pod <pod-name>

# Manually test health endpoint
kubectl port-forward <pod-name> 8000:8000
# Then: curl http://localhost:8000/health
```

## Cleanup

### Delete API Gateway

```bash
kubectl delete -f k8s/api-gateway.yaml
```

### Verify Deletion

```bash
kubectl get all -l app=api-gateway
```

## Next Steps

1. **Deploy PostgreSQL and Redis** (optional):
   - Use in-cluster deployments or managed services (RDS/ElastiCache)
   - Update environment variables in manifests

2. **Deploy Inventory and Pricing Services**:
   - Create similar manifests for other services
   - Configure inter-service communication

3. **Install Datadog Agent**:
   - Enable Single Step APM for automatic instrumentation
   - See issue #58 for instructions

4. **Set up Ingress** (optional):
   - Replace LoadBalancer with Ingress controller
   - Configure custom domain and TLS

5. **Configure Monitoring**:
   - Set up Datadog dashboards
   - Configure alerts
   - Enable trace collection

## Cost Considerations

- **LoadBalancer**: ~$0.025/hour (~$18/month per service)
- **EC2 instances**: Covered by EKS node costs
- **Data transfer**: First 1GB/month free, then $0.09/GB

For cost savings, consider using Ingress instead of LoadBalancer for multiple services.
