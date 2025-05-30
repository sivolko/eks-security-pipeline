#!/bin/bash
# EKS Security Pipeline Deployment Script
# This script deploys the complete EKS security infrastructure

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed. You'll need it for container operations."
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_warning "Helm is not installed. Installing it now..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    print_status "Prerequisites check completed"
}

# Check AWS credentials
check_aws_credentials() {
    print_header "Checking AWS Credentials"
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
    
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "Current User: $CURRENT_USER"
}

# Estimate costs
estimate_costs() {
    print_header "Cost Estimation"
    
    print_status "Estimated monthly costs for this deployment:"
    echo "• EKS Cluster Control Plane: ~$73/month"
    echo "• Worker Nodes (3x m5.large): ~$207/month"
    echo "• NAT Gateways (3x): ~$99/month"
    echo "• Load Balancers: ~$18/month each"
    echo "• ECR Storage: ~$0.10/GB/month"
    echo "• Data Transfer: Variable"
    echo "• CloudWatch Logs: ~$0.50/GB ingested"
    echo ""
    echo -e "${YELLOW}Total Estimated Cost: ~$400-500/month${NC}"
    echo ""
    
    read -p "Do you want to continue with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    cd terraform
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your specific values"
        read -p "Press Enter to continue after editing terraform.tfvars..."
    fi
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying deployment..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    cd ..
}

# Configure kubectl
configure_kubectl() {
    print_header "Configuring kubectl"
    
    # Get cluster name from terraform output
    CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
    AWS_REGION=$(cd terraform && terraform output -json cluster_info | jq -r '.cluster_endpoint' | sed 's/.*\.//g' | sed 's/\..*//g')
    
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-west-2"  # fallback
    fi
    
    print_status "Configuring kubectl for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Verify connection
    print_status "Verifying cluster connection..."
    kubectl get nodes
    
    if [ $? -eq 0 ]; then
        print_status "Successfully connected to EKS cluster!"
    else
        print_error "Failed to connect to EKS cluster"
        exit 1
    fi
}

# Install essential add-ons
install_addons() {
    print_header "Installing Essential Add-ons"
    
    # Install AWS Load Balancer Controller
    print_status "Installing AWS Load Balancer Controller..."
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Create service account for AWS Load Balancer Controller
    kubectl apply -f https://raw.githubusercontent.com/aws/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json
    
    # Install the controller
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
    
    print_status "AWS Load Balancer Controller installed"
}

# Show deployment summary
show_summary() {
    print_header "Deployment Summary"
    
    cd terraform
    
    print_status "Terraform outputs:"
    terraform output
    
    print_status "Cluster access command:"
    terraform output -raw cluster_access
    
    print_status "Important URLs:"
    terraform output important_urls
    
    cd ..
    
    print_header "Next Steps"
    echo "1. Deploy security policies: kubectl apply -f security-policies/"
    echo "2. Deploy sample applications: kubectl apply -f k8s-manifests/"
    echo "3. Set up monitoring: kubectl apply -f monitoring/"
    echo "4. Test ECR scanning: docker build and push images"
    echo "5. Configure alerting: Subscribe to SNS topic for alerts"
    echo ""
    print_status "Deployment completed successfully!"
}

# Main execution
main() {
    print_header "EKS Security Pipeline Deployment"
    
    check_prerequisites
    check_aws_credentials
    estimate_costs
    deploy_infrastructure
    configure_kubectl
    install_addons
    show_summary
}

# Run main function
main "$@"
