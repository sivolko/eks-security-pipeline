# Example Terraform Variables Configuration
# Copy this file to terraform.tfvars and customize the values

# AWS Configuration
aws_region = "us-west-2"  # Change to your preferred region
environment = "dev"       # dev, staging, prod

# EKS Cluster Configuration
cluster_name    = "eks-security-cluster"
cluster_version = "1.28"  # Latest supported version

# Node Group Configuration
node_group_instance_types    = ["m5.large", "m5.xlarge"]
node_group_desired_capacity  = 3
node_group_max_capacity      = 6
node_group_min_capacity      = 1

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = [
  "us-west-2a",
  "us-west-2b", 
  "us-west-2c"
]

private_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

public_subnet_cidrs = [
  "10.0.101.0/24",
  "10.0.102.0/24",
  "10.0.103.0/24"
]

# Cost Optimization (set to true for production)
enable_nat_gateway = true
single_nat_gateway = false  # Set to true to save costs (less redundancy)

# Security Features
enable_container_insights = true
enable_irsa              = true

# ECR Repositories
ecr_repositories = [
  "vulnerable-app",
  "secure-app", 
  "monitoring-app"
]

# Additional configurations can be added here as needed
