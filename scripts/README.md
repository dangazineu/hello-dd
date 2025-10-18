# Scripts Directory

This directory contains utility scripts for the hello-dd project.

## Available Scripts

### EKS Cluster Management (Issue #54)

#### `create-eks-cluster.sh`
Automated EKS cluster creation script.

**Usage:**
```bash
./scripts/create-eks-cluster.sh
```

**What it does:**
- Validates prerequisites (AWS CLI, eksctl, kubectl)
- Checks AWS credentials
- Creates EKS cluster named "hello-dd"
- Configures kubectl automatically
- Verifies cluster is ready

**Prerequisites:**
- AWS CLI installed and configured
- eksctl installed
- kubectl installed
- AWS account with appropriate permissions

**Time:** ~15-20 minutes

---

#### `verify-eks-cluster.sh`
Cluster verification and health check script.

**Usage:**
```bash
./scripts/verify-eks-cluster.sh
```

**What it does:**
- Checks kubectl configuration
- Verifies node health
- Tests pod deployment
- Validates cluster functionality
- Cleans up test resources

**Time:** ~2-3 minutes

---

### EKS Deployment (Issue #56)

#### `deploy-to-eks.sh`
Automated Kubernetes deployment to EKS.

**Usage:**
```bash
./scripts/deploy-to-eks.sh
```

**What it does:**
- Validates kubectl configuration
- Deploys Kubernetes manifests to EKS
- Waits for pods to be ready
- Waits for LoadBalancer provisioning
- Tests deployment endpoints
- Displays service URLs and useful commands

**Prerequisites:**
- EKS cluster running
- kubectl configured with cluster access
- Kubernetes manifests in k8s/ directory

**Time:** ~5-10 minutes (includes LoadBalancer provisioning)

---

### ECR Image Management (Issue #55)

#### `push-to-ecr.sh`
Automated Docker image build and ECR push script.

**Usage:**
```bash
./scripts/push-to-ecr.sh
```

**What it does:**
- Validates prerequisites (Docker, AWS CLI)
- Creates ECR repositories for all services
- Authenticates Docker to ECR
- Builds Docker images for existing services
- Tags images with `:latest` and `:commit-sha`
- Pushes images to ECR
- Verifies images are accessible

**Prerequisites:**
- Docker installed
- AWS CLI configured with credentials
- Sufficient AWS permissions for ECR

**Time:** ~5-10 minutes (first run)

---

### Database Initialization

#### `init-db.sql`
PostgreSQL database initialization script for the Inventory Service.

**Usage:**
This script is automatically executed when the PostgreSQL container starts via docker-compose.

**Contains:**
- Database schema creation
- Initial data seeding
- Sample product catalog

---

## Getting Started with EKS

For first-time setup, follow this sequence:

1. **Read the documentation:**
   - Quick start: `docs/QUICK_START_EKS.md`
   - Full guide: `docs/EKS_SETUP_GUIDE.md`
   - ECR setup: `docs/ECR_SETUP_GUIDE.md`

2. **Install prerequisites:**
   - AWS CLI
   - eksctl
   - kubectl
   - Docker

3. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

4. **Create EKS cluster:**
   ```bash
   ./scripts/create-eks-cluster.sh
   ```

5. **Verify cluster:**
   ```bash
   ./scripts/verify-eks-cluster.sh
   ```

6. **Build and push Docker images:**
   ```bash
   ./scripts/push-to-ecr.sh
   ```

7. **Deploy services to EKS:**
   ```bash
   ./scripts/deploy-to-eks.sh
   ```

8. **Get service URL and test:**
   ```bash
   kubectl get service api-gateway
   curl http://<loadbalancer-url>/health
   ```

## Script Features

Both EKS scripts include:
- ✅ Color-coded output for easy reading
- ✅ Comprehensive error checking
- ✅ Step-by-step progress indicators
- ✅ Automatic prerequisite validation
- ✅ Interactive confirmations
- ✅ Helpful error messages
- ✅ Next steps guidance

## Troubleshooting

If scripts fail, check:

1. **Permissions:**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **AWS credentials:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Tool versions:**
   ```bash
   aws --version
   eksctl version
   kubectl version --client
   ```

For detailed troubleshooting, see `docs/EKS_SETUP_GUIDE.md`.

## Cost Warning

The EKS cluster costs approximately:
- **$0.20/hour** (~$150/month if left running)

**Always delete the cluster when done:**
```bash
eksctl delete cluster --name hello-dd --region us-east-1
```

## Contributing

When adding new scripts:
1. Make them executable: `chmod +x scripts/your-script.sh`
2. Add proper error handling
3. Include usage documentation
4. Use consistent output formatting
5. Update this README

---

For more information, see the main project [README.md](../README.md).
