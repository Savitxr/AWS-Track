# -----------------------------------------------------------------------------
# IAM Role for SNS CloudWatch Delivery Logging Feedback
# -----------------------------------------------------------------------------
resource "aws_iam_role" "sns_feedback_role" {
  name = "${var.project_name}-sns-feedback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-sns-feedback-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "sns_feedback_policy" {
  name = "${var.project_name}-sns-feedback-policy"
  role = aws_iam_role.sns_feedback_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
