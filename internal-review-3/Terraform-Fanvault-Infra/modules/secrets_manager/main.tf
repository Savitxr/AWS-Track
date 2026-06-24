resource "aws_secretsmanager_secret" "secret" {
  name                    = "${var.project_name}-${var.environment}-app-secrets"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode(var.secret_values)
}
