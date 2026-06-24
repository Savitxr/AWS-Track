variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "A standard prefix for resources created by this project"
  default     = "fanvault"
}

variable "environment" {
  type        = string
  description = "Application deployment environment context tag"
  default     = "production"
}

variable "admin_ssh_ip" {
  type        = string
  description = "The public IP of the administrator for secure SSH access (Bastion)"
  default     = "0.0.0.0/0"
}

variable "key_name" {
  type        = string
  description = "The EC2 key pair name to use for SSH authentication"
  default     = "fanvault-key"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin for both backend services (e.g. https://fanvault.example.com)"
  default     = "https://fanvault.example.com"
}

variable "jwt_secret" {
  type        = string
  description = "JWT access token signing secret — minimum 32 characters"
  sensitive   = true
  default     = "CHANGE_ME_TO_A_RANDOM_32_PLUS_CHAR_STRING"
}

variable "jwt_refresh_secret" {
  type        = string
  description = "JWT refresh token signing secret — different from jwt_secret"
  sensitive   = true
  default     = "CHANGE_ME_TO_A_DIFFERENT_RANDOM_32_PLUS_CHAR_STRING"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name in the format 'owner/repo' (e.g. 'Savitxr/Fanvault-v2')"
  default     = "Savitxr/Fanvault-v2"
}

variable "alert_email" {
  type        = string
  description = "Optional email address to subscribe to SNS operational alerts"
  default     = ""
}

variable "geo_blocked_countries" {
  type        = list(string)
  description = "List of ISO country codes to block via AWS WAF"
  default     = []
}

variable "git_repo_url" {
  type        = string
  description = "The HTTP clone URL of the application Git repository"
  default     = "https://github.com/Savitxr/Fanvault-v2.git"
}

variable "git_branch" {
  type        = string
  description = "The target deployment branch of the application Git repository"
  default     = "main"
}

variable "dynamodb_billing_mode" {
  type        = string
  description = "The billing mode for the DynamoDB tables (PROVISIONED or PAY_PER_REQUEST)"
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_enable_pitr" {
  type        = bool
  description = "Whether to enable Point-in-Time Recovery (PITR) for the DynamoDB tables"
  default     = true
}

variable "dynamodb_enable_encryption" {
  type        = bool
  description = "Whether to enable server-side encryption with KMS keys for the DynamoDB tables"
  default     = true
}

variable "ssm_parameter_prefix" {
  type        = string
  description = "The prefix path for parameters stored in AWS Systems Manager Parameter Store"
  default     = "/fanvault"
}

variable "cloudfront_to_alb_custom_header" {
  type        = string
  description = "The secret header token passed from CloudFront to ALB to verify request origin"
  default     = "FanVaultSecureHeaderToken2026!"
}
