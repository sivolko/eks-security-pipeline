# EKS Cluster Configuration
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.cluster_name}-${var.environment}"  # Make name unique
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # Control plane logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  # Enable encryption
  create_kms_key = true
  enable_kms_key_rotation = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # IAM role configuration
  create_iam_role = true
  iam_role_use_name_prefix = false
  iam_role_name = "${var.cluster_name}-${var.environment}-role"
  iam_role_description = "EKS cluster role"
  
  # Disable inline policies
  attach_cluster_encryption_policy = false

  # Node groups configuration
  eks_managed_node_group_defaults = {
    instance_types = var.node_group_instance_types
    iam_role_use_name_prefix = false

    disk_size = 50
    
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }
  }

  eks_managed_node_groups = {
    security_nodes = {
      name = "${var.cluster_name}-${var.environment}-nodes"
      use_name_prefix = false

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_capacity
      max_size     = var.node_group_max_capacity
      desired_size = var.node_group_desired_capacity

      labels = {
        Environment = var.environment
        NodeGroup   = "security"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}-${var.environment}" = "owned"
      }
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true
  
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AdminRole"
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = data.aws_caller_identity.current.user_id
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create standalone policies
resource "aws_iam_policy" "cluster_base" {
  name        = "${var.cluster_name}-${var.environment}-base"
  description = "Base permissions for EKS cluster"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:DescribeInternetGateways",
          "elasticloadbalancing:*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to the cluster role
resource "aws_iam_role_policy_attachment" "cluster_base" {
  policy_arn = aws_iam_policy.cluster_base.arn
  role       = module.eks.cluster_iam_role_name
  depends_on = [module.eks]
}

# Get caller identity for IAM configurations
data "aws_caller_identity" "current" {}
