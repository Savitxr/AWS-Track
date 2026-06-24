# =============================================================================
# Monitoring Module — Observability Tier (Alarms, Dashboard, Log Groups)
# =============================================================================

# ── 1. CloudWatch Log Groups for Lambda Consumers ─────────────────────────────
# Set with 1-day retention to manage log lifecycle cost-effectively.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = var.lambdas
  name              = "/aws/lambda/${each.value}"
  retention_in_days = 1 # Minimum retention equal/higher than 1 day

  tags = {
    Name        = "/aws/lambda/${each.value}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 2. CloudWatch Alarms: Application Routing ─────────────────────────────────

# ALB 5XX count alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alarm when ALB 5XX error count is >= 5 in a 1-minute period"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group 5XX count alarm (for each Target Group)
resource "aws_cloudwatch_metric_alarm" "tg_5xx" {
  for_each            = var.target_groups
  alarm_name          = "${var.project_name}-tg-${each.key}-5xx-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when target group ${each.key} 5XX error count is >= 1 in a 1-minute period"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 3. CloudWatch Alarms: Compute Layer ───────────────────────────────────────

# Auto Scaling Group average CPU utilization > 80%
resource "aws_cloudwatch_metric_alarm" "asg_cpu" {
  for_each            = var.asgs
  alarm_name          = "${var.project_name}-asg-${each.key}-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when average CPU utilization for ASG ${each.value} exceeds 80% over 5 minutes"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    AutoScalingGroupName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Bastion Instance CPU utilization > 80%
resource "aws_cloudwatch_metric_alarm" "bastion_cpu" {
  alarm_name          = "${var.project_name}-bastion-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when average CPU utilization for Bastion host exceeds 80% over 10 minutes"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    InstanceId = var.bastion_instance_id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Bastion Instance Status Check Failed (fails system/instance status)
resource "aws_cloudwatch_metric_alarm" "bastion_status_check" {
  alarm_name          = "${var.project_name}-bastion-status-check-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alarm when Bastion host fails hardware or software status checks"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    InstanceId = var.bastion_instance_id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 4. CloudWatch Alarms: Database Layer (DynamoDB Throttling) ───────────────

# DynamoDB Read Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  for_each            = var.dynamodb_tables
  alarm_name          = "${var.project_name}-ddb-${each.key}-read-throttle"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when read requests to DynamoDB table ${each.value} are throttled"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    TableName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# DynamoDB Write Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  for_each            = var.dynamodb_tables
  alarm_name          = "${var.project_name}-ddb-${each.key}-write-throttle"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when write requests to DynamoDB table ${each.value} are throttled"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    TableName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 5. CloudWatch Alarms: Serverless Layer (Lambdas) ─────────────────────────

# Lambda Execution Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = var.lambdas
  alarm_name          = "${var.project_name}-lambda-${each.key}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when Lambda function ${each.value} encounters execution errors"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda Execution Duration Warnings (> 10s average duration)
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each            = var.lambdas
  alarm_name          = "${var.project_name}-lambda-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = 10000 # 10 seconds (in milliseconds)
  alarm_description   = "Alarm when Lambda function ${each.value} average execution duration exceeds 10s"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 6. CloudWatch Alarms: SNS Notification Layer ─────────────────────────────

# SNS Notification Delivery Failures
resource "aws_cloudwatch_metric_alarm" "sns_delivery_failures" {
  for_each            = var.sns_topics
  alarm_name          = "${var.project_name}-sns-${each.key}-delivery-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when SNS notifications delivery fails for topic ${each.value}"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    TopicName = each.value
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── 7. CloudWatch Dashboard ───────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "observability" {
  dashboard_name = "${var.project_name}-observability-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Header Text Widget
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# 🛡️ FanVault v2 Observability Dashboard\nMonitoring tier for the FanVault production environment on AWS."
        }
      },
      # Row 1: ALB & Target Group Errors (Application performance)
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ALB 5XX" }]
          ]
          period  = 60
          stat    = "Sum"
          region  = "us-east-1"
          title   = "ALB 5XX Error Count"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            for name, suffix in var.target_groups :
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", suffix, { label = "${name} 5XX" }]
          ]
          period  = 60
          stat    = "Sum"
          region  = "us-east-1"
          title   = "Target Groups 5XX Error Count"
          view    = "timeSeries"
          stacked = false
        }
      },
      # Row 2: Compute Metrics (ASG & Bastion CPU)
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            for asg in values(var.asgs) :
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", asg, { label = asg }]
          ]
          period  = 300
          stat    = "Average"
          region  = "us-east-1"
          title   = "ASG CPU Utilization"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              max = 100
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.bastion_instance_id, { label = "Bastion CPU" }]
          ]
          period  = 300
          stat    = "Average"
          region  = "us-east-1"
          title   = "Bastion CPU Utilization"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              max = 100
              min = 0
            }
          }
        }
      },
      # Row 3: DynamoDB Throttling Events
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = concat(
            [for table_name, real_name in var.dynamodb_tables : ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", real_name, { label = "${table_name} Read Throttle" }]],
            [for table_name, real_name in var.dynamodb_tables : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", real_name, { label = "${table_name} Write Throttle" }]]
          )
          period  = 60
          stat    = "Sum"
          region  = "us-east-1"
          title   = "DynamoDB Throttling Events"
          view    = "timeSeries"
          stacked = false
        }
      },
      # Row 4: Lambda Executions, Errors & Durations
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            for fn in values(var.lambdas) :
            ["AWS/Lambda", "Errors", "FunctionName", fn, { label = "${fn} Errors" }]
          ]
          period  = 60
          stat    = "Sum"
          region  = "us-east-1"
          title   = "Lambda Error Count"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 12
        height = 6
        properties = {
          metrics = [
            for fn in values(var.lambdas) :
            ["AWS/Lambda", "Duration", "FunctionName", fn, { label = "${fn} Duration" }]
          ]
          period  = 60
          stat    = "Average"
          region  = "us-east-1"
          title   = "Lambda Duration (ms)"
          view    = "timeSeries"
          stacked = false
        }
      },
      # Row 5: SNS Notifications failures
      {
        type   = "metric"
        x      = 12
        y      = 20
        width  = 12
        height = 6
        properties = {
          metrics = [
            for topic in values(var.sns_topics) :
            ["AWS/SNS", "NumberOfNotificationsFailed", "TopicName", topic, { label = "${topic} Failures" }]
          ]
          period  = 60
          stat    = "Sum"
          region  = "us-east-1"
          title   = "SNS Notification Delivery Failures"
          view    = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}
