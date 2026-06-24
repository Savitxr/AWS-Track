output "repository_urls" {
  value       = { for k, v in aws_ecr_repository.repo : k => v.repository_url }
  description = "Map of ECR repository name to repository URL"
}

output "repository_arns" {
  value       = { for k, v in aws_ecr_repository.repo : k => v.arn }
  description = "Map of ECR repository name to repository ARN"
}
