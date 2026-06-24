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

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for Alertmanager to publish critical alerts"
}

variable "sns_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt the SNS topic"
}

variable "alertmanager_irsa_role_arn" {
  type        = string
  description = "IRSA role ARN for Alertmanager service account"
}

variable "prometheus_retention_days" {
  type        = number
  description = "Prometheus data retention in days"
  default     = 15
}

variable "prometheus_storage_size" {
  type        = string
  description = "Prometheus PVC size"
  default     = "20Gi"
}

variable "grafana_storage_size" {
  type        = string
  description = "Grafana PVC size"
  default     = "10Gi"
}

variable "alertmanager_storage_size" {
  type        = string
  description = "Alertmanager PVC size"
  default     = "5Gi"
}

variable "kube_prometheus_stack_version" {
  type        = string
  description = "kube-prometheus-stack Helm chart version"
  default     = "65.8.1"
}
