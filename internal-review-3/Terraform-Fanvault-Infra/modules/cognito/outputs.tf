output "user_pool_id" {
  value       = aws_cognito_user_pool.pool.id
  description = "The ID of the Cognito User Pool"
}

output "user_pool_arn" {
  value       = aws_cognito_user_pool.pool.arn
  description = "The ARN of the Cognito User Pool"
}

output "client_id" {
  value       = aws_cognito_user_pool_client.client.id
  description = "The Client ID of the Cognito User Pool Client"
}

output "domain" {
  value       = aws_cognito_user_pool_domain.domain.domain
  description = "The domain name of the Cognito User Pool hosted UI"
}
