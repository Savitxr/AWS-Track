output "sns_key_arn" {
  value       = aws_kms_key.sns_key.arn
  description = "ARN of the KMS key used for encrypting SNS topics"
}

output "sns_key_id" {
  value       = aws_kms_key.sns_key.key_id
  description = "ID of the KMS key used for encrypting SNS topics"
}

output "sns_topic_low_inventory_arn" {
  value       = aws_sns_topic.low_inventory.arn
  description = "ARN of the Low Inventory alerts topic"
}

output "sns_topic_order_failure_arn" {
  value       = aws_sns_topic.order_failure.arn
  description = "ARN of the Order Failure alerts topic"
}

output "sns_topic_product_upload_failure_arn" {
  value       = aws_sns_topic.product_upload.arn
  description = "ARN of the Product Upload failures topic"
}

output "sns_topic_admin_operational_alert_arn" {
  value       = aws_sns_topic.admin_operational.arn
  description = "ARN of the Admin Operational alerts topic"
}
