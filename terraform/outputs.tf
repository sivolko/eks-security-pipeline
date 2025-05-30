# Terraform Outputs - Important Information After Deployment

# EKS Cluster Information
output "cluster_info" {
  description = "EKS Cluster Information"
  value = {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_arn      = module.eks.cluster_arn
    cluster_version  = module.eks.cluster_version
    cluster_status   = module.eks.cluster_status
  }
}

# Cluster Access Information  
output "cluster_access" {
  description = "Commands to access the EKS cluster"
  value = {
    configure_kubectl = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
    get_nodes        = "kubectl get nodes"
    get_pods         = "kubectl get pods -A"
  }
}

# Security Information
output "security_resources" {
  description = "Security-related resources"
  value = {
    vpc_id                    = module.vpc.vpc_id
    private_subnets          = module.vpc.private_subnets
    public_subnets          = module.vpc.public_subnets
    cluster_security_group   = module.eks.cluster_security_group_id
    node_security_group      = module.eks.node_security_group_id
    additional_security_group = aws_security_group.eks_additional_sg.id
    kms_key_arn             = module.eks.kms_key_arn
  }
}

# ECR Information
output "container_registry" {
  description = "ECR Repository Information"
  value = {
    repositories = {
      for k, v in aws_ecr_repository.repos : k => {
        name = v.name
        url  = v.repository_url
        arn  = v.arn
      }
    }
    scan_processor_function = aws_lambda_function.scan_processor.function_name
    security_alerts_topic   = aws_sns_topic.security_alerts.arn
  }
}

# Monitoring and Logging
output "monitoring_logging" {
  description = "Monitoring and logging resources"
  value = {
    cloudwatch_log_group        = "/aws/eks/${module.eks.cluster_name}/cluster"
    vpc_flow_logs_group        = "/aws/vpc-flow-log/${module.vpc.name}"
    container_insights_enabled = var.enable_container_insights
  }
}

# Cost Information
output "estimated_costs" {
  description = "Estimated monthly costs (USD)"
  value = {
    eks_cluster       = "~$73/month (24/7)"
    worker_nodes      = "~$${var.node_group_desired_capacity * 69}/month (m5.large)"
    nat_gateways      = var.single_nat_gateway ? "~$33/month" : "~$${length(var.availability_zones) * 33}/month"
    load_balancers    = "~$18/month per ALB/NLB"
    ecr_storage       = "~$0.10/GB/month"
    data_transfer     = "Variable based on usage"
    total_estimate    = "~$${73 + (var.node_group_desired_capacity * 69) + (var.single_nat_gateway ? 33 : length(var.availability_zones) * 33)}/month"
  }
}

# Next Steps
output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = {
    step_1 = "Configure kubectl: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
    step_2 = "Verify cluster: kubectl get nodes"
    step_3 = "Install AWS Load Balancer Controller: helm repo add eks https://aws.github.io/eks-charts"
    step_4 = "Deploy security policies: kubectl apply -f ../security-policies/"
    step_5 = "Deploy sample applications: kubectl apply -f ../k8s-manifests/"
    step_6 = "Set up monitoring: kubectl apply -f ../monitoring/"
    step_7 = "Test container scanning: docker build and push to ECR repositories"
  }
}

# Important URLs
output "important_urls" {
  description = "Important AWS Console URLs"
  value = {
    eks_cluster  = "https://${var.aws_region}.console.aws.amazon.com/eks/home?region=${var.aws_region}#/clusters/${module.eks.cluster_name}"
    ecr_console  = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories?region=${var.aws_region}"
    vpc_console  = "https://${var.aws_region}.console.aws.amazon.com/vpc/home?region=${var.aws_region}#vpcs:VpcId=${module.vpc.vpc_id}"
    cloudwatch   = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}"
    iam_console  = "https://console.aws.amazon.com/iam/home#/roles"
  }
}

# Security Checklist
output "security_checklist" {
  description = "Security implementation checklist"
  value = {
    infrastructure = {
      "✅ VPC with private/public subnets" = "Implemented"
      "✅ EKS cluster with latest version"  = "Implemented"
      "✅ Encrypted EBS volumes"           = "Implemented"
      "✅ KMS encryption for secrets"      = "Implemented"
      "✅ VPC Flow Logs enabled"          = "Implemented"
      "✅ CloudTrail logging"             = "Check if enabled in account"
    }
    container_security = {
      "✅ ECR vulnerability scanning"      = "Implemented"
      "✅ Image scan on push"             = "Implemented"
      "✅ Automated alerting"             = "Implemented"
      "⏳ Network policies"               = "Deploy Calico next"
      "⏳ Pod Security Standards"         = "Configure next"
      "⏳ Admission controllers"          = "Deploy OPA Gatekeeper next"
    }
    monitoring = {
      "✅ Control plane logging"          = "Implemented"
      "✅ Node-level monitoring"          = "Implemented"
      "⏳ Application monitoring"         = "Deploy Prometheus next"
      "⏳ Security monitoring"            = "Deploy Falco next"
    }
  }
}

# Cleanup Commands
output "cleanup_commands" {
  description = "Commands to clean up resources when done"
  value = {
    terraform_destroy = "terraform destroy -auto-approve"
    manual_cleanup    = "Check for any remaining Load Balancers, EBS volumes, or ENIs"
    cost_verification = "Check AWS Cost Explorer after cleanup"
  }
}
