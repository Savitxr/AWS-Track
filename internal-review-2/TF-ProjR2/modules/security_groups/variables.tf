variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "admin_ssh_ip" {
  type        = string
  description = "The public IP of the administrator for SSH access"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}
