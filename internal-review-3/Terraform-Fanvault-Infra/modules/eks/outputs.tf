output "cluster_name" {
  value       = aws_eks_cluster.cluster.name
  description = "The name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.cluster.endpoint
  description = "The endpoint of the EKS cluster"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
  description = "The CA data of the EKS cluster"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.oidc.arn
  description = "The ARN of the OIDC provider for IRSA"
}

output "oidc_provider_url" {
  value       = aws_iam_openid_connect_provider.oidc.url
  description = "The URL of the OIDC provider for IRSA"
}

output "node_role_name" {
  value       = aws_iam_role.node_role.name
  description = "Name of the EKS node IAM role (used by Karpenter EC2NodeClass)"
}

output "node_role_arn" {
  value       = aws_iam_role.node_role.arn
  description = "ARN of the EKS node IAM role"
}
