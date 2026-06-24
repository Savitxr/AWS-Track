variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS cluster API server endpoint"
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider"
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "URL of the EKS OIDC provider (without https://)"
}

variable "node_iam_role_name" {
  type        = string
  description = "Name of the existing EKS node IAM role (reused by Karpenter-provisioned nodes)"
}

variable "node_iam_role_arn" {
  type        = string
  description = "ARN of the existing EKS node IAM role"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev/prod)"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "karpenter_version" {
  type        = string
  description = "Karpenter Helm chart version"
  default     = "1.5.3"
}

variable "max_nodes_cpu" {
  type        = string
  description = "Maximum total CPU across all Karpenter-provisioned nodes"
  default     = "20"
}

variable "max_nodes_memory" {
  type        = string
  description = "Maximum total memory across all Karpenter-provisioned nodes"
  default     = "40Gi"
}

variable "instance_types" {
  type        = list(string)
  description = "Allowed EC2 instance types for Karpenter NodePool"
  default     = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
}
