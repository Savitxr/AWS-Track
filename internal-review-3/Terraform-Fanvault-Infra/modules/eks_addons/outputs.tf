output "cloudwatch_addon_version" {
  value       = var.enable_cloudwatch_observability ? data.aws_eks_addon_version.cloudwatch_observability[0].version : null
  description = "Version of the amazon-cloudwatch-observability addon installed"
}

output "metrics_server_installed" {
  value       = var.enable_metrics_server
  description = "Whether metrics-server was deployed"
}
