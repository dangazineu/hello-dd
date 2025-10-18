#!/bin/bash

# Verify Deployment Script for hello-dd project
# This script verifies deployed services on EKS using curl
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

# Get LoadBalancer URL
get_loadbalancer_url() {
    print_step "Step 1/3: Getting LoadBalancer URL"

    check_command kubectl

    print_info "Fetching API Gateway LoadBalancer URL..."
    LB_URL=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -z "$LB_URL" ]; then
        print_error "LoadBalancer URL not found"
        echo "Make sure the service is deployed:"
        echo "  kubectl get service api-gateway"
        exit 1
    fi

    print_success "LoadBalancer URL: $LB_URL"
    echo ""
}

# Test endpoint
test_endpoint() {
    local method=$1
    local path=$2
    local description=$3
    local expected_status=${4:-200}

    print_info "Testing: $description"
    print_info "  Method: $method"
    print_info "  Path: $path"

    local url="http://${LB_URL}${path}"

    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$url" 2>&1)
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$url" 2>&1)
    else
        print_error "Unknown method: $method"
        return 1
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "$expected_status" ]; then
        print_success "Status: $http_code ✓"
        echo "Response:"
        echo "$body" | head -c 500
        if [ ${#body} -gt 500 ]; then
            echo "... (truncated)"
        fi
        echo ""
        return 0
    else
        print_error "Status: $http_code (expected $expected_status) ✗"
        echo "Response:"
        echo "$body"
        echo ""
        return 1
    fi
}

# Run all tests
run_tests() {
    print_step "Step 2/3: Running API Tests"

    local passed=0
    local failed=0

    # Test 1: Root endpoint
    if test_endpoint "GET" "/" "Root endpoint"; then
        ((passed++))
    else
        ((failed++))
    fi

    # Test 2: Health endpoint
    if test_endpoint "GET" "/health" "Health check"; then
        ((passed++))
    else
        ((failed++))
    fi

    # Test 3: Products endpoint
    if test_endpoint "GET" "/products?limit=3" "Products list"; then
        ((passed++))
    else
        ((failed++))
    fi

    # Test 4: Order creation
    if test_endpoint "POST" "/order?product_id=TEST-001&quantity=2" "Order creation"; then
        ((passed++))
    else
        ((failed++))
    fi

    # Test 5: HTTP call to external service
    if test_endpoint "GET" "/test-http/external" "External HTTP call"; then
        ((passed++))
    else
        ((failed++))
    fi

    # Test 6: Error handling (404)
    if test_endpoint "GET" "/error-test/404" "Error handling (404)" "404"; then
        ((passed++))
    else
        ((failed++))
    fi

    print_step "Test Results Summary"

    echo -e "${GREEN}Passed: $passed${NC}"
    echo -e "${RED}Failed: $failed${NC}"
    echo ""

    if [ $failed -eq 0 ]; then
        print_success "All tests passed! ✓"
        TEST_RESULT=0
    else
        print_warning "$failed test(s) failed"
        TEST_RESULT=1
    fi
}

# Display service info
display_service_info() {
    print_step "Step 3/3: Service Information"

    print_info "Kubernetes resources:"
    kubectl get all -l app=api-gateway

    echo ""
    print_info "Service URL: http://${LB_URL}"
    echo ""
    print_info "Manual test commands:"
    echo "  curl http://${LB_URL}/health"
    echo "  curl http://${LB_URL}/products?limit=5"
    echo "  curl -X POST 'http://${LB_URL}/order?product_id=TEST&quantity=1'"
    echo ""
    print_info "View logs:"
    echo "  kubectl logs -l app=api-gateway --tail=100 -f"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Verify Deployment - hello-dd"
    echo "  Issue: #56"
    echo "=========================================="
    echo ""

    check_command curl

    get_loadbalancer_url
    run_tests
    display_service_info

    if [ $TEST_RESULT -eq 0 ]; then
        print_success "Deployment verification complete - all tests passed!"
        exit 0
    else
        print_warning "Deployment verification complete - some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
