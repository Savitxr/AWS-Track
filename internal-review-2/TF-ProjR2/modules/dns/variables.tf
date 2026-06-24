variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "mongodb_private_ip" {
  type        = string
  description = "Private IP of the MongoDB server"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}
