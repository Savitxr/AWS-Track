variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "vpc_endpoints_sg_id" {
  type        = string
  description = "Security Group ID for VPC Interface Endpoints"
}

variable "aws_region" {
  type        = string
  description = "AWS Region to build endpoint service names"
}
