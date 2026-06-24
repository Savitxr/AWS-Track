resource "aws_dynamodb_table" "profiles" {
  name         = "${var.project_name}-${var.environment}-profiles"
  billing_mode = var.billing_mode
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-profiles"
    Environment = var.environment
    Owner       = var.owner
    Service     = "fanvault-user-service"
  }
}

resource "aws_dynamodb_table" "products" {
  name         = "${var.project_name}-${var.environment}-products"
  billing_mode = var.billing_mode
  hash_key     = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  attribute {
    name = "sku"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "franchise"
    type = "S"
  }

  global_secondary_index {
    name            = "sku-index"
    hash_key        = "sku"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "category-franchise-index"
    hash_key        = "category"
    range_key       = "franchise"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-products"
    Environment = var.environment
    Owner       = var.owner
    Service     = "fanvault-commerce-service"
  }
}

resource "aws_dynamodb_table" "orders" {
  name         = "${var.project_name}-${var.environment}-orders"
  billing_mode = var.billing_mode
  hash_key     = "orderId"

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "orderNumber"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-createdAt-index"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "orderNumber-index"
    hash_key        = "orderNumber"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-createdAt-index"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-orders"
    Environment = var.environment
    Owner       = var.owner
    Service     = "fanvault-commerce-service"
  }
}

resource "aws_dynamodb_table" "audit_logs" {
  name         = "${var.project_name}-${var.environment}-audit-logs"
  billing_mode = var.billing_mode
  hash_key     = "logId"

  attribute {
    name = "logId"
    type = "S"
  }

  attribute {
    name = "entityType"
    type = "S"
  }

  attribute {
    name = "adminId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  global_secondary_index {
    name            = "entityType-timestamp-index"
    hash_key        = "entityType"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "adminId-timestamp-index"
    hash_key        = "adminId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttlExpiry"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-audit-logs"
    Environment = var.environment
    Owner       = var.owner
    Service     = "fanvault-commerce-service"
  }
}

resource "aws_dynamodb_table" "metadata" {
  name         = "${var.project_name}-${var.environment}-metadata"
  billing_mode = var.billing_mode
  hash_key     = "metaType"
  range_key    = "metaId"

  attribute {
    name = "metaType"
    type = "S"
  }

  attribute {
    name = "metaId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-metadata"
    Environment = var.environment
    Owner       = var.owner
    Service     = "fanvault-commerce-service"
  }
}
