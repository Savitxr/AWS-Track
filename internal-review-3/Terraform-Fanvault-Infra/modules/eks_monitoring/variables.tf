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
  description = "AWS region"
  default     = "us-east-1"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN to receive alarm notifications"
}

variable "dynamodb_tables" {
  type        = map(string)
  description = "Map of short key to DynamoDB table name (e.g. { profiles = 'fanvault-dev-profiles' })"
  default     = {}
}

variable "lambda_functions" {
  type        = map(string)
  description = "Map of short key to Lambda function name"
  default     = {}
}

variable "sns_topics" {
  type        = map(string)
  description = "Map of short key to SNS topic name (not ARN)"
  default     = {}
}
