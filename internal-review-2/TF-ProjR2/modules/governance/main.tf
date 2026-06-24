# -----------------------------------------------------------------------------
# AWS WAFv2 Web ACL for CloudFront
# Associated globally at the CloudFront distribution level.
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "cloudfront" {
  name        = "${var.project_name}-cf-waf"
  description = "WAFv2 Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # 1. Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSetOnly"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # 2. Known Bad Inputs Rule Set
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSetOnly"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # 3. Amazon IP Reputation List
  rule {
    name     = "AWSManagedRulesAmazonIpReputationListOnly"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # 4. Rate Limiting Rule (100 requests per 5 minutes per IP)
  rule {
    name     = "RateLimitRule"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # 5. Geographic Restrictions Rule (Block specific countries if configured)
  dynamic "rule" {
    for_each = length(var.geo_blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 50

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.geo_blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-cf-waf"
    Environment = var.environment
  }
}
