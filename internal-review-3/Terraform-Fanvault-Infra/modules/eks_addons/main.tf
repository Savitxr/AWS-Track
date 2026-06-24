data "aws_eks_addon_version" "cloudwatch_observability" {
  count              = var.enable_cloudwatch_observability ? 1 : 0
  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = "1.35"
  most_recent        = true
}

# ── Metrics Server ────────────────────────────────────────────────────────────
resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }
}

# ── CloudWatch Observability EKS Addon ───────────────────────────────────────
# Installs CloudWatch Agent + Fluent Bit for Container Insights and pod log collection
resource "aws_eks_addon" "cloudwatch_observability" {
  count                       = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = data.aws_eks_addon_version.cloudwatch_observability[0].version
  service_account_role_arn    = var.cloudwatch_agent_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudwatch-observability"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── EBS CSI Driver ───────────────────────────────────────────────────────────
# Required in EKS 1.23+ — in-tree aws-ebs provisioner is migrated to CSI.
# Without this addon, gp2/gp3 PVCs hang waiting for ebs.csi.aws.com provisioner.
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-csi-driver"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── Vertical Pod Autoscaler (recommendation-only) ────────────────────────────
# updater and admissionController disabled — only the recommender runs.
# kubectl describe vpa <name> -n <ns> shows right-sizing suggestions without mutating pods.
resource "helm_release" "vpa" {
  count      = var.enable_vpa ? 1 : 0
  name       = "vertical-pod-autoscaler"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "vpa"
  version    = var.vpa_version
  namespace  = "kube-system"

  set {
    name  = "updater.enabled"
    value = "false"
  }

  set {
    name  = "admissionController.enabled"
    value = "false"
  }

  set {
    name  = "recommender.enabled"
    value = "true"
  }

  set {
    name  = "recommender.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "recommender.resources.requests.memory"
    value = "128Mi"
  }
}
