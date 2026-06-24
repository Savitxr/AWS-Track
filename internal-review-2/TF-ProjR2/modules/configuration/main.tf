# =============================================================================
# SSM Module — Main
#
# Creates all 11 SSM Parameter Store entries required by the FanVault v2
# user data bootstrap scripts and backend services.
#
# String parameters   — plaintext, readable by any caller with ssm:GetParameter
# SecureString params — KMS-encrypted (AWS-managed key), require kms:Decrypt
#
# Path structure:
#   /fanvault/git/*       — Git repo config (read by frontend + backend at boot)
#   /fanvault/app/*       — Application secrets (read by backend only)
#   /fanvault/dynamodb/*  — DynamoDB table names (read by backend only)
#   /fanvault/s3/*        — S3 config for image proxy (read by backend only)
# =============================================================================

# ── /fanvault/git/repo_url ────────────────────────────────────────────────────
resource "aws_ssm_parameter" "git_repo_url" {
  name        = "/fanvault/git/repo_url"
  type        = "String"
  value       = var.git_repo_url
  description = "Git repository URL for cloning the FanVault v2 application at EC2 boot"

  tags = {
    Name        = "fanvault-git-repo-url"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/git/branch ──────────────────────────────────────────────────────
resource "aws_ssm_parameter" "git_branch" {
  name        = "/fanvault/git/branch"
  type        = "String"
  value       = var.git_branch
  description = "Git branch to checkout when deploying FanVault v2"

  tags = {
    Name        = "fanvault-git-branch"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/app/cors_origin ─────────────────────────────────────────────────
resource "aws_ssm_parameter" "cors_origin" {
  name        = "/fanvault/app/cors_origin"
  type        = "String"
  value       = var.cors_origin
  description = "Allowed CORS origin for both backend services"

  tags = {
    Name        = "fanvault-cors-origin"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/app/jwt_secret — SecureString ───────────────────────────────────
resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/fanvault/app/jwt_secret"
  type        = "SecureString"
  value       = var.jwt_secret
  description = "JWT access token signing secret — shared between identity and commerce services for verification"
  key_id      = "alias/aws/ssm" # AWS-managed KMS key

  lifecycle {
    # Prevent Terraform from overwriting a secret that was rotated manually
    ignore_changes = [value]
  }

  tags = {
    Name        = "fanvault-jwt-secret"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Sensitive   = "true"
  }
}

# ── /fanvault/app/jwt_refresh_secret — SecureString ──────────────────────────
resource "aws_ssm_parameter" "jwt_refresh_secret" {
  name        = "/fanvault/app/jwt_refresh_secret"
  type        = "SecureString"
  value       = var.jwt_refresh_secret
  description = "JWT refresh token signing secret — identity service only; must differ from jwt_secret"
  key_id      = "alias/aws/ssm"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "fanvault-jwt-refresh-secret"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Sensitive   = "true"
  }
}

# ── /fanvault/dynamodb/table_users ────────────────────────────────────────────
resource "aws_ssm_parameter" "table_users" {
  name        = "/fanvault/dynamodb/table_users"
  type        = "String"
  value       = var.dynamodb_table_users
  description = "DynamoDB table name for auth users (fanvault-user-auth-service)"

  tags = {
    Name        = "fanvault-ddb-table-users"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/dynamodb/table_profiles ────────────────────────────────────────
resource "aws_ssm_parameter" "table_profiles" {
  name        = "/fanvault/dynamodb/table_profiles"
  type        = "String"
  value       = var.dynamodb_table_profiles
  description = "DynamoDB table name for user profiles (fanvault-user-auth-service)"

  tags = {
    Name        = "fanvault-ddb-table-profiles"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/dynamodb/table_products ────────────────────────────────────────
resource "aws_ssm_parameter" "table_products" {
  name        = "/fanvault/dynamodb/table_products"
  type        = "String"
  value       = var.dynamodb_table_products
  description = "DynamoDB table name for products (fanvault-commerce-service)"

  tags = {
    Name        = "fanvault-ddb-table-products"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/dynamodb/table_orders ──────────────────────────────────────────
resource "aws_ssm_parameter" "table_orders" {
  name        = "/fanvault/dynamodb/table_orders"
  type        = "String"
  value       = var.dynamodb_table_orders
  description = "DynamoDB table name for orders (fanvault-commerce-service)"

  tags = {
    Name        = "fanvault-ddb-table-orders"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/s3/bucket ───────────────────────────────────────────────────────
resource "aws_ssm_parameter" "s3_bucket" {
  name        = "/fanvault/s3/bucket"
  type        = "String"
  value       = var.s3_bucket_name
  description = "Name of the private S3 bucket for product images and architecture page assets"

  tags = {
    Name        = "fanvault-s3-bucket"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/s3/region ───────────────────────────────────────────────────────
resource "aws_ssm_parameter" "s3_region" {
  name        = "/fanvault/s3/region"
  type        = "String"
  value       = var.aws_region
  description = "AWS region where the product images S3 bucket is located"

  tags = {
    Name        = "fanvault-s3-region"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/s3/cloudfront_url ──────────────────────────────────────────────
resource "aws_ssm_parameter" "s3_cloudfront_url" {
  name        = "/fanvault/s3/cloudfront_url"
  type        = "String"
  value       = var.s3_cloudfront_url
  description = "Domain name of the CloudFront distribution for S3 product images"

  tags = {
    Name        = "fanvault-s3-cloudfront-url"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/dynamodb/table_audit_logs ──────────────────────────────────────
resource "aws_ssm_parameter" "table_audit_logs" {
  name        = "/fanvault/dynamodb/table_audit_logs"
  type        = "String"
  value       = var.dynamodb_table_audit_logs
  description = "DynamoDB table name for admin audit logs (fanvault-commerce-service)"

  tags = {
    Name        = "fanvault-ddb-table-audit-logs"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/dynamodb/table_metadata ────────────────────────────────────────
resource "aws_ssm_parameter" "table_metadata" {
  name        = "/fanvault/dynamodb/table_metadata"
  type        = "String"
  value       = var.dynamodb_table_metadata
  description = "DynamoDB table name for admin category/franchise metadata (fanvault-commerce-service)"

  tags = {
    Name        = "fanvault-ddb-table-metadata"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/eventbridge/bus_name ───────────────────────────────────────────
resource "aws_ssm_parameter" "eventbridge_bus_name" {
  name        = "/fanvault/eventbridge/bus_name"
  type        = "String"
  value       = var.eventbridge_bus_name
  description = "Name of the EventBridge custom event bus"

  tags = {
    Name        = "fanvault-eb-bus-name"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/sns/topic_low_inventory ────────────────────────────────────────
resource "aws_ssm_parameter" "sns_topic_low_inventory" {
  name        = "/fanvault/sns/topic_low_inventory"
  type        = "String"
  value       = var.sns_topic_low_inventory
  description = "ARN of the Low Inventory Alerts SNS topic"

  tags = {
    Name        = "fanvault-sns-topic-low-inventory"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/sns/topic_order_failure ────────────────────────────────────────
resource "aws_ssm_parameter" "sns_topic_order_failure" {
  name        = "/fanvault/sns/topic_order_failure"
  type        = "String"
  value       = var.sns_topic_order_failure
  description = "ARN of the Order Failure Alerts SNS topic"

  tags = {
    Name        = "fanvault-sns-topic-order-failure"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/sns/topic_product_upload_failure ───────────────────────────────
resource "aws_ssm_parameter" "sns_topic_product_upload_failure" {
  name        = "/fanvault/sns/topic_product_upload_failure"
  type        = "String"
  value       = var.sns_topic_product_upload_failure
  description = "ARN of the Product Upload Failures SNS topic"

  tags = {
    Name        = "fanvault-sns-topic-product-upload-failure"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── /fanvault/sns/topic_admin_operational_alert ──────────────────────────────
resource "aws_ssm_parameter" "sns_topic_admin_operational_alert" {
  name        = "/fanvault/sns/topic_admin_operational_alert"
  type        = "String"
  value       = var.sns_topic_admin_operational_alert
  description = "ARN of the Admin Operational Alerts SNS topic"

  tags = {
    Name        = "fanvault-sns-topic-admin-operational-alert"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}


