output "distribution_id" {
  value       = aws_cloudfront_distribution.product_images.id
  description = "ID of the CloudFront distribution"
}

output "domain_name" {
  value       = aws_cloudfront_distribution.product_images.domain_name
  description = "Domain name of the CloudFront distribution (e.g. xxxxx.cloudfront.net)"
}

output "hosted_zone_id" {
  value       = aws_cloudfront_distribution.product_images.hosted_zone_id
  description = "CloudFront hosted zone ID (used for Route 53 alias records)"
}

output "arn" {
  value       = aws_cloudfront_distribution.product_images.arn
  description = "ARN of the CloudFront distribution"
}
