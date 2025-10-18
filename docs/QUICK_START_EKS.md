# Quick Start Guide - EKS Cluster Setup

This is a condensed version of the EKS setup for issue #54. For detailed instructions, see [EKS_SETUP_GUIDE.md](EKS_SETUP_GUIDE.md).

## Prerequisites Checklist

Before running the setup scripts, ensure you have:

- [ ] AWS account with admin permissions
- [ ] AWS CLI installed and configured
- [ ] eksctl installed
- [ ] kubectl installed

## Step-by-Step Instructions

### 1. Install Required Tools

#### AWS CLI (choose your OS):

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

**macOS:**
```bash
brew install awscli
aws --version
```

**Windows (PowerShell as Administrator):**
```powershell
# Using Chocolatey
choco install awscli

# Verify
aws --version
```

#### eksctl (choose your OS):

**Linux:**
```bash
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

**macOS:**
```bash
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
eksctl version
```

**Windows (PowerShell as Administrator):**
```powershell
choco install eksctl
eksctl version
```

#### kubectl (choose your OS):

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

**macOS:**
```bash
brew install kubectl
kubectl version --client
```

**Windows (PowerShell as Administrator):**
```powershell
choco install kubernetes-cli
kubectl version --client
```

### 2. Configure AWS Credentials

You need to obtain AWS credentials from your AWS account:

1. Log into AWS Console: https://console.aws.amazon.com
2. Go to: IAM → Users → [Your Username] → Security Credentials
3. Click "Create access key"
4. Choose "Command Line Interface (CLI)"
5. Download or copy the credentials

Then configure AWS CLI:

```bash
aws configure
```

Enter the following when prompted:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**Verify configuration:**
```bash
aws sts get-caller-identity
```

You should see your AWS account details.

### 3. Create EKS Cluster

Run the automated creation script:

```bash
./scripts/create-eks-cluster.sh
```

**What this does:**
- Validates all prerequisites
- Creates EKS cluster named "hello-dd"
- Sets up 2 t3.medium worker nodes
- Configures kubectl automatically
- Verifies cluster is ready

**Expected time:** 15-20 minutes

**Expected output:**
```
==========================================
  EKS Cluster Creation - hello-dd
  Issue: #54
==========================================

[INFO] Checking required tools...
[SUCCESS] All required tools are installed
[INFO] Creating EKS cluster...
...
[SUCCESS] Cluster Creation Complete!
```

### 4. Verify Cluster

Run the verification script:

```bash
./scripts/verify-eks-cluster.sh
```

**What this does:**
- Checks kubectl configuration
- Verifies all nodes are ready
- Tests pod deployment
- Validates cluster functionality

**Expected output:**
```
==========================================
  EKS Cluster Verification - hello-dd
  Issue: #54
==========================================

[SUCCESS] kubectl is configured and can connect to cluster
[SUCCESS] All nodes are ready
[SUCCESS] Test pod is running
[SUCCESS] Verification Complete!
```

## Manual Verification (Optional)

If you want to manually verify the cluster:

```bash
# Check cluster status
eksctl get cluster --name hello-dd --region us-east-1

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Deploy test pod
kubectl run nginx-test --image=nginx:latest
kubectl get pod nginx-test
kubectl delete pod nginx-test
```

## Troubleshooting

### "AWS credentials not found"
```bash
# Re-configure AWS
aws configure

# Or check existing config
cat ~/.aws/credentials
```

### "Command not found: eksctl" or "kubectl"
- Verify installation: `which eksctl` and `which kubectl`
- Ensure tools are in your PATH
- Reinstall using instructions above

### "Cluster creation failed"
```bash
# Delete failed cluster
eksctl delete cluster --name hello-dd --region us-east-1

# Check CloudFormation in AWS Console for error details
# Retry creation
./scripts/create-eks-cluster.sh
```

### "Nodes not ready"
```bash
# Wait a bit longer (nodes can take 5-10 minutes)
kubectl get nodes -w

# Check node details
kubectl describe nodes
```

## Important: Cost Management

**Running costs:** ~$0.20/hour (~$150/month)
- EKS control plane: $0.10/hour
- 2x t3.medium nodes: ~$0.10/hour

**Delete cluster when done:**
```bash
eksctl delete cluster --name hello-dd --region us-east-1
```

This takes about 10-15 minutes and removes ALL resources.

## Next Steps

After successful cluster creation:

1. **Deploy hello-dd services:**
   ```bash
   # Create Kubernetes manifests (coming soon)
   kubectl apply -f k8s/
   ```

2. **Install Datadog Agent:**
   ```bash
   # Follow Datadog EKS installation guide
   # https://docs.datadoghq.com/containers/amazon_eks/
   ```

3. **Test distributed tracing:**
   - Generate traffic to API Gateway
   - View traces in Datadog APM

## Useful Commands

```bash
# View all resources
kubectl get all --all-namespaces

# View cluster info
kubectl cluster-info

# View logs
kubectl logs <pod-name>

# Describe resource
kubectl describe <resource-type> <name>

# Port forward for testing
kubectl port-forward <pod-name> 8080:80

# Get cluster endpoint
kubectl config view --minify

# Switch context (if you have multiple clusters)
kubectl config get-contexts
kubectl config use-context <context-name>
```

## Additional Resources

- Full guide: [EKS_SETUP_GUIDE.md](EKS_SETUP_GUIDE.md)
- eksctl docs: https://eksctl.io/
- kubectl cheat sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- AWS EKS docs: https://docs.aws.amazon.com/eks/

---

**Questions?** Check the [EKS_SETUP_GUIDE.md](EKS_SETUP_GUIDE.md) for detailed troubleshooting steps.
