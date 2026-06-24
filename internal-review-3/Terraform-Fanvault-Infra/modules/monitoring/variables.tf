# =============================================================================
# Monitoring Module — Variables
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project name prefix used in resource names"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. production, staging)"
}

variable "sns_topic_arn" {
  type        = string
  description = "The ARN of the SNS topic to publish operational alerts to"
}

variable "alb_arn_suffix" {
  type        = string
  description = "The ARN suffix of the Application Load Balancer"
}

variable "target_groups" {
  type        = map(string)
  description = "Map of target group names to their ARN suffixes"
}

variable "bastion_instance_id" {
  type        = string
  description = "Instance ID of the Bastion EC2 host"
}

variable "asgs" {
  type        = map(string)
  description = "Map of static keys to Auto Scaling Group names to monitor"
}

variable "dynamodb_tables" {
  type        = map(string)
  description = "Map of DynamoDB table names to monitor"
}

variable "lambdas" {
  type        = map(string)
  description = "Map of static keys to Lambda function names to monitor"
}

variable "sns_topics" {
  type        = map(string)
  description = "Map of static keys to SNS topic names to monitor"
}
