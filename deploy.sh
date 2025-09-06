#!/bin/bash

# Gender Classification API - Unified Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="238295645671"
ECR_REPOSITORY="gender-classifier"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$PROJECT_ROOT/api"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure'."
        exit 1
    fi
    
    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Creating from example..."
        cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
        log_warning "Please edit terraform/terraform.tfvars with your actual values"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

build_and_push_image() {
    log_info "Building and pushing Docker image..."
    
    cd "$API_DIR"
    
    # Build Docker image
    log_info "Building Docker image..."
    docker build -t $ECR_REPOSITORY .
    
    # Login to ECR
    log_info "Logging into Amazon ECR..."
    aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin \
        $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Create ECR repository if it doesn't exist
    log_info "Creating ECR repository if it doesn't exist..."
    aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION || \
        aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    
    # Tag and push image
    log_info "Tagging and pushing image..."
    docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    
    log_success "Docker image built and pushed successfully!"
    
    # Update terraform.tfvars with the image URI
    IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"
    log_info "Updating terraform.tfvars with image URI..."
    
    # Update image_uri in terraform.tfvars
    cd "$TERRAFORM_DIR"
    sed -i.bak "s|image_uri.*=.*|image_uri = \"$IMAGE_URI\"|g" terraform.tfvars
    
    log_success "Updated terraform.tfvars with image URI: $IMAGE_URI"
}

terraform_plan() {
    log_info "Creating Terraform execution plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Create plan
    log_info "Generating execution plan..."
    terraform plan -out=tfplan
    
    log_success "Terraform plan created successfully!"
    log_info "Plan saved to: $TERRAFORM_DIR/tfplan"
    echo ""
    log_info "To apply this plan, run: ./deploy.sh apply"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log_info "Creating Terraform execution plan..."
    terraform plan -out=tfplan
    
    # Apply deployment
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully!"
}

apply_terraform_plan() {
    log_info "Applying existing Terraform plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if plan file exists
    if [ ! -f "tfplan" ]; then
        log_error "No terraform plan found. Please run './deploy.sh plan' first."
        exit 1
    fi
    
    # Apply the plan
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully!"
}

show_outputs() {
    log_info "Retrieving deployment information..."
    cd "$TERRAFORM_DIR"
    
    echo ""
    echo "=== Deployment Outputs ==="
    terraform output
    echo ""
    
    # Get the load balancer URL
    ALB_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "Not available")
    
    if [ "$ALB_URL" != "Not available" ]; then
        log_success "Application URL: $ALB_URL"
        log_info "Health check: $ALB_URL/health"
        log_info "API documentation: $ALB_URL/docs"
        echo ""
        log_info "Testing the deployment..."
        echo "curl $ALB_URL/health"
    fi
}

destroy_infrastructure() {
    log_warning "This will destroy all infrastructure and delete the ECR repository!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        log_info "Destroying infrastructure..."
        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve
        
        log_info "Deleting ECR repository..."
        aws ecr delete-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION --force || true
        
        log_success "Infrastructure destroyed"
    else
        log_info "Destroy cancelled"
        exit 0
    fi
}

show_help() {
    echo "Gender Classification API - Unified Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy        Full deployment (build image + deploy infrastructure)"
    echo "  build         Build and push Docker image only"
    echo "  infrastructure Deploy infrastructure only (assumes image exists)"
    echo "  plan          Create Terraform execution plan (review changes before applying)"
    echo "  apply         Apply existing Terraform plan"
    echo "  outputs       Show deployment outputs"
    echo "  destroy       Destroy all infrastructure"
    echo "  help          Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker installed"
    echo "  - Terraform installed"
    echo "  - AWS CLI installed and configured"
    echo "  - terraform/terraform.tfvars file configured"
    echo ""
    echo "Full deployment process:"
    echo "  1. Builds Docker image"
    echo "  2. Pushes to ECR"
    echo "  3. Updates terraform.tfvars with image URI"
    echo "  4. Deploys infrastructure with Terraform"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        log_info "Starting full deployment..."
        check_prerequisites
        build_and_push_image
        deploy_infrastructure
        show_outputs
        ;;
    "build")
        log_info "Building and pushing Docker image..."
        check_prerequisites
        build_and_push_image
        ;;
    "infrastructure")
        log_info "Deploying infrastructure only..."
        check_prerequisites
        deploy_infrastructure
        show_outputs
        ;;
    "plan")
        log_info "Creating Terraform execution plan..."
        check_prerequisites
        terraform_plan
        ;;
    "apply")
        log_info "Applying existing Terraform plan..."
        check_prerequisites
        apply_terraform_plan
        show_outputs
        ;;
    "outputs")
        show_outputs
        ;;
    "destroy")
        destroy_infrastructure
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

log_success "Script completed successfully!"