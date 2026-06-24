variable "project_name" {
  type        = string
  description = "The project name prefix"
}

variable "environment" {
  type        = string
  description = "Application deployment environment context tag"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}

variable "database_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for database subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to distribute subnets"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
