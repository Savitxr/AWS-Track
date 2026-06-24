data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# KMS Key for SNS encryption at rest
# -----------------------------------------------------------------------------
resource "aws_kms_key" "sns_key" {
  description             = "KMS key for SNS topic and SQS queue encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns_kms_policy.json

  tags = {
    Name        = "${var.project_name}-sns-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "sns_key_alias" {
  name          = "alias/${var.project_name}-sns-key"
  target_key_id = aws_kms_key.sns_key.key_id
}

data "aws_iam_policy_document" "sns_kms_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSNSToUseKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEventBridgeToUseKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSQSToUseKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
  }
}



# -----------------------------------------------------------------------------
# SQS Dead-Letter Queue for SNS Subscription Failures
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "sns_dlq" {
  name                      = "${var.project_name}-sns-dlq"
  kms_master_key_id         = aws_kms_key.sns_key.id
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-sns-dlq"
    Environment = var.environment
  }
}

resource "aws_sqs_queue_policy" "sns_dlq_policy" {
  queue_url = aws_sqs_queue.sns_dlq.id
  policy    = data.aws_iam_policy_document.sns_dlq_policy_doc.json
}

data "aws_iam_policy_document" "sns_dlq_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.sns_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# SNS Topics
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "low_inventory" {
  name              = "${var.project_name}-low-inventory-alerts"
  kms_master_key_id = aws_kms_key.sns_key.id

  sqs_success_feedback_role_arn       = var.sns_feedback_role_arn
  sqs_failure_feedback_role_arn       = var.sns_feedback_role_arn
  lambda_success_feedback_role_arn    = var.sns_feedback_role_arn
  lambda_failure_feedback_role_arn    = var.sns_feedback_role_arn
  sqs_success_feedback_sample_rate    = 100
  lambda_success_feedback_sample_rate = 100

  tags = {
    Name        = "${var.project_name}-low-inventory-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic" "order_failure" {
  name              = "${var.project_name}-order-failure-alerts"
  kms_master_key_id = aws_kms_key.sns_key.id

  sqs_success_feedback_role_arn       = var.sns_feedback_role_arn
  sqs_failure_feedback_role_arn       = var.sns_feedback_role_arn
  lambda_success_feedback_role_arn    = var.sns_feedback_role_arn
  lambda_failure_feedback_role_arn    = var.sns_feedback_role_arn
  sqs_success_feedback_sample_rate    = 100
  lambda_success_feedback_sample_rate = 100

  tags = {
    Name        = "${var.project_name}-order-failure-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic" "product_upload" {
  name              = "${var.project_name}-product-upload-failures"
  kms_master_key_id = aws_kms_key.sns_key.id

  sqs_success_feedback_role_arn       = var.sns_feedback_role_arn
  sqs_failure_feedback_role_arn       = var.sns_feedback_role_arn
  lambda_success_feedback_role_arn    = var.sns_feedback_role_arn
  lambda_failure_feedback_role_arn    = var.sns_feedback_role_arn
  sqs_success_feedback_sample_rate    = 100
  lambda_success_feedback_sample_rate = 100

  tags = {
    Name        = "${var.project_name}-product-upload-failures"
    Environment = var.environment
  }
}

resource "aws_sns_topic" "admin_operational" {
  name              = "${var.project_name}-admin-operational-alerts"
  kms_master_key_id = aws_kms_key.sns_key.id

  sqs_success_feedback_role_arn       = var.sns_feedback_role_arn
  sqs_failure_feedback_role_arn       = var.sns_feedback_role_arn
  lambda_success_feedback_role_arn    = var.sns_feedback_role_arn
  lambda_failure_feedback_role_arn    = var.sns_feedback_role_arn
  sqs_success_feedback_sample_rate    = 100
  lambda_success_feedback_sample_rate = 100

  tags = {
    Name        = "${var.project_name}-admin-operational-alerts"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Primary SQS Queues (Subscribed to topics to capture alerts)
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "low_inventory_queue" {
  name                      = "${var.project_name}-low-inventory-alerts-queue"
  kms_master_key_id         = aws_kms_key.sns_key.id
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-low-inventory-alerts-queue"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "order_failure_queue" {
  name                      = "${var.project_name}-order-failure-alerts-queue"
  kms_master_key_id         = aws_kms_key.sns_key.id
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-order-failure-alerts-queue"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "product_upload_queue" {
  name                      = "${var.project_name}-product-upload-failures-queue"
  kms_master_key_id         = aws_kms_key.sns_key.id
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-product-upload-failures-queue"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "admin_operational_queue" {
  name                      = "${var.project_name}-admin-operational-alerts-queue"
  kms_master_key_id         = aws_kms_key.sns_key.id
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-admin-operational-alerts-queue"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Local Maps & SQS Queue Policies
# -----------------------------------------------------------------------------
locals {
  topic_queues = {
    low_inventory = {
      queue_id  = aws_sqs_queue.low_inventory_queue.id
      queue_arn = aws_sqs_queue.low_inventory_queue.arn
      topic_arn = aws_sns_topic.low_inventory.arn
    }
    order_failure = {
      queue_id  = aws_sqs_queue.order_failure_queue.id
      queue_arn = aws_sqs_queue.order_failure_queue.arn
      topic_arn = aws_sns_topic.order_failure.arn
    }
    product_upload = {
      queue_id  = aws_sqs_queue.product_upload_queue.id
      queue_arn = aws_sqs_queue.product_upload_queue.arn
      topic_arn = aws_sns_topic.product_upload.arn
    }
    admin_operational = {
      queue_id  = aws_sqs_queue.admin_operational_queue.id
      queue_arn = aws_sqs_queue.admin_operational_queue.arn
      topic_arn = aws_sns_topic.admin_operational.arn
    }
  }
}

resource "aws_sqs_queue_policy" "sqs_policy" {
  for_each = local.topic_queues

  queue_url = each.value.queue_id
  policy    = data.aws_iam_policy_document.sqs_policy_doc[each.key].json
}

data "aws_iam_policy_document" "sqs_policy_doc" {
  for_each = local.topic_queues

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [each.value.queue_arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [each.value.topic_arn]
    }
  }
}

# -----------------------------------------------------------------------------
# SNS Topic Subscriptions (SQS)
# -----------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "low_inventory_sqs" {
  topic_arn = aws_sns_topic.low_inventory.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.low_inventory_queue.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sns_dlq.arn
  })
}

resource "aws_sns_topic_subscription" "order_failure_sqs" {
  topic_arn = aws_sns_topic.order_failure.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_failure_queue.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sns_dlq.arn
  })
}

resource "aws_sns_topic_subscription" "product_upload_sqs" {
  topic_arn = aws_sns_topic.product_upload.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.product_upload_queue.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sns_dlq.arn
  })
}

resource "aws_sns_topic_subscription" "admin_operational_sqs" {
  topic_arn = aws_sns_topic.admin_operational.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.admin_operational_queue.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sns_dlq.arn
  })
}

# -----------------------------------------------------------------------------
# SNS Topic Subscriptions (Email - Optional)
# -----------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "low_inventory_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.low_inventory.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "order_failure_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.order_failure.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "product_upload_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.product_upload.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "admin_operational_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.admin_operational.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
