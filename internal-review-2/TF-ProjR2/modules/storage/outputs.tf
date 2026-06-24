# =============================================================================
# Storage Module — Outputs
# =============================================================================

# ── Grouped Output: Map of DynamoDB table names ──────────────────────────────
output "dynamodb_tables" {
  value = {
    users      = aws_dynamodb_table.users.name
    profiles   = aws_dynamodb_table.profiles.name
    products   = aws_dynamodb_table.products.name
    orders     = aws_dynamodb_table.orders.name
    audit_logs = aws_dynamodb_table.audit_logs.name
    metadata   = aws_dynamodb_table.metadata.name
  }
  description = "Map of all FanVault DynamoDB table names"
}

# ── Individual DynamoDB Outputs (Compatibility) ──────────────────────────────
output "table_users_name" {
  value       = aws_dynamodb_table.users.name
  description = "Name of the fanvault-users DynamoDB table"
}

output "table_profiles_name" {
  value       = aws_dynamodb_table.profiles.name
  description = "Name of the fanvault-profiles DynamoDB table"
}

output "table_products_name" {
  value       = aws_dynamodb_table.products.name
  description = "Name of the fanvault-products DynamoDB table"
}

output "table_orders_name" {
  value       = aws_dynamodb_table.orders.name
  description = "Name of the fanvault-orders DynamoDB table"
}

output "table_users_arn" {
  value       = aws_dynamodb_table.users.arn
  description = "ARN of the fanvault-users table (used in IAM policies)"
}

output "table_profiles_arn" {
  value       = aws_dynamodb_table.profiles.arn
  description = "ARN of the fanvault-profiles table"
}

output "table_products_arn" {
  value       = aws_dynamodb_table.products.arn
  description = "ARN of the fanvault-products table"
}

output "table_orders_arn" {
  value       = aws_dynamodb_table.orders.arn
  description = "ARN of the fanvault-orders table"
}

output "table_audit_logs_name" {
  value       = aws_dynamodb_table.audit_logs.name
  description = "Name of the fanvault-audit-logs DynamoDB table"
}

output "table_metadata_name" {
  value       = aws_dynamodb_table.metadata.name
  description = "Name of the fanvault-metadata DynamoDB table"
}

output "table_audit_logs_arn" {
  value       = aws_dynamodb_table.audit_logs.arn
  description = "ARN of the fanvault-audit-logs table (used in IAM policies)"
}

output "table_metadata_arn" {
  value       = aws_dynamodb_table.metadata.arn
  description = "ARN of the fanvault-metadata table (used in IAM policies)"
}

# ── Individual S3/CloudFront/Lambda Outputs ───────────────────────────────
output "lambda_function_name" {
  value       = aws_lambda_function.arch_page.function_name
  description = "The name of the Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.arch_page.arn
  description = "The ARN of the Lambda function"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.architecture.arn
  description = "ARN of the private S3 architecture/images bucket (used to scope IAM policy)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.product_images.id
  description = "Name of the private S3 product images bucket (stored in SSM /fanvault/s3/bucket)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.product_images_distribution.domain_name
  description = "The domain name of the CloudFront distribution for product images"
}

output "s3_product_images_bucket_arn" {
  value       = aws_s3_bucket.product_images.arn
  description = "ARN of the product images S3 bucket"
}
