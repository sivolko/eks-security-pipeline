#!/bin/bash
# EKS Security Pipeline Cleanup Script
# This script safely destroys all created resources

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

# Confirm cleanup
confirm_cleanup() {
    print_header "EKS Security Pipeline Cleanup"
    
    echo "This script will destroy ALL resources created by the EKS security pipeline:"
    echo "• EKS Cluster and worker nodes"
    echo "• VPC, subnets, and networking components"
    echo "• ECR repositories and images"
    echo "• Lambda functions and SNS topics"
    echo "• KMS keys and IAM roles"
    echo "• CloudWatch log groups"
    echo ""
    print_warning "THIS ACTION CANNOT BE UNDONE!"
    echo ""
    
    read -p "Are you absolutely sure you want to continue? Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
}

# Check if cluster exists
check_cluster_exists() {
    print_header "Checking Cluster Status"
    
    cd terraform
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No terraform state found. Nothing to destroy."
        exit 0
    fi
    
    # Try to get cluster name
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    
    if [ -n "$CLUSTER_NAME" ]; then
        print_status "Found cluster: $CLUSTER_NAME"
    else
        print_warning "Cluster name not found in terraform output"
    fi
    
    cd ..
}

# Clean up Kubernetes resources
cleanup_k8s_resources() {
    print_header "Cleaning Up Kubernetes Resources"
    
    if [ -n "$CLUSTER_NAME" ]; then
        print_status "Deleting all deployed applications..."
        
        # Delete all Load Balancers (to avoid terraform destroy issues)
        kubectl delete svc --all-namespaces --selector="service.beta.kubernetes.io/aws-load-balancer-type" --ignore-not-found=true
        
        # Delete AWS Load Balancer Controller
        helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found
        
        # Delete any remaining ingresses
        kubectl delete ingress --all-namespaces --all --ignore-not-found=true
        
        # Wait for load balancers to be deleted
        print_status "Waiting for AWS resources to be cleaned up..."
        sleep 30
        
        print_status "Kubernetes resources cleaned up"
    else
        print_warning "Skipping Kubernetes cleanup - cluster not accessible"
    fi
}

# Empty ECR repositories
empty_ecr_repositories() {
    print_header "Emptying ECR Repositories"
    
    cd terraform
    
    # Get ECR repository names
    ECR_REPOS=$(terraform output -json ecr_repositories 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "")
    
    if [ -n "$ECR_REPOS" ]; then
        for repo in $ECR_REPOS; do
            REPO_NAME=$(terraform output -json ecr_repositories | jq -r ".[\"$repo\"].name" 2>/dev/null || echo "")
            if [ -n "$REPO_NAME" ]; then
                print_status "Emptying ECR repository: $REPO_NAME"
                
                # Get all image tags
                IMAGE_TAGS=$(aws ecr list-images --repository-name "$REPO_NAME" --query 'imageIds[*].imageTag' --output text 2>/dev/null || echo "")
                
                if [ -n "$IMAGE_TAGS" ] && [ "$IMAGE_TAGS" != "None" ]; then
                    # Delete all images
                    aws ecr batch-delete-image --repository-name "$REPO_NAME" --image-ids imageTag="$IMAGE_TAGS" >/dev/null 2>&1 || true
                fi
                
                print_status "ECR repository $REPO_NAME emptied"
            fi
        done
    else
        print_warning "No ECR repositories found to clean up"
    fi
    
    cd ..
}

# Run terraform destroy
terraform_destroy() {
    print_header "Destroying Infrastructure with Terraform"
    
    cd terraform
    
    print_status "Running terraform destroy..."
    
    # First attempt - normal destroy
    if terraform destroy -auto-approve; then
        print_status "Terraform destroy completed successfully"
    else
        print_warning "First terraform destroy attempt failed. Trying again..."
        
        # Second attempt - force destroy
        sleep 10
        if terraform destroy -auto-approve; then
            print_status "Terraform destroy completed on second attempt"
        else
            print_error "Terraform destroy failed. Manual cleanup may be required."
            print_warning "Check AWS console for remaining resources"
            
            # Show remaining resources
            terraform state list 2>/dev/null || echo "No state information available"
        fi
    fi
    
    cd ..
}

# Manual cleanup verification
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    print_status "Checking for remaining resources..."
    
    # Check for remaining EKS clusters
    REMAINING_CLUSTERS=$(aws eks list-clusters --query 'clusters[?contains(@, `eks-security`)]' --output text 2>/dev/null || echo "")
    if [ -n "$REMAINING_CLUSTERS" ]; then
        print_warning "Remaining EKS clusters found: $REMAINING_CLUSTERS"
    fi
    
    # Check for remaining ECR repositories
    REMAINING_REPOS=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `eks-security`)].repositoryName' --output text 2>/dev/null || echo "")
    if [ -n "$REMAINING_REPOS" ]; then
        print_warning "Remaining ECR repositories found: $REMAINING_REPOS"
    fi
    
    # Check for remaining VPCs
    REMAINING_VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*eks-security*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
    if [ -n "$REMAINING_VPCS" ]; then
        print_warning "Remaining VPCs found: $REMAINING_VPCS"
    fi
    
    print_status "Cleanup verification completed"
}

# Show final cost check reminder
show_cost_reminder() {
    print_header "Cost Verification Reminder"
    
    echo "Please verify that all resources have been deleted:"
    echo "1. Check AWS Cost Explorer for today's usage"
    echo "2. Verify no charges are accumulating"
    echo "3. Check these services specifically:"
    echo "   • EC2 instances (worker nodes)"
    echo "   • ELB/ALB load balancers"
    echo "   • NAT gateways"
    echo "   • EKS cluster"
    echo "   • ECR repositories"
    echo "   • CloudWatch logs"
    echo ""
    echo "AWS Console URLs to check:"
    echo "• EC2: https://console.aws.amazon.com/ec2/"
    echo "• EKS: https://console.aws.amazon.com/eks/"
    echo "• VPC: https://console.aws.amazon.com/vpc/"
    echo "• ECR: https://console.aws.amazon.com/ecr/"
    echo "• Cost Explorer: https://console.aws.amazon.com/cost-reports/"
    echo ""
    print_status "Remember to check your AWS bill in the next few hours!"
}

# Main execution
main() {
    confirm_cleanup
    check_cluster_exists
    cleanup_k8s_resources
    empty_ecr_repositories
    terraform_destroy
    verify_cleanup
    show_cost_reminder
    
    print_header "Cleanup Completed"
    print_status "All resources should now be destroyed"
    print_warning "Please verify in AWS Console and Cost Explorer"
}

# Run main function
main "$@"
