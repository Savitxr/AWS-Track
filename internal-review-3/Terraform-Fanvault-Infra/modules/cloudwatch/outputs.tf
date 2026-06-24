output "log_group_arn" {
  value       = aws_cloudwatch_log_group.eks_logs.arn
  description = "The ARN of the CloudWatch log group"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.eks_logs.name
  description = "The name of the CloudWatch log group"
}
