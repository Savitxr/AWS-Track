output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "cloudfront_distribution_id" {
  value       = module.cloudfront.distribution_id
  description = "ID of the CloudFront distribution for prod product images"
}

output "cloudfront_domain_name" {
  value       = module.cloudfront.domain_name
  description = "CloudFront domain name (e.g. xxxxx.cloudfront.net)"
}

output "cloudfront_hosted_zone_id" {
  value       = module.cloudfront.hosted_zone_id
  description = "CloudFront hosted zone ID for Route 53 alias records"
}
