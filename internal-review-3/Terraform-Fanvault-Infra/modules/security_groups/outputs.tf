output "alb_sg_id" {
  value       = aws_security_group.alb.id
  description = "ID of the ALB security group"
}

output "frontend_sg_id" {
  value       = aws_security_group.frontend.id
  description = "ID of the frontend Nginx security group"
}

output "backend_sg_id" {
  value       = aws_security_group.backend.id
  description = "ID of the backend App security group"
}

output "bastion_sg_id" {
  value       = aws_security_group.bastion.id
  description = "ID of the Bastion security group"
}

output "vpc_endpoints_sg_id" {
  value       = aws_security_group.vpc_endpoints.id
  description = "ID of the security group for VPC Endpoints"
}
