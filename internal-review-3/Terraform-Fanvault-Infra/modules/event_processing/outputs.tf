output "event_bus_name" {
  value       = aws_cloudwatch_event_bus.commerce_bus.name
  description = "Name of the EventBridge custom event bus"
}

output "event_bus_arn" {
  value       = aws_cloudwatch_event_bus.commerce_bus.arn
  description = "ARN of the EventBridge custom event bus"
}

output "event_dlq_arn" {
  value       = aws_sqs_queue.event_dlq.arn
  description = "ARN of the SQS Dead-Letter Queue"
}

output "event_dlq_name" {
  value       = aws_sqs_queue.event_dlq.name
  description = "Name of the SQS Dead-Letter Queue"
}
