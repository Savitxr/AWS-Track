# kubernetes_manifest cannot be used here because the EC2NodeClass CRD is installed by
# the Karpenter Helm release in the same apply — the provider validates CRDs at plan time.
# null_resource + local-exec defers the kubectl apply to after helm_release.karpenter runs.
resource "null_resource" "ec2_node_class" {
  triggers = {
    cluster_name   = var.cluster_name
    node_role_name = var.node_iam_role_name
    project_name   = var.project_name
    environment    = var.environment
    ami_selector   = "al2023@latest"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata:
        name: ${var.project_name}-default
      spec:
        # Karpenter v1 API removed amiFamily as a standalone field.
        # amiSelectorTerms with alias is the replacement — alias: al2023@latest
        # resolves to the latest EKS-optimised AL2023 AMI for the cluster version.
        amiSelectorTerms:
          - alias: al2023@latest
        role: ${var.node_iam_role_name}
        subnetSelectorTerms:
          - tags:
              kubernetes.io/cluster/${var.cluster_name}: owned
        securityGroupSelectorTerms:
          - tags:
              kubernetes.io/cluster/${var.cluster_name}: owned
        blockDeviceMappings:
          - deviceName: /dev/xvda
            ebs:
              volumeSize: 20Gi
              volumeType: gp3
              encrypted: true
              deleteOnTermination: true
        tags:
          Environment: ${var.environment}
          Project: ${var.project_name}
          ManagedBy: karpenter
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete ec2nodeclass ${self.triggers.project_name}-default --ignore-not-found=true"
  }

  depends_on = [helm_release.karpenter]
}
