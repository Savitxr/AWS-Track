output "karpenter_controller_role_arn" {
  value       = aws_iam_role.karpenter_controller.arn
  description = "ARN of the Karpenter controller IRSA role"
}

output "karpenter_interruption_queue_url" {
  value       = aws_sqs_queue.karpenter_interruption.url
  description = "URL of the Karpenter SQS interruption queue"
}

output "karpenter_interruption_queue_arn" {
  value       = aws_sqs_queue.karpenter_interruption.arn
  description = "ARN of the Karpenter SQS interruption queue"
}
