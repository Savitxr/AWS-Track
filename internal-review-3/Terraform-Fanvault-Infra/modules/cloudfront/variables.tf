variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "s3_bucket_id" {
  type        = string
  description = "ID (name) of the S3 bucket to use as the CloudFront origin"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket (used for the OAC bucket policy)"
}

variable "s3_bucket_regional_domain_name" {
  type        = string
  description = "Regional domain name of the S3 bucket (e.g. bucket.s3.us-east-1.amazonaws.com)"
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
