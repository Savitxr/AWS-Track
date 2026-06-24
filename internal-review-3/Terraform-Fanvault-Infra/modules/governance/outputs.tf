output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.cloudfront.arn
  description = "ARN of the WAFv2 Web ACL for CloudFront"
}

output "waf_web_acl_id" {
  value       = aws_wafv2_web_acl.cloudfront.id
  description = "ID of the WAFv2 Web ACL for CloudFront"
}

output "waf_web_acl_name" {
  value       = aws_wafv2_web_acl.cloudfront.name
  description = "Name of the WAFv2 Web ACL for CloudFront"
}
