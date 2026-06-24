variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "aws_region" {
  type        = string
  description = "Target AWS region"
}

variable "dynamodb_table_audit_logs_arn" {
  type        = string
  description = "ARN of the fanvault-audit-logs DynamoDB table"
}

variable "dynamodb_table_audit_logs_name" {
  type        = string
  description = "Name of the fanvault-audit-logs DynamoDB table"
}

variable "dynamodb_table_products_arn" {
  type        = string
  description = "ARN of the fanvault-products DynamoDB table"
}

variable "dynamodb_table_products_name" {
  type        = string
  description = "Name of the fanvault-products DynamoDB table"
}

variable "s3_bucket_product_images_arn" {
  type        = string
  description = "ARN of the S3 bucket for product images"
}

variable "s3_bucket_product_images_name" {
  type        = string
  description = "Name of the S3 bucket for product images"
}

variable "sns_topic_low_inventory_arn" {
  type        = string
  description = "ARN of the Low Inventory Alerts SNS topic"
  default     = ""
}

variable "sns_topic_product_upload_failure_arn" {
  type        = string
  description = "ARN of the Product Upload Failures SNS topic"
  default     = ""
}

variable "sns_key_arn" {
  type        = string
  description = "ARN of the KMS Key used for SNS topics"
  default     = ""
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for the Lambda consumers"
}


