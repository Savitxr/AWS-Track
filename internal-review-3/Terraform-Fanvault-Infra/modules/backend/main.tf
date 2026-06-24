# -----------------------------------------------------------------------------
# Dynamic AMI Lookup (Ubuntu 22.04 LTS)
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Bastion & MongoDB Instances
# -----------------------------------------------------------------------------

# Public Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  subnet_id              = var.public_subnets[0] # Place in public-1a
  vpc_security_group_ids = [var.bastion_sg_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-bastion"
    Environment = var.environment
  }
}


# -----------------------------------------------------------------------------
# ALB & Target Groups
# -----------------------------------------------------------------------------

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets # Span public 1a and 1b

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group 1: Nginx Frontend
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/index.html"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-frontend-tg"
    Environment = var.environment
  }
}

# Target Group 2: Identity Service Node
resource "aws_lb_target_group" "identity" {
  name     = "${var.project_name}-identity-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "3001"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-identity-tg"
    Environment = var.environment
  }
}

# Target Group 3: Commerce Service Node
resource "aws_lb_target_group" "commerce" {
  name     = "${var.project_name}-commerce-tg"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "3002"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-commerce-tg"
    Environment = var.environment
  }
}

# Target Group 4: Lambda Target Group (No port/protocol since it targets Lambda)
resource "aws_lb_target_group" "lambda" {
  name        = "${var.project_name}-lambda-tg"
  target_type = "lambda"

  tags = {
    Name        = "${var.project_name}-lambda-tg"
    Environment = var.environment
  }
}

# Grant permission to ALB to invoke Lambda
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = var.lambda_function_arn
  depends_on       = [aws_lambda_permission.alb]
}

# -----------------------------------------------------------------------------
# ALB Listeners & Rules
# -----------------------------------------------------------------------------

# HTTP Listener (Port 80) -> Forward to Frontend target group by default
# Note: HTTPS termination will be handled by CloudFront later.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access Denied: Direct load balancer access is forbidden."
      status_code  = "403"
    }
  }
}

# Rule 1 (P5): Host arch.fanvault.com -> Lambda Target Group
resource "aws_lb_listener_rule" "arch_host" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  condition {
    host_header {
      values = ["arch.fanvault.com"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# Rule 2 (P10): Path /api/auth/* -> Identity TG
resource "aws_lb_listener_rule" "auth_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.identity.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

resource "aws_lb_listener_rule" "admin_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce.arn
  }

  condition {
    path_pattern {
      values = ["/api/admin*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# Rule 3 (P20): Path /api/users/* -> Identity TG
resource "aws_lb_listener_rule" "users_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.identity.arn
  }

  condition {
    path_pattern {
      values = ["/api/users*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# Rule 4 (P30): Path /api/products/* -> Commerce TG
resource "aws_lb_listener_rule" "products_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce.arn
  }

  condition {
    path_pattern {
      values = ["/api/products*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# Rule 5 (P40): Path /api/orders/* -> Commerce TG
resource "aws_lb_listener_rule" "orders_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# Rule 6 (P99): Default Frontend Routing via CloudFront Custom Header
resource "aws_lb_listener_rule" "frontend_default" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [var.cloudfront_to_alb_custom_header]
    }
  }
}

# -----------------------------------------------------------------------------
# Launch Templates (2 total: Frontend + Backend)
# -----------------------------------------------------------------------------
# ARCHITECTURE: Monolithic 2-tier EC2 deployment.
# - Frontend LT : Nginx serving compiled React/Vite static files (port 80)
# - Backend LT  : Runs BOTH fanvault-user-auth-service (port 3001)
#                 AND fanvault-commerce-service (port 3002) on the same instance.
#   The single Backend ASG registers to BOTH identity-tg and commerce-tg so
#   the ALB can still route /api/auth/* → port 3001 and /api/products/* → port 3002.
# -----------------------------------------------------------------------------

# Launch Template 1: Frontend (Nginx / React static SPA)
resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.project_name}-frontend-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # IAM Instance Profile — grants SSM (git config) + CloudWatch access
  iam_instance_profile {
    name = var.ec2_frontend_instance_profile_name
  }

  # user_data installs Nginx, deploys the compiled SPA, and starts Nginx
  user_data = base64encode(file("${path.module}/user_data/user_data_frontend.sh"))

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.frontend_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-frontend-node"
      Environment = var.environment
    }
  }
}

# Launch Template 2: Backend (Identity + Commerce — monolithic node)
# Single template boots BOTH Node.js services on the same EC2 instance.
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # IAM Instance Profile — grants DynamoDB + SSM + S3 + CloudWatch access
  iam_instance_profile {
    name = var.ec2_backend_instance_profile_name
  }

  # user_data installs Node.js 20, deploys both services, starts them via PM2
  user_data = base64encode(file("${path.module}/user_data/user_data_backend.sh"))

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-backend-node"
      Environment = var.environment
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Groups (2 total: Frontend + Backend)
# -----------------------------------------------------------------------------

# ASG 1: Frontend
resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.project_name}-frontend-asg-"
  vpc_zone_identifier = var.frontend_private_subnets
  target_group_arns   = [aws_lb_target_group.frontend.arn]
  desired_capacity    = 1 # Testing: 1 instance. Change to 2 for production.
  min_size            = 1
  max_size            = 1 # Set to 4 in production.

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend-asg"
    propagate_at_launch = false
  }
}

# ASG 2: Backend (Monolithic — runs both Identity :3001 and Commerce :3002)
# Registered to BOTH target groups so the ALB can route by path to each port.
resource "aws_autoscaling_group" "backend" {
  name_prefix         = "${var.project_name}-backend-asg-"
  vpc_zone_identifier = var.backend_private_subnets
  target_group_arns = [
    aws_lb_target_group.identity.arn, # ALB routes /api/auth/* and /api/users/* here
    aws_lb_target_group.commerce.arn, # ALB routes /api/products/* and /api/orders/* here
  ]
  desired_capacity = 1 # Testing: 1 instance. Change to 2 for production.
  min_size         = 1
  max_size         = 1 # Set to 4 in production.

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg"
    propagate_at_launch = false
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Target Tracking Policies (CPU Utilization > 70%)
# Disabled at min/max=1. These activate automatically when max is raised.
# -----------------------------------------------------------------------------

resource "aws_autoscaling_policy" "frontend_cpu" {
  name                   = "${var.project_name}-frontend-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "backend_cpu" {
  name                   = "${var.project_name}-backend-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
