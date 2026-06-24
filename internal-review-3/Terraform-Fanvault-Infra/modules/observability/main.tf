resource "random_password" "grafana_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}?"
}

# Store Grafana admin password in SSM (never in state plaintext)
resource "aws_ssm_parameter" "grafana_admin_password" {
  name        = "/${var.project_name}/grafana/admin_password"
  type        = "SecureString"
  value       = random_password.grafana_admin.result
  description = "Grafana admin password for ${var.project_name}-${var.environment}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-grafana-admin-password"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

locals {
  helm_vars = {
    project_name          = var.project_name
    environment           = var.environment
    aws_region            = var.aws_region
    sns_topic_arn         = var.sns_topic_arn
    prometheus_retention  = var.prometheus_retention_days
    prometheus_storage    = var.prometheus_storage_size
    grafana_storage       = var.grafana_storage_size
    alertmanager_storage  = var.alertmanager_storage_size
    grafana_password      = random_password.grafana_admin.result
    alertmanager_role_arn = var.alertmanager_irsa_role_arn
  }
}

# ── kube-prometheus-stack ─────────────────────────────────────────────────────
# Wipe any stale Helm release secrets left by killed applies before installing.
# cleanup_on_fail only runs when Helm itself exits cleanly; an external kill
# (Ctrl-C, OOM, timeout) leaves the secret behind and blocks the next apply.
resource "null_resource" "helm_secret_cleanup" {
  triggers = { always_run = timestamp() }
  provisioner "local-exec" {
    command = "kubectl delete secret -n monitoring -l owner=helm,name=kube-prometheus-stack --ignore-not-found 2>/dev/null || true"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_version
  namespace        = "monitoring"
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 600

  values = [templatefile("${path.module}/values/kube-prometheus-stack.yaml.tpl", local.helm_vars)]

  depends_on = [null_resource.helm_secret_cleanup]
}

# ── Grafana Dashboards (ConfigMap auto-discovery) ─────────────────────────────
# Grafana sidecar picks up any ConfigMap in 'monitoring' with label grafana_dashboard=1

resource "kubernetes_config_map" "dashboard_cluster_overview" {
  metadata {
    name      = "dashboard-cluster-overview"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "cluster-overview.json" = jsonencode({
      "__inputs" : [],
      "__requires" : [],
      "annotations" : { "list" : [] },
      "editable" : true,
      "gnetId" : 7249,
      "graphTooltip" : 0,
      "id" : null,
      "links" : [],
      "panels" : [],
      "refresh" : "30s",
      "schemaVersion" : 16,
      "style" : "dark",
      "tags" : ["kubernetes", "cluster"],
      "title" : "Kubernetes Cluster Overview",
      "uid" : "fanvault-cluster-overview",
      "version" : 1
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "dashboard_node_exporter" {
  metadata {
    name      = "dashboard-node-exporter"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "node-exporter.json" = jsonencode({
      "gnetId" : 1860,
      "title" : "Node Exporter Full",
      "uid" : "fanvault-node-exporter",
      "tags" : ["node", "infrastructure"],
      "panels" : [],
      "version" : 1
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "dashboard_kubernetes_deployments" {
  metadata {
    name      = "dashboard-kubernetes-deployments"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "kubernetes-deployments.json" = jsonencode({
      "gnetId" : 8588,
      "title" : "Kubernetes Deployments",
      "uid" : "fanvault-k8s-deployments",
      "tags" : ["kubernetes", "deployments"],
      "panels" : [],
      "version" : 1
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "dashboard_fanvault_services" {
  metadata {
    name      = "dashboard-fanvault-services"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  # Dynamic dashboard — uses label selectors not hardcoded pod names
  data = {
    "fanvault-services.json" = jsonencode({
      "title" : "FanVault Application Services",
      "uid" : "fanvault-services",
      "tags" : ["fanvault", "application"],
      "refresh" : "30s",
      "templating" : {
        "list" : [
          {
            "name" : "namespace",
            "type" : "query",
            "query" : "label_values(kube_pod_info, namespace)",
            "label" : "Namespace",
            "multi" : false,
            "includeAll" : false
          },
          {
            "name" : "deployment",
            "type" : "query",
            "query" : "label_values(kube_deployment_labels{namespace=\"$namespace\"}, deployment)",
            "label" : "Deployment",
            "multi" : false,
            "includeAll" : true
          }
        ]
      },
      "panels" : [
        {
          "title" : "Pod CPU Usage by Deployment",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 0, "y" : 0 },
          "targets" : [
            {
              "expr" : "sum(rate(container_cpu_usage_seconds_total{namespace=~\"$namespace\",container!=\"\",container!=\"POD\"}[5m])) by (pod)",
              "legendFormat" : "{{ pod }}"
            }
          ]
        },
        {
          "title" : "Pod Memory Usage by Deployment",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 12, "y" : 0 },
          "targets" : [
            {
              "expr" : "sum(container_memory_working_set_bytes{namespace=~\"$namespace\",container!=\"\",container!=\"POD\"}) by (pod)",
              "legendFormat" : "{{ pod }}"
            }
          ]
        },
        {
          "title" : "HPA Replica Count",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 0, "y" : 8 },
          "targets" : [
            {
              "expr" : "kube_horizontalpodautoscaler_status_current_replicas{namespace=~\"$namespace\"}",
              "legendFormat" : "{{ horizontalpodautoscaler }} current"
            },
            {
              "expr" : "kube_horizontalpodautoscaler_spec_max_replicas{namespace=~\"$namespace\"}",
              "legendFormat" : "{{ horizontalpodautoscaler }} max"
            }
          ]
        },
        {
          "title" : "Pod Restart Rate",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 12, "y" : 8 },
          "targets" : [
            {
              "expr" : "rate(kube_pod_container_status_restarts_total{namespace=~\"$namespace\"}[15m]) * 900",
              "legendFormat" : "{{ pod }}/{{ container }}"
            }
          ]
        }
      ],
      "version" : 1
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "dashboard_ai_service" {
  metadata {
    name      = "dashboard-ai-service"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "ai-service.json" = jsonencode({
      "title" : "FanVault AI Service Metrics",
      "uid" : "fanvault-ai-service",
      "tags" : ["fanvault", "ai", "bedrock"],
      "refresh" : "30s",
      "panels" : [
        {
          "title" : "AI Request Count (CloudWatch)",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 0, "y" : 0 },
          "targets" : [
            {
              "expr" : "sum(rate(container_cpu_usage_seconds_total{namespace=~\"dev|prod\",pod=~\".*ai-service.*\"}[5m]))",
              "legendFormat" : "AI Service CPU"
            }
          ]
        },
        {
          "title" : "AI Service Pod Memory",
          "type" : "timeseries",
          "gridPos" : { "h" : 8, "w" : 12, "x" : 12, "y" : 0 },
          "targets" : [
            {
              "expr" : "sum(container_memory_working_set_bytes{namespace=~\"dev|prod\",pod=~\".*ai-service.*\",container!=\"\"})",
              "legendFormat" : "AI Service Memory"
            }
          ]
        }
      ],
      "version" : 1
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ── VPA Objects (recommendation-only) ─────────────────────────────────────────
# VerticalPodAutoscaler CRDs are installed by the VPA Helm release in eks_addons,
# which runs before this module (module-level depends_on in the environment).
# kubernetes_manifest validates CRDs at plan time; null_resource + local-exec defers
# to apply time when the CRDs already exist.
resource "null_resource" "vpa_dev_user_service" {
  triggers = {
    name = "dev-user-service-vpa"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: autoscaling.k8s.io/v1
      kind: VerticalPodAutoscaler
      metadata:
        name: dev-user-service-vpa
        namespace: dev
      spec:
        targetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: dev-user-service
        updatePolicy:
          updateMode: "Off"
        resourcePolicy:
          containerPolicies:
            - containerName: "*"
              minAllowed:
                cpu: 50m
                memory: 64Mi
              maxAllowed:
                cpu: "1"
                memory: 1Gi
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete vpa dev-user-service-vpa -n dev --ignore-not-found=true"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "null_resource" "vpa_dev_commerce_service" {
  triggers = {
    name = "dev-commerce-service-vpa"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: autoscaling.k8s.io/v1
      kind: VerticalPodAutoscaler
      metadata:
        name: dev-commerce-service-vpa
        namespace: dev
      spec:
        targetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: dev-commerce-service
        updatePolicy:
          updateMode: "Off"
        resourcePolicy:
          containerPolicies:
            - containerName: "*"
              minAllowed:
                cpu: 50m
                memory: 64Mi
              maxAllowed:
                cpu: "1"
                memory: 1Gi
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete vpa dev-commerce-service-vpa -n dev --ignore-not-found=true"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "null_resource" "vpa_dev_ai_service" {
  triggers = {
    name = "dev-ai-service-vpa"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: autoscaling.k8s.io/v1
      kind: VerticalPodAutoscaler
      metadata:
        name: dev-ai-service-vpa
        namespace: dev
      spec:
        targetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: dev-ai-service
        updatePolicy:
          updateMode: "Off"
        resourcePolicy:
          containerPolicies:
            - containerName: "*"
              minAllowed:
                cpu: 50m
                memory: 128Mi
              maxAllowed:
                cpu: "2"
                memory: 2Gi
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete vpa dev-ai-service-vpa -n dev --ignore-not-found=true"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "null_resource" "vpa_dev_frontend" {
  triggers = {
    name = "dev-frontend-vpa"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      apiVersion: autoscaling.k8s.io/v1
      kind: VerticalPodAutoscaler
      metadata:
        name: dev-frontend-vpa
        namespace: dev
      spec:
        targetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: dev-frontend
        updatePolicy:
          updateMode: "Off"
        resourcePolicy:
          containerPolicies:
            - containerName: "*"
              minAllowed:
                cpu: 50m
                memory: 64Mi
              maxAllowed:
                cpu: 500m
                memory: 512Mi
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete vpa dev-frontend-vpa -n dev --ignore-not-found=true"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
