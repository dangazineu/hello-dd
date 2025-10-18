# EKS Cluster Setup Guide - Issue #54

This guide provides step-by-step instructions to set up a minimal EKS cluster for APM testing using eksctl.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Tool Installation](#tool-installation)
3. [AWS Configuration](#aws-configuration)
4. [EKS Cluster Creation](#eks-cluster-creation)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:
- An active AWS account
- Administrative access to your local machine
- Internet connection
- Approximately 20-30 minutes for cluster creation

### Required AWS Permissions

Your AWS user/role needs the following permissions:
- EC2 (for node groups and networking)
- EKS (for cluster management)
- CloudFormation (eksctl uses this)
- IAM (for creating service roles)
- Systems Manager (for node management)

The easiest approach is to use the `AdministratorAccess` policy for initial setup, or create a custom policy with these specific permissions.

---

## Tool Installation

### 1. Install AWS CLI

#### Linux (Ubuntu/Debian)
```bash
# Download and install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

#### macOS
```bash
# Using Homebrew (recommended)
brew install awscli

# OR download installer
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Verify installation
aws --version
```

#### Windows
1. Download the AWS CLI MSI installer from: https://awscli.amazonaws.com/AWSCLIV2.msi
2. Run the installer
3. Open a new Command Prompt or PowerShell window
4. Verify: `aws --version`

**Expected output:** `aws-cli/2.x.x Python/3.x.x ...`

---

### 2. Install eksctl

#### Linux
```bash
# Download and install eksctl
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# Extract and move to bin
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# Verify installation
eksctl version
```

#### macOS
```bash
# Using Homebrew (recommended)
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verify installation
eksctl version
```

#### Windows
```powershell
# Using Chocolatey
choco install eksctl

# OR using Scoop
scoop install eksctl

# Verify installation
eksctl version
```

**Expected output:** `0.x.x`

---

### 3. Install kubectl

#### Linux
```bash
# Download latest stable version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable and move to bin
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

#### macOS
```bash
# Using Homebrew (recommended)
brew install kubectl

# Verify installation
kubectl version --client
```

#### Windows
```powershell
# Using Chocolatey
choco install kubernetes-cli

# OR using Scoop
scoop install kubectl

# Verify installation
kubectl version --client
```

**Expected output:** `Client Version: v1.x.x`

---

## AWS Configuration

### Step 1: Obtain AWS Credentials

You'll need:
- AWS Access Key ID
- AWS Secret Access Key
- (Optional) AWS Session Token (if using temporary credentials)

**To create credentials:**
1. Log into AWS Console
2. Go to IAM → Users → Your Username
3. Click "Security Credentials" tab
4. Click "Create access key"
5. Choose "Command Line Interface (CLI)"
6. Download or copy the credentials

### Step 2: Configure AWS CLI

Run the configuration command:
```bash
aws configure
```

You'll be prompted for:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**Recommended region:** `us-east-1` (matches the eksctl script)

### Step 3: Verify AWS Configuration

```bash
# Check your AWS identity
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

If you see your account details, you're configured correctly!

### Alternative: Environment Variables

Instead of `aws configure`, you can set environment variables:

**Linux/macOS:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Windows (PowerShell):**
```powershell
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"
$env:AWS_DEFAULT_REGION="us-east-1"
```

---

## EKS Cluster Creation

### Option 1: Using the Provided Script (Recommended)

We've created a script that automates the cluster creation process:

```bash
# Make the script executable
chmod +x scripts/create-eks-cluster.sh

# Run the script
./scripts/create-eks-cluster.sh
```

The script will:
1. Validate prerequisites
2. Create the EKS cluster
3. Configure kubectl automatically
4. Verify the cluster is ready

**Expected time:** 15-20 minutes

### Option 2: Manual eksctl Command

If you prefer to run the command manually:

```bash
eksctl create cluster \
  --name hello-dd \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --managed
```

### What Gets Created

The eksctl command creates:
- EKS control plane (master nodes)
- Managed node group with 2 t3.medium EC2 instances
- VPC with public and private subnets
- Security groups
- IAM roles for cluster and nodes
- CloudFormation stacks

**Estimated AWS costs:** ~$0.20/hour (~$150/month if left running 24/7)
- EKS cluster: $0.10/hour
- 2x t3.medium nodes: ~$0.10/hour

---

## Verification

### Step 1: Check Cluster Status

```bash
# Check eksctl cluster info
eksctl get cluster --name hello-dd --region us-east-1

# Check kubectl configuration
kubectl config current-context

# Should show: your-user@hello-dd.us-east-1.eksctl.io
```

### Step 2: Verify Nodes

```bash
# List cluster nodes
kubectl get nodes

# Expected output:
# NAME                             STATUS   ROLES    AGE   VERSION
# ip-xxx-xxx-xxx-xxx.ec2.internal  Ready    <none>   2m    v1.28.x
# ip-xxx-xxx-xxx-xxx.ec2.internal  Ready    <none>   2m    v1.28.x
```

Both nodes should show `STATUS: Ready`

### Step 3: Deploy Test Pod

Use the verification script:
```bash
# Make executable
chmod +x scripts/verify-eks-cluster.sh

# Run verification
./scripts/verify-eks-cluster.sh
```

Or manually:
```bash
# Create a test pod
kubectl run nginx-test --image=nginx:latest --port=80

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/nginx-test --timeout=60s

# Check pod status
kubectl get pod nginx-test

# Should show: STATUS: Running

# Clean up test pod
kubectl delete pod nginx-test
```

### Step 4: Check Cluster Info

```bash
# Get cluster details
kubectl cluster-info

# Get all resources
kubectl get all --all-namespaces
```

---

## Troubleshooting

### Issue: AWS credentials not found
**Error:** `Unable to locate credentials`

**Solution:**
```bash
# Re-run AWS configure
aws configure

# Or check credentials file
cat ~/.aws/credentials
```

### Issue: Insufficient permissions
**Error:** `User is not authorized to perform: eks:CreateCluster`

**Solution:**
- Contact your AWS administrator
- Ensure your IAM user has EKS permissions
- Try with AdministratorAccess policy temporarily

### Issue: eksctl command not found
**Error:** `command not found: eksctl`

**Solution:**
```bash
# Verify installation
which eksctl

# If not found, reinstall eksctl
# Follow installation instructions above
```

### Issue: Cluster creation failed
**Error:** Various CloudFormation errors

**Solution:**
```bash
# Check eksctl logs
eksctl utils describe-stacks --region us-east-1 --cluster hello-dd

# Delete failed cluster
eksctl delete cluster --name hello-dd --region us-east-1

# Retry creation
./scripts/create-eks-cluster.sh
```

### Issue: Nodes not ready
**Error:** Nodes stuck in `NotReady` state

**Solution:**
```bash
# Describe node to see issues
kubectl describe node <node-name>

# Check node group status
eksctl get nodegroup --cluster hello-dd --region us-east-1

# If persistent, delete and recreate node group
eksctl delete nodegroup --cluster hello-dd --region us-east-1 --name standard-workers
eksctl create nodegroup --cluster hello-dd --region us-east-1 --name standard-workers --node-type t3.medium --nodes 2 --managed
```

### Issue: kubectl context not set
**Error:** `The connection to the server localhost:8080 was refused`

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name hello-dd --region us-east-1

# Verify context
kubectl config get-contexts
```

---

## Next Steps

After successful cluster creation:

1. **Deploy hello-dd services** - See deployment documentation
2. **Install Datadog Agent** - For APM monitoring
3. **Configure ingress** - Expose services externally
4. **Set up CI/CD** - Automate deployments

---

## Cleanup

When you're done testing, delete the cluster to avoid charges:

```bash
# Delete the cluster (removes all resources)
eksctl delete cluster --name hello-dd --region us-east-1

# This takes about 10-15 minutes
```

---

## Additional Resources

- [eksctl Documentation](https://eksctl.io/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Datadog EKS Monitoring](https://docs.datadoghq.com/containers/amazon_eks/)

---

**Questions or Issues?**
- Create an issue in the repository
- Check AWS CloudFormation console for detailed error messages
- Review CloudWatch Logs for EKS control plane logs
