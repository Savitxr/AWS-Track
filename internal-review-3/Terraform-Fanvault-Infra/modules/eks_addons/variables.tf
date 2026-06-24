variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS cluster API endpoint"
}

variable "cluster_ca_data" {
  type        = string
  description = "EKS cluster CA certificate data (base64)"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for all resources"
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

variable "cloudwatch_agent_role_arn" {
  type        = string
  description = "IRSA role ARN for the CloudWatch agent service account"
}

variable "ebs_csi_role_arn" {
  type        = string
  description = "IRSA role ARN for the EBS CSI driver service account"
}

variable "enable_metrics_server" {
  type        = bool
  description = "Deploy metrics-server (required for HPA)"
  default     = true
}

variable "enable_cloudwatch_observability" {
  type        = bool
  description = "Deploy amazon-cloudwatch-observability EKS addon (Container Insights + Fluent Bit)"
  default     = true
}

variable "enable_vpa" {
  type        = bool
  description = "Deploy Vertical Pod Autoscaler in recommendation-only mode"
  default     = true
}

variable "metrics_server_version" {
  type        = string
  description = "metrics-server Helm chart version"
  default     = "3.12.1"
}

variable "vpa_version" {
  type        = string
  description = "Fairwinds VPA Helm chart version"
  default     = "4.4.6"
}
