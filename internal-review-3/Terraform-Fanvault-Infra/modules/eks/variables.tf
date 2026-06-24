variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (dev, prod, etc.)"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the cluster will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS node groups"
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "instance_types" {
  type        = list(string)
  description = "Instance types for node group"
  default     = ["t3.medium"]
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster (must be 1.29+)"
  default     = "1.35"
}
