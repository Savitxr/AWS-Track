output "alb_dns_name" {
  value       = module.backend.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = module.backend.bastion_public_ip
  description = "The public IP address of the Bastion host (Jump Box)"
}

output "github_actions_role_arn" {
  value       = module.iam.github_actions_role_arn
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
}

output "event_bus_name" {
  value       = module.event_processing.event_bus_name
  description = "Name of the EventBridge custom event bus"
}

output "event_dlq_name" {
  value       = module.event_processing.event_dlq_name
  description = "Name of the SQS Dead-Letter Queue"
}

output "sns_topic_low_inventory_arn" {
  value       = module.notifications.sns_topic_low_inventory_arn
  description = "ARN of the Low Inventory Alerts SNS topic"
}

output "sns_topic_order_failure_arn" {
  value       = module.notifications.sns_topic_order_failure_arn
  description = "ARN of the Order Failure Alerts SNS topic"
}

output "sns_topic_product_upload_failure_arn" {
  value       = module.notifications.sns_topic_product_upload_failure_arn
  description = "ARN of the Product Upload Failures SNS topic"
}

output "sns_topic_admin_operational_alert_arn" {
  value       = module.notifications.sns_topic_admin_operational_alert_arn
  description = "ARN of the Admin Operational Alerts SNS topic"
}

output "waf_web_acl_arn" {
  value       = module.governance.waf_web_acl_arn
  description = "ARN of the WAFv2 Web ACL"
}

output "waf_web_acl_id" {
  value       = module.governance.waf_web_acl_id
  description = "ID of the WAFv2 Web ACL"
}

output "waf_web_acl_name" {
  value       = module.governance.waf_web_acl_name
  description = "Name of the WAFv2 Web ACL"
}
