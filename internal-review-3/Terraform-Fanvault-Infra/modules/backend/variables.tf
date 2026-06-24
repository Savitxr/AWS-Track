variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet IDs list"
}

variable "frontend_private_subnets" {
  type        = list(string)
  description = "Frontend private subnet IDs list"
}

variable "backend_private_subnets" {
  type        = list(string)
  description = "Backend private subnet IDs list"
}

variable "database_private_subnets" {
  type        = list(string)
  description = "Database private subnet IDs list"
}

variable "alb_sg_id" {
  type        = string
  description = "ALB security group ID"
}

variable "frontend_sg_id" {
  type        = string
  description = "Frontend Nginx security group ID"
}

variable "backend_sg_id" {
  type        = string
  description = "Backend App security group ID"
}


variable "bastion_sg_id" {
  type        = string
  description = "Bastion security group ID"
}

variable "lambda_function_arn" {
  type        = string
  description = "ARN of the S3-fetching Lambda function"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the S3-fetching Lambda function"
}

variable "key_name" {
  type        = string
  description = "Key pair name for EC2 instances"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "ec2_backend_instance_profile_name" {
  type        = string
  description = "Name of the IAM instance profile to attach to backend EC2 Launch Template"
}

variable "ec2_frontend_instance_profile_name" {
  type        = string
  description = "Name of the IAM instance profile to attach to frontend EC2 Launch Template"
}

variable "cloudfront_to_alb_custom_header" {
  type        = string
  description = "Custom secret header value sent from CloudFront to ALB"
  sensitive   = true
}
