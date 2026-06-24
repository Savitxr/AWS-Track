output "grafana_service_name" {
  value       = "kube-prometheus-stack-grafana"
  description = "Grafana service name in the monitoring namespace"
}

output "prometheus_service_name" {
  value       = "kube-prometheus-stack-prometheus"
  description = "Prometheus service name in the monitoring namespace"
}

output "alertmanager_service_name" {
  value       = "kube-prometheus-stack-alertmanager"
  description = "Alertmanager service name in the monitoring namespace"
}

output "grafana_password_ssm_path" {
  value       = aws_ssm_parameter.grafana_admin_password.name
  description = "SSM parameter path for the Grafana admin password"
}
