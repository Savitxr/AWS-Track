output "helm_release_name" {
  value       = helm_release.argocd.name
  description = "The name of the ArgoCD Helm release"
}

output "namespace" {
  value       = helm_release.argocd.namespace
  description = "The namespace ArgoCD is installed in"
}
