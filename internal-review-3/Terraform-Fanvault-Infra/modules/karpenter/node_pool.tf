# Same reasoning as node_class.tf — NodePool CRD is installed by Karpenter Helm,
# so we must defer creation to apply time via local-exec.
resource "null_resource" "node_pool" {
  triggers = {
    project_name     = var.project_name
    environment      = var.environment
    instance_types   = join(",", var.instance_types)
    max_nodes_cpu    = var.max_nodes_cpu
    max_nodes_memory = var.max_nodes_memory
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: karpenter.sh/v1
      kind: NodePool
      metadata:
        name: ${var.project_name}-default
      spec:
        template:
          metadata:
            labels:
              Environment: ${var.environment}
          spec:
            nodeClassRef:
              group: karpenter.k8s.aws
              kind: EC2NodeClass
              name: ${var.project_name}-default
            requirements:
              - key: kubernetes.io/arch
                operator: In
                values: [amd64]
              - key: karpenter.sh/capacity-type
                operator: In
                values: [spot, on-demand]
              - key: node.kubernetes.io/instance-type
                operator: In
                values: [${join(", ", var.instance_types)}]
              - key: topology.kubernetes.io/zone
                operator: In
                values: [us-east-1a, us-east-1b]
        limits:
          cpu: "${var.max_nodes_cpu}"
          memory: "${var.max_nodes_memory}"
        disruption:
          consolidationPolicy: WhenEmptyOrUnderutilized
          consolidateAfter: 30s
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete nodepool ${self.triggers.project_name}-default --ignore-not-found=true"
  }

  depends_on = [null_resource.ec2_node_class]
}
