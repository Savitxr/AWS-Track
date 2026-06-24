resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.database.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-s3-gateway-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.database.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-dynamodb-gateway-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.backend_private[*].id
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.backend_private[*].id
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.backend_private[*].id
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2messages-endpoint"
  })
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.backend_private[*].id
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-secretsmanager-endpoint"
  })
}
