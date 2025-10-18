#!/bin/bash

# EKS Cluster Creation Script for hello-dd project
# This script creates a minimal EKS cluster for APM testing
# Issue: #54

set -e  # Exit on error

# Configuration
CLUSTER_NAME="hello-dd"
REGION="us-east-1"
NODE_TYPE="t3.medium"
NODE_COUNT=2
NODEGROUP_NAME="standard-workers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        echo "Please install $1 and try again."
        echo "See docs/EKS_SETUP_GUIDE.md for installation instructions."
        exit 1
    fi
}

# Validate prerequisites
validate_prerequisites() {
    print_step "Step 1/5: Validating Prerequisites"

    print_info "Checking required tools..."
    check_command aws
    check_command eksctl
    check_command kubectl

    print_success "All required tools are installed"

    # Check AWS credentials
    print_info "Validating AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        echo "Please run 'aws configure' and try again."
        echo "See docs/EKS_SETUP_GUIDE.md for configuration instructions."
        exit 1
    fi

    local AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    local AWS_USER=$(aws sts get-caller-identity --query Arn --output text)

    print_success "AWS credentials are valid"
    print_info "AWS Account: $AWS_ACCOUNT"
    print_info "AWS Identity: $AWS_USER"
}

# Check if cluster already exists
check_existing_cluster() {
    print_step "Step 2/5: Checking for Existing Cluster"

    if eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster '$CLUSTER_NAME' already exists in region $REGION"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing cluster..."
            eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait
            print_success "Existing cluster deleted"
        else
            print_info "Using existing cluster"
            return 0
        fi
    else
        print_success "No existing cluster found. Ready to create new cluster."
    fi
}

# Create EKS cluster
create_cluster() {
    print_step "Step 3/5: Creating EKS Cluster"

    print_info "Cluster configuration:"
    echo "  Name: $CLUSTER_NAME"
    echo "  Region: $REGION"
    echo "  Node Type: $NODE_TYPE"
    echo "  Node Count: $NODE_COUNT"
    echo "  Nodegroup Name: $NODEGROUP_NAME"
    echo ""

    print_warning "This process will take approximately 15-20 minutes"
    print_warning "Estimated cost: ~\$0.20/hour (~\$150/month if left running)"
    echo ""

    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cluster creation cancelled"
        exit 0
    fi

    print_info "Creating EKS cluster..."
    print_info "You can monitor progress in the AWS Console: CloudFormation"
    echo ""

    if eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name $NODEGROUP_NAME \
        --node-type $NODE_TYPE \
        --nodes $NODE_COUNT \
        --managed; then
        print_success "EKS cluster created successfully"
    else
        print_error "Failed to create EKS cluster"
        echo "Check CloudFormation console for detailed error messages"
        exit 1
    fi
}

# Configure kubectl
configure_kubectl() {
    print_step "Step 4/5: Configuring kubectl"

    print_info "Updating kubeconfig..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

    print_info "Current kubectl context:"
    kubectl config current-context

    print_success "kubectl configured successfully"
}

# Verify cluster
verify_cluster() {
    print_step "Step 5/5: Verifying Cluster"

    print_info "Waiting for nodes to be ready..."
    sleep 10

    print_info "Cluster nodes:"
    kubectl get nodes

    print_info "Cluster info:"
    kubectl cluster-info

    print_info "All namespaces:"
    kubectl get all --all-namespaces

    print_success "Cluster verification complete"
}

# Display next steps
display_next_steps() {
    print_step "Cluster Creation Complete!"

    echo -e "${GREEN}Your EKS cluster is ready!${NC}"
    echo ""
    echo "Cluster Details:"
    echo "  Name: $CLUSTER_NAME"
    echo "  Region: $REGION"
    echo "  Endpoint: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo ""
    echo "Next Steps:"
    echo "  1. Deploy a test pod:"
    echo "     ./scripts/verify-eks-cluster.sh"
    echo ""
    echo "  2. Deploy hello-dd services:"
    echo "     kubectl apply -f k8s/"
    echo ""
    echo "  3. Install Datadog Agent for APM monitoring"
    echo ""
    echo "Useful Commands:"
    echo "  - View nodes: kubectl get nodes"
    echo "  - View all resources: kubectl get all --all-namespaces"
    echo "  - Access AWS Console: https://console.aws.amazon.com/eks/home?region=$REGION#/clusters/$CLUSTER_NAME"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Don't forget to delete the cluster when done to avoid charges:${NC}"
    echo "  eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  EKS Cluster Creation - hello-dd"
    echo "  Issue: #54"
    echo "=========================================="
    echo ""

    validate_prerequisites
    check_existing_cluster
    create_cluster
    configure_kubectl
    verify_cluster
    display_next_steps
}

# Run main function
main
