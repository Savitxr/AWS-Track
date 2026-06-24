output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion jump host"
}

output "alb_arn_suffix" {
  value       = aws_lb.main.arn_suffix
  description = "ARN suffix of the Application Load Balancer"
}

output "frontend_tg_arn_suffix" {
  value       = aws_lb_target_group.frontend.arn_suffix
  description = "ARN suffix of the frontend Target Group"
}

output "identity_tg_arn_suffix" {
  value       = aws_lb_target_group.identity.arn_suffix
  description = "ARN suffix of the identity Target Group"
}

output "commerce_tg_arn_suffix" {
  value       = aws_lb_target_group.commerce.arn_suffix
  description = "ARN suffix of the commerce Target Group"
}

output "lambda_tg_arn_suffix" {
  value       = aws_lb_target_group.lambda.arn_suffix
  description = "ARN suffix of the Lambda Target Group"
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "Instance ID of the Bastion host"
}

output "frontend_asg_name" {
  value       = aws_autoscaling_group.frontend.name
  description = "Name of the Frontend Auto Scaling Group"
}

output "backend_asg_name" {
  value       = aws_autoscaling_group.backend.name
  description = "Name of the Backend Auto Scaling Group"
}



