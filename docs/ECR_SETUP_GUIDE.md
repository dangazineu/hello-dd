# ECR Setup Guide - Docker Image Registry

This guide explains how to build Docker images for the hello-dd services and push them to Amazon Elastic Container Registry (ECR) for deployment to EKS.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Automated Setup](#automated-setup)
4. [Manual Setup](#manual-setup)
5. [Troubleshooting](#troubleshooting)

---

## Overview

Amazon ECR is a fully managed Docker container registry that makes it easy to store, manage, and deploy Docker container images. This guide covers:

- Creating ECR repositories for hello-dd services
- Building Docker images locally
- Pushing images to ECR
- Verifying images are accessible

**Services covered:**
- API Gateway (Python/FastAPI) - Port 8000
- Inventory Service (Java/Spring Boot) - Port 8001 *(coming soon)*
- Pricing Service (Go/Gin) - Port 8002 *(coming soon)*

---

## Prerequisites

### Required Tools

1. **Docker** - For building images
   ```bash
   docker --version
   # Should show: Docker version 20.x or higher
   ```

2. **AWS CLI** - For ECR operations
   ```bash
   aws --version
   # Should show: aws-cli/2.x.x
   ```

3. **AWS Credentials** - Configured and valid
   ```bash
   aws sts get-caller-identity
   # Should show your AWS account details
   ```

### AWS Permissions

Your AWS user/role needs these permissions:
- **ECR**: CreateRepository, DescribeRepositories, GetAuthorizationToken, PutImage, UploadLayerPart, CompleteLayerUpload
- **ECR (Read)**: ListImages, DescribeImages, BatchGetImage

The easiest approach is to use the `AmazonEC2ContainerRegistryPowerUser` policy.

---

## Automated Setup

The fastest way to push images to ECR is using our automation script.

### Step 1: Run the Script

```bash
./scripts/push-to-ecr.sh
```

### What the Script Does

1. **Validates prerequisites** - Checks Docker and AWS CLI are installed
2. **Verifies AWS credentials** - Ensures you're authenticated
3. **Creates ECR repositories** - For all three services (even if not built yet)
4. **Authenticates Docker to ECR** - Logs Docker into ECR
5. **Builds images** - For services that exist (currently API Gateway)
6. **Tags images** - With both `:latest` and `:commit-sha`
7. **Pushes to ECR** - Uploads images to your repositories
8. **Verifies success** - Confirms images are accessible

### Expected Output

```
==========================================
  ECR Image Push - hello-dd
  Issue: #55
==========================================

[INFO] Checking required tools...
[SUCCESS] All required tools are installed
[INFO] AWS Account: 157626804532
[INFO] Creating repository: hello-dd/api-gateway
[SUCCESS] Repository created: hello-dd/api-gateway
[INFO] Building image for: api-gateway
[SUCCESS] Image built: api-gateway:latest
[INFO] Pushing image to ECR: hello-dd/api-gateway
[SUCCESS] Pushed: 157626804532.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest
[SUCCESS] Docker images pushed to ECR successfully!
```

### Time Estimate

- **First run**: 5-10 minutes (includes Docker image build)
- **Subsequent runs**: 2-5 minutes (Docker layer caching)

---

## Manual Setup

If you prefer to run commands manually or need to understand the process:

### Step 1: Get Your AWS Account ID

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo $AWS_ACCOUNT_ID
```

### Step 2: Create ECR Repositories

```bash
# API Gateway
aws ecr create-repository \
  --repository-name hello-dd/api-gateway \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Inventory Service (future)
aws ecr create-repository \
  --repository-name hello-dd/inventory-service \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Pricing Service (future)
aws ecr create-repository \
  --repository-name hello-dd/pricing-service \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

### Step 3: Authenticate Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

**Expected output:** `Login Succeeded`

### Step 4: Build Docker Image

```bash
# API Gateway
cd api-gateway
docker build -t api-gateway:latest .
cd ..
```

### Step 5: Tag Image

```bash
# Tag with latest
docker tag api-gateway:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest

# Tag with commit SHA (optional but recommended)
GIT_COMMIT=$(git rev-parse --short HEAD)
docker tag api-gateway:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:${GIT_COMMIT}
```

### Step 6: Push Image to ECR

```bash
# Push latest tag
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest

# Push commit SHA tag
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:${GIT_COMMIT}
```

### Step 7: Verify Images in ECR

```bash
# List images in repository
aws ecr list-images \
  --repository-name hello-dd/api-gateway \
  --region us-east-1

# Describe images (shows details)
aws ecr describe-images \
  --repository-name hello-dd/api-gateway \
  --region us-east-1
```

---

## Verifying Images

### View in AWS Console

1. Navigate to: https://console.aws.amazon.com/ecr/repositories?region=us-east-1
2. Click on `hello-dd/api-gateway`
3. You should see your images with tags `latest` and your commit SHA

### Pull Image Locally (Test)

```bash
# Pull from ECR
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest

# Run locally to test
docker run -p 8000:8000 \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest
```

### Test in EKS

You can test pulling the image from your EKS cluster:

```bash
# Create a test pod
kubectl run api-gateway-test \
  --image=${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest \
  --port=8000

# Check if it's running
kubectl get pod api-gateway-test

# Clean up
kubectl delete pod api-gateway-test
```

---

## Image Tagging Strategy

Our automation uses two tags:

### 1. `latest` Tag
- Always points to the most recent build
- Use for development and testing
- **Not recommended** for production

### 2. Commit SHA Tag (e.g., `abc123f`)
- Immutable reference to specific code version
- Enables rollback to exact versions
- **Recommended** for production deployments

**Example:**
```
157626804532.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:latest
157626804532.dkr.ecr.us-east-1.amazonaws.com/hello-dd/api-gateway:ec0fb0a
```

---

## Repository Configuration

Our ECR repositories are configured with:

- **Image Scanning**: Enabled on push (scans for vulnerabilities)
- **Encryption**: AES256 encryption at rest
- **Region**: us-east-1 (matches EKS cluster)

### Lifecycle Policies (Optional)

To save costs, you can add lifecycle policies to delete old images:

```bash
cat > lifecycle-policy.json <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name hello-dd/api-gateway \
  --lifecycle-policy-text file://lifecycle-policy.json
```

---

## Troubleshooting

### Issue: "command not found: docker"

**Solution:**
```bash
# Install Docker
# For Ubuntu/Debian:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: "permission denied while trying to connect to Docker daemon"

**Solution:**
```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and log back in, then verify
docker ps
```

### Issue: "Unable to locate credentials"

**Solution:**
```bash
# Configure AWS credentials
aws configure

# Or verify existing config
aws sts get-caller-identity
```

### Issue: "RepositoryAlreadyExistsException"

**This is normal!** The repository already exists. The script handles this gracefully.

### Issue: "denied: User not authorized to perform: ecr:CreateRepository"

**Solution:**
- Contact your AWS administrator
- Ensure your IAM user has ECR permissions
- Try with `AmazonEC2ContainerRegistryPowerUser` policy

### Issue: "no basic auth credentials"

**Solution:**
```bash
# Re-authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

**Note:** ECR authentication tokens expire after 12 hours. Re-run if you get auth errors.

### Issue: Docker build fails

**Solution:**
```bash
# Check Dockerfile syntax
cd api-gateway
docker build -t test .

# View detailed build logs
docker build --progress=plain -t test .

# Check if requirements.txt exists
ls -la requirements.txt
```

### Issue: Image push is very slow

**Solution:**
- This is normal for first push (uploading all layers)
- Subsequent pushes are faster (only changed layers)
- Check your internet connection
- Consider using AWS bandwidth optimization if available

---

## Cost Information

### ECR Pricing (us-east-1)

- **Storage**: $0.10 per GB/month
- **Data Transfer**:
  - Within same region (to EKS): FREE
  - Out to internet: Standard AWS data transfer rates

**Estimated costs for hello-dd:**
- 3 images × ~500MB each = 1.5GB
- Monthly cost: ~$0.15/month
- **Negligible for demo purposes**

---

## Next Steps

After pushing images to ECR:

1. **Create Kubernetes manifests** - Define deployments using ECR image URIs
2. **Deploy to EKS**:
   ```bash
   kubectl apply -f k8s/
   ```
3. **Verify deployments**:
   ```bash
   kubectl get pods
   kubectl get services
   ```
4. **Install Datadog Agent** - For APM monitoring

---

## Useful Commands

```bash
# List all ECR repositories
aws ecr describe-repositories --region us-east-1

# List images in a repository
aws ecr list-images --repository-name hello-dd/api-gateway --region us-east-1

# Get image details
aws ecr describe-images --repository-name hello-dd/api-gateway --region us-east-1

# Delete an image
aws ecr batch-delete-image \
  --repository-name hello-dd/api-gateway \
  --image-ids imageTag=old-tag \
  --region us-east-1

# Delete a repository (careful!)
aws ecr delete-repository \
  --repository-name hello-dd/api-gateway \
  --region us-east-1 \
  --force  # Deletes even if images exist
```

---

## Additional Resources

- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [ECR with EKS](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)

---

**Implementation completed for Issue #55**
**All scripts tested and documentation complete**
