# =============================================================================
# SSM Module — Variables
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

# ── Application values ────────────────────────────────────────────────────────
variable "git_repo_url" {
  type        = string
  description = "Git repository URL for cloning the FanVault v2 application"
  default     = "https://github.com/Savitxr/Fanvault-v2.git"
}

variable "git_branch" {
  type        = string
  description = "Git branch to deploy"
  default     = "main"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin (e.g. https://fanvault.example.com)"
  default     = "https://fanvault.example.com"
}

# ── Secrets (SecureString) — set via tfvars or environment variables ───────────
variable "jwt_secret" {
  type        = string
  description = "JWT signing secret — minimum 32 characters. Mark as sensitive in tfvars."
  sensitive   = true
}

variable "jwt_refresh_secret" {
  type        = string
  description = "JWT refresh token signing secret — different from jwt_secret. Mark as sensitive."
  sensitive   = true
}

# ── DynamoDB table names ──────────────────────────────────────────────────────
variable "dynamodb_table_users" {
  type        = string
  description = "Name of the fanvault-users DynamoDB table"
  default     = "fanvault-users"
}

variable "dynamodb_table_profiles" {
  type        = string
  description = "Name of the fanvault-profiles DynamoDB table"
  default     = "fanvault-profiles"
}

variable "dynamodb_table_products" {
  type        = string
  description = "Name of the fanvault-products DynamoDB table"
  default     = "fanvault-products"
}

variable "dynamodb_table_orders" {
  type        = string
  description = "Name of the fanvault-orders DynamoDB table"
  default     = "fanvault-orders"
}

# ── S3 bucket ─────────────────────────────────────────────────────────────────
variable "s3_bucket_name" {
  type        = string
  description = "Name of the private S3 bucket for product images and architecture assets"
  default     = "fanvault-architecture"
}

variable "aws_region" {
  type        = string
  description = "AWS region (used as the S3 region parameter value)"
  default     = "us-east-1"
}

variable "s3_cloudfront_url" {
  type        = string
  description = "The domain name of the CloudFront distribution for product images"
  default     = ""
}

variable "dynamodb_table_audit_logs" {
  type        = string
  description = "Name of the fanvault-audit-logs DynamoDB table"
  default     = "fanvault-audit-logs"
}

variable "dynamodb_table_metadata" {
  type        = string
  description = "Name of the fanvault-metadata DynamoDB table"
  default     = "fanvault-metadata"
}

variable "eventbridge_bus_name" {
  type        = string
  description = "Name of the EventBridge custom event bus"
  default     = "fanvault-event-bus"
}

variable "sns_topic_low_inventory" {
  type        = string
  description = "ARN of the Low Inventory alerts SNS topic"
  default     = ""
}

variable "sns_topic_order_failure" {
  type        = string
  description = "ARN of the Order Failure alerts SNS topic"
  default     = ""
}

variable "sns_topic_product_upload_failure" {
  type        = string
  description = "ARN of the Product Upload failures SNS topic"
  default     = ""
}

variable "sns_topic_admin_operational_alert" {
  type        = string
  description = "ARN of the Admin Operational alerts SNS topic"
  default     = ""
}


