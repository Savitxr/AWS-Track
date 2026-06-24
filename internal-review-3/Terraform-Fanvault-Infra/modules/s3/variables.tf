variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID to prevent naming collisions"
}

variable "cors_allowed_origins" {
  type        = list(string)
  description = "Origins allowed to upload directly to S3 via presigned URLs"
  default     = ["*"]
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
