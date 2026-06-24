output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC created"
}

output "public_subnets" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

output "frontend_private_subnets" {
  value       = aws_subnet.frontend_private[*].id
  description = "IDs of the frontend private subnets"
}

output "backend_private_subnets" {
  value       = aws_subnet.backend_private[*].id
  description = "IDs of the backend private subnets"
}

output "database_private_subnets" {
  value       = aws_subnet.database_private[*].id
  description = "IDs of the database private subnets"
}
