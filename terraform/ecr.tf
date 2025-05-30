# ECR Configuration for Container Security Scanning
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.ecr_repositories)
  
  name = "${var.cluster_name}-${each.value}"
  
  image_tag_mutability = "MUTABLE"
  
  # Enable image scanning on push
  image_scanning_configuration {
    scan_on_push = true
  }
  
  # Encryption configuration
  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = aws_kms_key.ecr.arn
  }

  tags = {
    Name        = "${var.cluster_name}-${each.value}"
    Environment = var.environment
    Purpose     = "SecurityPipeline"
  }
}

# KMS key for ECR encryption
resource "aws_kms_key" "ecr" {
  description             = "ECR Repository Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR Service"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-ecr-key"
  }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.cluster_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ECR Repository Policies for security
resource "aws_ecr_repository_policy" "repo_policies" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateImageScan"
        ]
      }
    ]
  })
}

# Lifecycle policies to manage image retention and costs
resource "aws_ecr_lifecycle_policy" "repo_lifecycle" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production", "stable"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "development", "test"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CloudWatch Event Rule for ECR scan results
resource "aws_cloudwatch_event_rule" "ecr_scan_results" {
  name        = "${var.cluster_name}-ecr-scan-results"
  description = "Capture ECR image scan results"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      scan-status = ["COMPLETE"]
    }
  })

  tags = {
    Name = "${var.cluster_name}-ecr-scan-results"
  }
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "${var.cluster_name}-security-alerts"
  
  kms_master_key_id = aws_kms_key.ecr.id

  tags = {
    Name = "${var.cluster_name}-security-alerts"
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "security_alerts" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# EventBridge target to send scan results to SNS
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_results.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# Lambda function for processing scan results
resource "aws_lambda_function" "scan_processor" {
  filename         = "scan-processor.zip"
  function_name    = "${var.cluster_name}-scan-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.scan_processor_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      CLUSTER_NAME  = var.cluster_name
    }
  }

  tags = {
    Name = "${var.cluster_name}-scan-processor"
  }
}

# Package Lambda function
data "archive_file" "scan_processor_zip" {
  type        = "zip"
  output_path = "scan-processor.zip"
  source {
    content = templatefile("${path.module}/scan-processor.py", {
      cluster_name = var.cluster_name
    })
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.cluster_name}-lambda-scan-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.cluster_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeImageScanFindings",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# EventBridge target for Lambda
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_results.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.scan_processor.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scan_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_scan_results.arn
}

# Outputs
output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    for k, v in aws_ecr_repository.repos : k => v.repository_url
  }
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs"
  value = {
    for k, v in aws_ecr_repository.repos : k => v.arn
  }
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}
