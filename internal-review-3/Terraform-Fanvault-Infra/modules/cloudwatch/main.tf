resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.project_name}-${var.environment}-eks/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudwatch"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
  }
}

# Application service log groups — one per EKS workload
locals {
  services = ["user-service", "commerce-service", "ai-service", "frontend"]
}

resource "aws_cloudwatch_log_group" "service_logs" {
  for_each          = toset(local.services)
  name              = "/aws/eks/${var.project_name}-${var.environment}/${each.value}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.value}-logs"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
  }
}
