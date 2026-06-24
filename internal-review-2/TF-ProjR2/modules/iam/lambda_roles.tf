# -----------------------------------------------------------------------------
# IAM Role and Policies for Event-Driven Lambda Consumers
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_consumers" {
  name = "${var.project_name}-lambda-consumers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-consumers-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_consumers.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_resources" {
  name = "${var.project_name}-lambda-consumers-resources-policy"
  role = aws_iam_role.lambda_consumers.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBReadWriteAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          var.dynamodb_table_audit_logs_arn,
          var.dynamodb_table_products_arn,
          "${var.dynamodb_table_products_arn}/index/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_product_images_arn,
          "${var.s3_bucket_product_images_arn}/*"
        ]
      },
      {
        Sid    = "SNSPublishAccess"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          var.sns_topic_low_inventory_arn,
          var.sns_topic_product_upload_failure_arn
        ]
      },
      {
        Sid    = "KMSDecryptSNS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          var.sns_kms_key_arn
        ]
      }
    ]
  })
}
