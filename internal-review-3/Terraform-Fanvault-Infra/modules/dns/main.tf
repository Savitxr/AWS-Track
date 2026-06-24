# Private Hosted Zone
resource "aws_route53_zone" "private" {
  name = "fanvault.internal"

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = "us-east-1"
  }

  tags = {
    Name        = "${var.project_name}-dns-zone"
    Environment = var.environment
  }
}

# A record mapping db.fanvault.internal to the MongoDB instance
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db"
  type    = "A"
  ttl     = "60"
  records = [var.mongodb_private_ip]
}
