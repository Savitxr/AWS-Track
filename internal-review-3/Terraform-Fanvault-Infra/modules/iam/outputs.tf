# =============================================================================
# IAM Module — Outputs
# =============================================================================

# ── Lambda Role (existing) ────────────────────────────────────────────────────
output "lambda_role_arn" {
  value       = aws_iam_role.lambda_s3_read.arn
  description = "ARN of the S3-read execution role for Lambda"
}

# ── EC2 Backend Instance Profile ──────────────────────────────────────────────
output "ec2_backend_instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_backend.name
  description = "Name of the EC2 instance profile for backend nodes (DynamoDB + SSM + S3 + CloudWatch)"
}

output "ec2_backend_instance_profile_arn" {
  value       = aws_iam_instance_profile.ec2_backend.arn
  description = "ARN of the backend EC2 instance profile"
}

output "ec2_backend_role_arn" {
  value       = aws_iam_role.ec2_backend.arn
  description = "ARN of the backend EC2 IAM role"
}

# ── EC2 Frontend Instance Profile ─────────────────────────────────────────────
output "ec2_frontend_instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_frontend.name
  description = "Name of the EC2 instance profile for frontend nodes (SSM git/* + CloudWatch)"
}

output "ec2_frontend_instance_profile_arn" {
  value       = aws_iam_instance_profile.ec2_frontend.arn
  description = "ARN of the frontend EC2 instance profile"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
}

output "lambda_consumers_role_arn" {
  value       = aws_iam_role.lambda_consumers.arn
  description = "ARN of the Lambda consumers execution role"
}

output "sns_feedback_role_arn" {
  value       = aws_iam_role.sns_feedback_role.arn
  description = "ARN of the SNS CloudWatch feedback execution role"
}
output "user_irsa_role_arn" {
  value       = length(aws_iam_role.user_irsa) > 0 ? aws_iam_role.user_irsa[0].arn : ""
  description = "ARN of the User Service EKS IRSA role"
}

output "commerce_irsa_role_arn" {
  value       = length(aws_iam_role.commerce_irsa) > 0 ? aws_iam_role.commerce_irsa[0].arn : ""
  description = "ARN of the Commerce Service EKS IRSA role"
}

output "cloudwatch_agent_irsa_role_arn" {
  value       = length(aws_iam_role.cloudwatch_agent_irsa) > 0 ? aws_iam_role.cloudwatch_agent_irsa[0].arn : ""
  description = "ARN of the CloudWatch Agent IRSA role (used by amazon-cloudwatch-observability addon)"
}

output "alertmanager_irsa_role_arn" {
  value       = length(aws_iam_role.alertmanager_irsa) > 0 ? aws_iam_role.alertmanager_irsa[0].arn : ""
  description = "ARN of the Alertmanager IRSA role (used by kube-prometheus-stack Alertmanager)"
}
