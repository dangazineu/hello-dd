#!/bin/bash

# ECR Image Push Script for hello-dd project
# This script builds Docker images and pushes them to Amazon ECR
# Issue: #55

set -e  # Exit on error

# Configuration
REGION="us-east-1"
PROJECT_NAME="hello-dd"

# Service definitions (service-name:directory:port)
SERVICES=(
    "api-gateway:api-gateway:8000"
    "inventory-service:inventory-service:8001"
    "pricing-service:pricing-service:8002"
)

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
    print_step "Step 1/6: Validating Prerequisites"

    print_info "Checking required tools..."
    check_command aws
    check_command docker

    print_success "All required tools are installed"

    # Check AWS credentials
    print_info "Validating AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        echo "Please run 'aws configure' and try again."
        exit 1
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)

    print_success "AWS credentials are valid"
    print_info "AWS Account: $AWS_ACCOUNT_ID"
    print_info "AWS Identity: $AWS_USER"
    print_info "AWS Region: $REGION"
}

# Create ECR repositories
create_ecr_repositories() {
    print_step "Step 2/6: Creating ECR Repositories"

    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir service_port <<< "$service_info"
        repo_name="${PROJECT_NAME}/${service_name}"

        print_info "Checking repository: $repo_name"

        if aws ecr describe-repositories --repository-names "$repo_name" --region "$REGION" &> /dev/null; then
            print_success "Repository already exists: $repo_name"
        else
            print_info "Creating repository: $repo_name"
            if aws ecr create-repository \
                --repository-name "$repo_name" \
                --region "$REGION" \
                --image-scanning-configuration scanOnPush=true \
                --encryption-configuration encryptionType=AES256 \
                --output json > /dev/null; then
                print_success "Repository created: $repo_name"
            else
                print_error "Failed to create repository: $repo_name"
                exit 1
            fi
        fi
    done

    print_success "All ECR repositories are ready"
}

# Authenticate Docker to ECR
authenticate_docker() {
    print_step "Step 3/6: Authenticating Docker to ECR"

    print_info "Logging in to ECR..."

    if aws ecr get-login-password --region "$REGION" | \
        docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"; then
        print_success "Docker authenticated to ECR"
    else
        print_error "Failed to authenticate Docker to ECR"
        exit 1
    fi
}

# Build and push images
build_and_push_images() {
    print_step "Step 4/6: Building and Pushing Docker Images"

    # Get git commit SHA for tagging
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_COMMIT=$(git rev-parse --short HEAD)
    else
        GIT_COMMIT="local"
    fi

    print_info "Git commit SHA: $GIT_COMMIT"

    PUSHED_IMAGES=()

    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir service_port <<< "$service_info"

        # Check if service directory exists
        if [ ! -d "$service_dir" ]; then
            print_warning "Service directory not found: $service_dir - skipping"
            continue
        fi

        # Check if Dockerfile exists
        if [ ! -f "$service_dir/Dockerfile" ]; then
            print_warning "Dockerfile not found in $service_dir - skipping"
            continue
        fi

        repo_name="${PROJECT_NAME}/${service_name}"
        image_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${repo_name}"

        print_info "Building image for: $service_name"

        # Build Docker image
        if docker build -t "${service_name}:latest" "./${service_dir}"; then
            print_success "Image built: ${service_name}:latest"
        else
            print_error "Failed to build image: ${service_name}"
            continue
        fi

        # Tag with latest
        docker tag "${service_name}:latest" "${image_uri}:latest"
        # Tag with commit SHA
        docker tag "${service_name}:latest" "${image_uri}:${GIT_COMMIT}"

        print_info "Pushing image to ECR: $repo_name"

        # Push latest tag
        if docker push "${image_uri}:latest"; then
            print_success "Pushed: ${image_uri}:latest"
        else
            print_error "Failed to push: ${image_uri}:latest"
            continue
        fi

        # Push commit SHA tag
        if docker push "${image_uri}:${GIT_COMMIT}"; then
            print_success "Pushed: ${image_uri}:${GIT_COMMIT}"
        else
            print_warning "Failed to push commit SHA tag"
        fi

        PUSHED_IMAGES+=("${image_uri}:latest")
        PUSHED_IMAGES+=("${image_uri}:${GIT_COMMIT}")
    done

    if [ ${#PUSHED_IMAGES[@]} -eq 0 ]; then
        print_error "No images were pushed successfully"
        exit 1
    fi

    print_success "Image build and push complete"
}

# Verify images in ECR
verify_images() {
    print_step "Step 5/6: Verifying Images in ECR"

    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir service_port <<< "$service_info"

        if [ ! -d "$service_dir" ]; then
            continue
        fi

        repo_name="${PROJECT_NAME}/${service_name}"

        print_info "Checking images in: $repo_name"

        if aws ecr list-images --repository-name "$repo_name" --region "$REGION" --output json > /dev/null 2>&1; then
            IMAGE_COUNT=$(aws ecr list-images --repository-name "$repo_name" --region "$REGION" --query 'length(imageIds)' --output text)
            print_success "Repository $repo_name contains $IMAGE_COUNT image(s)"
        else
            print_warning "Could not verify images in $repo_name"
        fi
    done
}

# Display summary
display_summary() {
    print_step "Step 6/6: Summary"

    echo -e "${GREEN}Docker images pushed to ECR successfully!${NC}"
    echo ""
    echo "ECR Repository URLs:"
    echo ""

    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir service_port <<< "$service_info"

        if [ ! -d "$service_dir" ]; then
            continue
        fi

        repo_name="${PROJECT_NAME}/${service_name}"
        image_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${repo_name}"

        echo "  ${service_name}:"
        echo "    Latest: ${image_uri}:latest"
        echo "    Commit: ${image_uri}:${GIT_COMMIT}"
        echo ""
    done

    echo "View in AWS Console:"
    echo "  https://console.aws.amazon.com/ecr/repositories?region=${REGION}"
    echo ""
    echo "Pull an image:"
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir service_port <<< "$service_info"

        if [ ! -d "$service_dir" ]; then
            continue
        fi

        repo_name="${PROJECT_NAME}/${service_name}"
        image_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${repo_name}"

        echo "  docker pull ${image_uri}:latest"
        break  # Just show one example
    done

    echo ""
    echo "Next Steps:"
    echo "  1. Create Kubernetes deployment manifests using these image URIs"
    echo "  2. Deploy to EKS: kubectl apply -f k8s/"
    echo "  3. Verify pods are running: kubectl get pods"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  ECR Image Push - hello-dd"
    echo "  Issue: #55"
    echo "=========================================="
    echo ""

    validate_prerequisites
    create_ecr_repositories
    authenticate_docker
    build_and_push_images
    verify_images
    display_summary
}

# Run main function
main
