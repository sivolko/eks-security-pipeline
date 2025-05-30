#!/bin/bash
# Quick setup script for EKS Security Pipeline

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_header "EKS Security Pipeline - Quick Setup"

# Make scripts executable
print_status "Making scripts executable..."
chmod +x scripts/deploy.sh
chmod +x scripts/cleanup.sh

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform/terraform.tfvars" ]; then
    print_status "Creating terraform.tfvars from example..."
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    
    echo ""
    echo "📝 Please edit terraform/terraform.tfvars with your specific settings:"
    echo "   • AWS region"
    echo "   • Cluster name" 
    echo "   • Instance types"
    echo "   • Network configuration"
    echo ""
fi

print_header "Ready to Deploy!"

echo "🚀 To deploy the EKS security pipeline:"
echo "   ./scripts/deploy.sh"
echo ""
echo "🧹 To cleanup all resources when done:"
echo "   ./scripts/cleanup.sh"
echo ""
echo "📁 Project structure:"
echo "   ├── terraform/          # Infrastructure code"
echo "   ├── scripts/            # Deployment scripts"
echo "   ├── k8s-manifests/      # Kubernetes manifests (coming next)"
echo "   ├── security-policies/  # Security policies (coming next)"
echo "   └── monitoring/         # Monitoring configs (coming next)"
echo ""
print_status "Setup completed! You're ready to deploy."
