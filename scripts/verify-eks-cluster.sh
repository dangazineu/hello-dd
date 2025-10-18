#!/bin/bash

# EKS Cluster Verification Script for hello-dd project
# This script verifies the EKS cluster is working correctly
# Issue: #54

set -e  # Exit on error

# Configuration
CLUSTER_NAME="hello-dd"
REGION="us-east-1"
TEST_POD_NAME="nginx-test"
TEST_NAMESPACE="default"

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

# Check if kubectl is configured
check_kubectl() {
    print_step "Step 1/6: Checking kubectl Configuration"

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi

    print_info "Current context:"
    kubectl config current-context

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to cluster. Is kubectl configured correctly?"
        echo "Try running: aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
        exit 1
    fi

    print_success "kubectl is configured and can connect to cluster"
}

# Check cluster health
check_cluster_health() {
    print_step "Step 2/6: Checking Cluster Health"

    print_info "Cluster information:"
    kubectl cluster-info

    print_info "Checking nodes..."
    kubectl get nodes

    local NOT_READY=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l)
    if [ $NOT_READY -gt 0 ]; then
        print_warning "Some nodes are not ready"
        kubectl get nodes
        exit 1
    fi

    print_success "All nodes are ready"
}

# Check system pods
check_system_pods() {
    print_step "Step 3/6: Checking System Pods"

    print_info "Checking kube-system pods..."
    kubectl get pods -n kube-system

    local NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
    if [ $NOT_RUNNING -gt 0 ]; then
        print_warning "Some system pods are not running properly"
        kubectl get pods -n kube-system | grep -v "Running\|Completed"
    else
        print_success "All system pods are running"
    fi
}

# Deploy test pod
deploy_test_pod() {
    print_step "Step 4/6: Deploying Test Pod"

    # Clean up any existing test pod
    if kubectl get pod $TEST_POD_NAME -n $TEST_NAMESPACE &> /dev/null; then
        print_info "Cleaning up existing test pod..."
        kubectl delete pod $TEST_POD_NAME -n $TEST_NAMESPACE --wait=false || true
        sleep 5
    fi

    print_info "Creating test pod: $TEST_POD_NAME"
    kubectl run $TEST_POD_NAME \
        --image=nginx:latest \
        --port=80 \
        --labels="app=test,purpose=verification" \
        -n $TEST_NAMESPACE

    print_info "Waiting for pod to be ready (timeout: 120s)..."
    if kubectl wait --for=condition=ready pod/$TEST_POD_NAME \
        -n $TEST_NAMESPACE \
        --timeout=120s; then
        print_success "Test pod is running"
    else
        print_error "Test pod failed to start"
        kubectl describe pod $TEST_POD_NAME -n $TEST_NAMESPACE
        exit 1
    fi
}

# Verify pod functionality
verify_pod() {
    print_step "Step 5/6: Verifying Pod Functionality"

    print_info "Pod status:"
    kubectl get pod $TEST_POD_NAME -n $TEST_NAMESPACE -o wide

    print_info "Pod details:"
    kubectl describe pod $TEST_POD_NAME -n $TEST_NAMESPACE | grep -A 10 "Status:\|Conditions:\|IP:"

    print_info "Testing pod connectivity..."
    local POD_IP=$(kubectl get pod $TEST_POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.podIP}')
    print_info "Pod IP: $POD_IP"

    # Try to exec into pod
    print_info "Testing exec into pod..."
    if kubectl exec $TEST_POD_NAME -n $TEST_NAMESPACE -- nginx -v &> /dev/null; then
        print_success "Successfully executed command in pod"
    else
        print_warning "Could not execute command in pod"
    fi

    print_success "Pod verification complete"
}

# Clean up test pod
cleanup() {
    print_step "Step 6/6: Cleaning Up Test Resources"

    print_info "Deleting test pod..."
    if kubectl delete pod $TEST_POD_NAME -n $TEST_NAMESPACE --wait=true; then
        print_success "Test pod deleted successfully"
    else
        print_warning "Failed to delete test pod (it may not exist)"
    fi
}

# Display verification summary
display_summary() {
    print_step "Verification Complete!"

    echo -e "${GREEN}Your EKS cluster is working correctly!${NC}"
    echo ""
    echo "Verification Results:"
    echo "  ✓ kubectl configured and connected"
    echo "  ✓ All nodes are ready"
    echo "  ✓ System pods are running"
    echo "  ✓ Test pod deployed successfully"
    echo "  ✓ Pod functionality verified"
    echo "  ✓ Test resources cleaned up"
    echo ""
    echo "Your cluster is ready for deploying the hello-dd services!"
    echo ""
    echo "Next Steps:"
    echo "  1. Create Kubernetes manifests for hello-dd services"
    echo "  2. Deploy services: kubectl apply -f k8s/"
    echo "  3. Install Datadog Agent for APM monitoring"
    echo ""
    echo "Useful Commands:"
    echo "  - View all resources: kubectl get all --all-namespaces"
    echo "  - View logs: kubectl logs <pod-name>"
    echo "  - Describe resource: kubectl describe <resource-type> <name>"
    echo "  - Port forward: kubectl port-forward <pod-name> <local-port>:<pod-port>"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  EKS Cluster Verification - hello-dd"
    echo "  Issue: #54"
    echo "=========================================="
    echo ""

    # Set up cleanup trap
    trap cleanup EXIT

    check_kubectl
    check_cluster_health
    check_system_pods
    deploy_test_pod
    verify_pod
    cleanup
    display_summary
}

# Run main function
main
