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
UI_DIR="$PROJECT_ROOT/ui"

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

check_ui_prerequisites() {
    log_info "Checking UI prerequisites..."
    
    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed. Please install Node.js and npm first."
        exit 1
    fi
    
    # Check if UI directory exists
    if [ ! -d "$UI_DIR" ]; then
        log_error "UI directory not found at $UI_DIR"
        exit 1
    fi
    
    # Check if package.json exists
    if [ ! -f "$UI_DIR/package.json" ]; then
        log_error "package.json not found in UI directory"
        exit 1
    fi
    
    log_success "UI prerequisites check passed"
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

build_ui() {
    log_info "Building React UI..."
    
    cd "$UI_DIR"
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        log_info "Installing UI dependencies..."
        npm install
    fi
    
    # Build for production
    log_info "Building UI for production..."
    npm run build:prod
    
    log_success "UI built successfully!"
    log_info "Build output in: $UI_DIR/build/"
}

deploy_ui_to_s3() {
    log_info "Deploying UI to S3..."
    
    # Try to get bucket name from Terraform outputs if not set
    if [ -z "$S3_BUCKET_UI" ]; then
        log_info "S3_BUCKET_UI not set, trying to get from Terraform outputs..."
        cd "$TERRAFORM_DIR"
        if [ -f "terraform.tfstate" ]; then
            S3_BUCKET_UI=$(terraform output -raw ui_bucket_name 2>/dev/null || echo "")
            if [ -n "$S3_BUCKET_UI" ]; then
                log_info "Using Terraform-managed S3 bucket: $S3_BUCKET_UI"
            fi
        fi
        cd "$PROJECT_ROOT"
    fi
    
    if [ -z "$S3_BUCKET_UI" ]; then
        log_error "S3_BUCKET_UI environment variable not set and no Terraform state found"
        log_info "Option 1: Set manually: S3_BUCKET_UI=my-bucket ./deploy.sh deploy-ui"
        log_info "Option 2: Deploy infrastructure first: ./deploy.sh deploy"
        exit 1
    fi
    
    # Try to get CloudFront distribution ID from Terraform if not set
    if [ -z "$CLOUDFRONT_ID" ]; then
        cd "$TERRAFORM_DIR"
        if [ -f "terraform.tfstate" ]; then
            CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
            if [ -n "$CLOUDFRONT_ID" ]; then
                log_info "Using Terraform-managed CloudFront distribution: $CLOUDFRONT_ID"
            fi
        fi
        cd "$PROJECT_ROOT"
    fi
    
    cd "$UI_DIR"
    
    if [ ! -d "build" ]; then
        log_error "No build directory found. Building first..."
        build_ui
    fi
    
    # Determine S3 destination path
    local s3_destination="s3://$S3_BUCKET_UI/"
    if [ -n "$S3_UI_PREFIX" ]; then
        s3_destination="s3://$S3_BUCKET_UI/$S3_UI_PREFIX"
        log_info "Uploading to S3 bucket: $S3_BUCKET_UI in folder: $S3_UI_PREFIX"
    else
        log_info "Uploading to S3 bucket: $S3_BUCKET_UI (root)"
    fi
    
    # Sync files to S3
    aws s3 sync build/ "$s3_destination" --delete
    
    # Set proper content types with prefix support
    log_info "Setting proper content types..."
    aws s3 cp "$s3_destination" "$s3_destination" --recursive \
        --exclude "*" --include "*.html" --content-type "text/html" \
        --metadata-directive REPLACE
    
    aws s3 cp "$s3_destination" "$s3_destination" --recursive \
        --exclude "*" --include "*.js" --content-type "application/javascript" \
        --metadata-directive REPLACE
    
    aws s3 cp "$s3_destination" "$s3_destination" --recursive \
        --exclude "*" --include "*.css" --content-type "text/css" \
        --metadata-directive REPLACE
    
    # Invalidate CloudFront if distribution ID provided
    if [ -n "$CLOUDFRONT_ID" ]; then
        local invalidation_paths="${CLOUDFRONT_PATHS:-/*}"
        if [ -n "$S3_UI_PREFIX" ] && [ "$invalidation_paths" = "/*" ]; then
            invalidation_paths="/$S3_UI_PREFIX*"
        fi
        
        log_info "Invalidating CloudFront distribution: $CLOUDFRONT_ID"
        log_info "Invalidation paths: $invalidation_paths"
        aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "$invalidation_paths"
        log_info "CloudFront invalidation started"
    fi
    
    log_success "UI deployment completed!"
    
    # Show access URLs
    if [ -n "$CLOUDFRONT_ID" ]; then
        # Try to get CloudFront domain from Terraform
        cd "$TERRAFORM_DIR"
        CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")
        cd "$PROJECT_ROOT"
        
        if [ -n "$CLOUDFRONT_DOMAIN" ]; then
            log_success "🌐 Your UI is available at: https://$CLOUDFRONT_DOMAIN"
            log_info "CloudFront distribution ID: $CLOUDFRONT_ID"
        else
            log_info "CloudFront distribution: $CLOUDFRONT_ID"
            log_info "UI will be available at your CloudFront URL (check AWS console)"
        fi
        
        if [ -n "$S3_UI_PREFIX" ]; then
            log_info "S3 folder: $S3_UI_PREFIX"
        fi
    else
        if [ -n "$S3_UI_PREFIX" ]; then
            log_info "Your UI is available at: https://$S3_BUCKET_UI.s3-website-$AWS_REGION.amazonaws.com/$S3_UI_PREFIX"
        else
            log_info "Your UI is available at: https://$S3_BUCKET_UI.s3-website-$AWS_REGION.amazonaws.com"
        fi
    fi
}

serve_ui_locally() {
    log_info "Serving UI locally..."
    cd "$UI_DIR"
    
    if [ ! -d "build" ]; then
        log_error "No build directory found. Building first..."
        build_ui
    fi
    
    log_info "Starting local server at http://localhost:3000"
    log_info "Press Ctrl+C to stop"
    npx serve -s build -l 3000
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
    echo "Infrastructure Commands:"
    echo "  deploy        Full deployment (build image + deploy infrastructure)"
    echo "  build         Build and push Docker image only"
    echo "  infrastructure Deploy infrastructure only (assumes image exists)"
    echo "  plan          Create Terraform execution plan (review changes before applying)"
    echo "  apply         Apply existing Terraform plan"
    echo "  outputs       Show deployment outputs"
    echo "  destroy       Destroy all infrastructure"
    echo ""
    echo "UI Commands:"
    echo "  build-ui      Build React UI for production"
    echo "  deploy-ui     Deploy UI to S3 (requires S3_BUCKET_UI env var)"
    echo "  serve-ui      Serve UI build locally on port 3000"
    echo ""
    echo "General:"
    echo "  help          Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker installed (for API deployment)"
    echo "  - Terraform installed (for infrastructure)"
    echo "  - AWS CLI installed and configured"
    echo "  - Node.js and npm installed (for UI)"
    echo "  - terraform/terraform.tfvars file configured"
    echo ""
    echo "UI Deployment Configuration:"
    echo "  1. Edit deploy-config.env with your settings (one-time setup)"
    echo "  2. Run: ./deploy.sh deploy-ui"
    echo "  Note: Config file is automatically loaded if it exists"
    echo ""
    echo "  Config file settings:"
    echo "    S3_BUCKET_UI      - S3 bucket name for UI hosting"
    echo "    S3_UI_PREFIX      - S3 folder path (optional, e.g., 'ui/')"
    echo "    CLOUDFRONT_ID     - CloudFront distribution ID (optional)"
    echo ""
    echo "Examples:"
    echo "  # API deployment"
    echo "  ./deploy.sh deploy                           # Deploy API infrastructure"
    echo "  ./deploy.sh build-ui                         # Build UI only"
    echo ""
    echo "  # UI deployment (uses deploy-config.env automatically)"
    echo "  ./deploy.sh deploy-ui                        # Deploy UI to configured S3 bucket"
    echo ""
    echo "  # Manual override (if needed)"
    echo "  S3_BUCKET_UI=my-bucket ./deploy.sh deploy-ui # Override config file"
}

# Auto-load configuration file if it exists
CONFIG_FILE="$PROJECT_ROOT/deploy-config.env"
if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading configuration from deploy-config.env..."
    source "$CONFIG_FILE"
fi

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
    "build-ui")
        log_info "Building React UI..."
        check_ui_prerequisites
        build_ui
        ;;
    "deploy-ui")
        log_info "Deploying React UI to S3..."
        check_ui_prerequisites
        deploy_ui_to_s3
        ;;
    "serve-ui")
        log_info "Serving UI locally..."
        check_ui_prerequisites
        serve_ui_locally
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