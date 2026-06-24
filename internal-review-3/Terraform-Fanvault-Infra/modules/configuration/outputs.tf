# =============================================================================
# SSM Module — Outputs
# =============================================================================

output "parameter_prefix" {
  value       = "/fanvault"
  description = "Root path prefix for all FanVault SSM parameters"
}

output "jwt_secret_arn" {
  value       = aws_ssm_parameter.jwt_secret.arn
  description = "ARN of the JWT secret SecureString parameter"
}

output "jwt_refresh_secret_arn" {
  value       = aws_ssm_parameter.jwt_refresh_secret.arn
  description = "ARN of the JWT refresh secret SecureString parameter"
}

output "cognito_user_pool_id_arn" {
  value       = aws_ssm_parameter.cognito_user_pool_id.arn
  description = "ARN of the Cognito User Pool ID SSM parameter"
}

output "cognito_client_id_arn" {
  value       = aws_ssm_parameter.cognito_client_id.arn
  description = "ARN of the Cognito App Client ID SSM parameter"
}
