output "profiles_table_name" {
  value = aws_dynamodb_table.profiles.name
}

output "profiles_table_arn" {
  value = aws_dynamodb_table.profiles.arn
}

output "products_table_name" {
  value = aws_dynamodb_table.products.name
}

output "products_table_arn" {
  value = aws_dynamodb_table.products.arn
}

output "orders_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "orders_table_arn" {
  value = aws_dynamodb_table.orders.arn
}

output "audit_logs_table_name" {
  value = aws_dynamodb_table.audit_logs.name
}

output "audit_logs_table_arn" {
  value = aws_dynamodb_table.audit_logs.arn
}

output "metadata_table_name" {
  value = aws_dynamodb_table.metadata.name
}

output "metadata_table_arn" {
  value = aws_dynamodb_table.metadata.arn
}
