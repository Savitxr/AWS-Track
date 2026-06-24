# =============================================================================
# EKS Monitoring Module — CloudWatch Alarms and Dashboard for EKS workloads
# Covers: DynamoDB throttles, Lambda errors/duration, SNS delivery failures
# =============================================================================

# ── DynamoDB Read Throttle Alarms ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  for_each = var.dynamodb_tables

  alarm_name          = "${var.project_name}-${var.environment}-ddb-${each.key}-read-throttle"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "DynamoDB table ${each.value} has read throttle events"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── DynamoDB Write Throttle Alarms ────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  for_each = var.dynamodb_tables

  alarm_name          = "${var.project_name}-${var.environment}-ddb-${each.key}-write-throttle"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "DynamoDB table ${each.value} has write throttle events"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── Lambda Error Alarms ───────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_functions

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.key}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function ${each.value} has execution errors"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── Lambda Duration Alarms (>10s average) ────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.lambda_functions

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = 10000
  alarm_description   = "Lambda function ${each.value} average duration exceeds 10s"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── SNS Delivery Failure Alarms ───────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "sns_delivery_failures" {
  for_each = var.sns_topics

  alarm_name          = "${var.project_name}-${var.environment}-sns-${each.key}-delivery-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "SNS topic ${each.value} has delivery failures"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-observability-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# FanVault ${upper(var.environment)} Observability Dashboard\nEvent-driven architecture monitoring: DynamoDB · Lambda · SNS · AI Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB Throttle Events"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = concat(
            [for k, v in var.dynamodb_tables : ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", v, { label = "${k} Read" }]],
            [for k, v in var.dynamodb_tables : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", v, { label = "${k} Write" }]]
          )
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            for k, v in var.lambda_functions : ["AWS/Lambda", "Errors", "FunctionName", v, { label = k }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (avg ms)"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            for k, v in var.lambda_functions : ["AWS/Lambda", "Duration", "FunctionName", v, { label = k }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "SNS Delivery Failures"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            for k, v in var.sns_topics : ["AWS/SNS", "NumberOfNotificationsFailed", "TopicName", v, { label = k }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "AI Service Request Count"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["FanVault/AI", "RequestCount", "Service", "ai-service", "Environment", var.environment, { label = "Requests" }],
            ["FanVault/AI", "SuccessCount", "Service", "ai-service", "Environment", var.environment, { label = "Successes" }],
            ["FanVault/AI", "FailureCount", "Service", "ai-service", "Environment", var.environment, { label = "Failures" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "AI Service Latency (ms)"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["FanVault/AI", "Latency", "Service", "ai-service", "Environment", var.environment, { label = "Avg Latency" }]
          ]
        }
      }
    ]
  })
}
