#!/bin/bash

# Deploy Services to EKS Script for hello-dd project
# This script deploys Kubernetes manifests to EKS cluster
# Issue: #56

set -e  # Exit on error

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
        exit 1
    fi
}

# Validate prerequisites
validate_prerequisites() {
    print_step "Step 1/5: Validating Prerequisites"

    print_info "Checking required tools..."
    check_command kubectl

    print_success "All required tools are installed"

    # Check kubectl can connect to cluster
    print_info "Validating Kubernetes cluster connection..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        echo "Please ensure kubectl is configured correctly."
        echo "Try: kubectl config get-contexts"
        exit 1
    fi

    CURRENT_CONTEXT=$(kubectl config current-context)
    print_success "Connected to Kubernetes cluster"
    print_info "Current context: $CURRENT_CONTEXT"
}

# Deploy manifests
deploy_manifests() {
    print_step "Step 2/5: Deploying Kubernetes Manifests"

    # Check if k8s directory exists
    if [ ! -d "k8s" ]; then
        print_error "k8s directory not found"
        echo "Please run this script from the project root directory"
        exit 1
    fi

    # Deploy API Gateway
    if [ -f "k8s/api-gateway.yaml" ]; then
        print_info "Deploying API Gateway..."
        kubectl apply -f k8s/api-gateway.yaml
        print_success "API Gateway manifest applied"
    else
        print_warning "k8s/api-gateway.yaml not found, skipping"
    fi

    # Deploy other services if they exist
    for service in inventory-service pricing-service; do
        manifest="k8s/${service}.yaml"
        if [ -f "$manifest" ]; then
            print_info "Deploying $service..."
            kubectl apply -f "$manifest"
            print_success "$service manifest applied"
        else
            print_warning "$manifest not found, skipping"
        fi
    done
}

# Wait for pods to be ready
wait_for_pods() {
    print_step "Step 3/5: Waiting for Pods to be Ready"

    print_info "Waiting for API Gateway pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=api-gateway --timeout=120s || {
        print_warning "Some pods may not be ready yet"
        kubectl get pods -l app=api-gateway
    }

    print_info "Current pod status:"
    kubectl get pods -l app=api-gateway
}

# Wait for LoadBalancer
wait_for_loadbalancer() {
    print_step "Step 4/5: Waiting for LoadBalancer"

    print_info "Waiting for LoadBalancer external IP/hostname..."
    print_info "This can take 2-3 minutes..."

    for i in {1..30}; do
        LB_HOSTNAME=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

        if [ -n "$LB_HOSTNAME" ]; then
            print_success "LoadBalancer provisioned: $LB_HOSTNAME"
            break
        fi

        echo -n "."
        sleep 10
    done

    echo ""

    if [ -z "$LB_HOSTNAME" ]; then
        print_warning "LoadBalancer not yet available"
        print_info "Check status with: kubectl get service api-gateway"
        return 1
    fi
}

# Test deployment
test_deployment() {
    print_step "Step 5/5: Testing Deployment"

    LB_HOSTNAME=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -z "$LB_HOSTNAME" ]; then
        print_warning "LoadBalancer not yet available, skipping tests"
        return 0
    fi

    print_info "Testing API Gateway endpoints..."
    print_info "LoadBalancer URL: http://$LB_HOSTNAME"

    # Wait a moment for DNS propagation
    sleep 10

    # Test health endpoint
    print_info "Testing /health endpoint..."
    if curl -s -f -m 10 "http://$LB_HOSTNAME/health" > /dev/null; then
        print_success "Health check passed"
        curl -s "http://$LB_HOSTNAME/health"
    else
        print_warning "Health check failed or timed out"
        print_info "LoadBalancer may still be initializing"
    fi
}

# Display summary
display_summary() {
    print_step "Deployment Complete!"

    echo -e "${GREEN}Services deployed successfully!${NC}"
    echo ""

    print_info "Deployed Services:"
    kubectl get deployments
    echo ""

    print_info "Services:"
    kubectl get services
    echo ""

    print_info "Pods:"
    kubectl get pods
    echo ""

    LB_HOSTNAME=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -n "$LB_HOSTNAME" ]; then
        echo "API Gateway URL: http://$LB_HOSTNAME"
        echo ""
        echo "Test endpoints:"
        echo "  Health:   curl http://$LB_HOSTNAME/health"
        echo "  Root:     curl http://$LB_HOSTNAME/"
        echo "  Products: curl http://$LB_HOSTNAME/products?limit=5"
        echo "  Order:    curl -X POST 'http://$LB_HOSTNAME/order?product_id=TEST&quantity=1'"
    else
        echo "LoadBalancer URL: (still provisioning)"
        echo "Get URL with: kubectl get service api-gateway"
    fi

    echo ""
    echo "Useful Commands:"
    echo "  View pods:    kubectl get pods"
    echo "  View logs:    kubectl logs -l app=api-gateway --tail=100 -f"
    echo "  Describe pod: kubectl describe pod <pod-name>"
    echo "  Scale up:     kubectl scale deployment api-gateway --replicas=3"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Deploy to EKS - hello-dd"
    echo "  Issue: #56"
    echo "=========================================="
    echo ""

    validate_prerequisites
    deploy_manifests
    wait_for_pods
    wait_for_loadbalancer
    test_deployment
    display_summary
}

# Run main function
main
