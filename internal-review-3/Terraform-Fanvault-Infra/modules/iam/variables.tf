# =============================================================================
# IAM Module — Variables
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

# DynamoDB table ARNs — used to scope the EC2 instance policy
variable "dynamodb_table_arns" {
  type        = list(string)
  description = "ARNs of all DynamoDB tables the backend EC2 needs access to"
  default     = []
}

# SSM parameter path prefix — used to scope GetParameter access
variable "ssm_parameter_prefix" {
  type        = string
  description = "SSM Parameter Store path prefix (e.g. /fanvault)"
  default     = "/fanvault"
}

# S3 bucket name prefix — used to build a scoped GetObject ARN pattern
# Avoids a circular dependency with the s3_lambda module.
variable "s3_bucket_name_prefix" {
  type        = string
  description = "S3 bucket name prefix (e.g. 'fanvault') used to scope s3:GetObject policy to 'arn:aws:s3:::fanvault-*/*'"
  default     = "fanvault"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name in the format 'owner/repo' (e.g. 'Fanvault-CloudOps/Fanvault-v3-App')"
  default     = "Fanvault-CloudOps/Fanvault-v3-App"
}

variable "sns_topic_arns" {
  type        = list(string)
  description = "ARNs of the SNS topics for operational notifications"
  default     = []
}

variable "sns_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used for encrypting SNS topics"
  default     = ""
}

variable "dynamodb_table_audit_logs_arn" {
  type        = string
  description = "ARN of the fanvault-audit-logs DynamoDB table"
}

variable "dynamodb_table_products_arn" {
  type        = string
  description = "ARN of the fanvault-products DynamoDB table"
}

variable "s3_bucket_product_images_arn" {
  type        = string
  description = "ARN of the S3 bucket for product images"
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
variable "eks_oidc_provider_arn" {
  type        = string
  description = "The ARN of the EKS OIDC provider"
  default     = ""
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "The URL of the EKS OIDC provider"
  default     = ""
}

variable "enable_irsa" {
  type        = bool
  description = "Whether to create EKS IRSA resources"
  default     = false
}


variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
