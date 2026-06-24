## kube-prometheus-stack Helm values
## Template variables: project_name, environment, aws_region, sns_topic_arn, prometheus_retention, prometheus_storage, grafana_storage, alertmanager_storage, grafana_password, alertmanager_role_arn

fullnameOverride: "kube-prometheus-stack"

## ── Prometheus Operator ────────────────────────────────────────────────────────
# Admission webhooks require a pre-install Job pod which can't schedule on
# t3.medium nodes at max pod density (17 pods/node ENI limit). Disabled for dev.
prometheusOperator:
  admissionWebhooks:
    enabled: false
    patch:
      enabled: false
  tls:
    enabled: false

## ── Prometheus ────────────────────────────────────────────────────────────────
prometheus:
  prometheusSpec:
    retention: ${prometheus_retention}d
    retentionSize: "18GB"

    # Discover all ServiceMonitors and PodMonitors regardless of helm labels
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: ${prometheus_storage}

    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: "1000m"
        memory: 2Gi

    # Additional scrape configs for kgateway/Envoy metrics
    additionalScrapeConfigs:
      - job_name: kgateway-envoy
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [kgateway-system]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: keep
            regex: kgateway

## ── Alertmanager ──────────────────────────────────────────────────────────────
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: ${alertmanager_storage}

    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 256Mi

    serviceAccountAnnotations:
      eks.amazonaws.com/role-arn: "${alertmanager_role_arn}"

  config:
    global:
      resolve_timeout: 5m
    inhibit_rules:
      - source_matchers:
          - severity="critical"
        target_matchers:
          - severity="warning"
        equal: [alertname, namespace]
    route:
      group_by: [alertname, namespace, severity]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      receiver: "sns-critical"
      routes:
        - matchers:
            - severity="critical"
          receiver: "sns-critical"
        - matchers:
            - severity="warning"
          receiver: "sns-critical"
    receivers:
      - name: "sns-critical"
        sns_configs:
          - api_url: "https://sns.${aws_region}.amazonaws.com"
            topic_arn: "${sns_topic_arn}"
            sigv4:
              region: "${aws_region}"
            attributes:
              severity: '{{ .CommonLabels.severity }}'

## ── Grafana ───────────────────────────────────────────────────────────────────
grafana:
  adminPassword: "${grafana_password}"

  persistence:
    enabled: true
    storageClassName: gp2
    size: ${grafana_storage}

  service:
    type: ClusterIP

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Auto-discover ConfigMap-based dashboards in monitoring namespace
  sidecar:
    dashboards:
      enabled: true
      searchNamespace: monitoring
      label: grafana_dashboard
      labelValue: "1"
    datasources:
      enabled: true

  # Grafana.ini overrides
  grafana.ini:
    server:
      root_url: "%(protocol)s://%(domain)s/"
    analytics:
      reporting_enabled: false
    security:
      allow_embedding: true
    unified_alerting:
      enabled: true

## ── Prometheus Rules (additional) ────────────────────────────────────────────
additionalPrometheusRulesMap:
  fanvault-cluster-rules:
    groups:
      - name: cluster.health
        interval: 60s
        rules:
          - alert: NodeNotReady
            expr: kube_node_status_condition{condition="Ready",status="true"} == 0
            for: 5m
            labels:
              severity: critical
              project: ${project_name}
            annotations:
              summary: "Node {{ $labels.node }} is not ready"
              description: "Node {{ $labels.node }} has been not ready for more than 5 minutes."
          - alert: NodeMemoryPressure
            expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
            for: 5m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Node {{ $labels.node }} has memory pressure"
          - alert: NodeDiskPressure
            expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
            for: 5m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Node {{ $labels.node }} has disk pressure"
      - name: workload.health
        interval: 60s
        rules:
          - alert: PodCrashLoopBackOff
            expr: rate(kube_pod_container_status_restarts_total[15m]) * 900 > 5
            for: 5m
            labels:
              severity: critical
              project: ${project_name}
            annotations:
              summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
              description: "Container {{ $labels.container }} restarted more than 5 times in 15 minutes."
          - alert: DeploymentUnavailable
            expr: kube_deployment_status_replicas_unavailable > 0
            for: 10m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has unavailable replicas"
          - alert: FailedPods
            expr: kube_pod_status_phase{phase="Failed"} > 0
            for: 5m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is in Failed state"
      - name: resource.utilization
        interval: 60s
        rules:
          - alert: HighCPUUtilization
            expr: |
              (
                sum(rate(container_cpu_usage_seconds_total{container!="",container!="POD"}[5m])) by (pod, namespace)
                /
                sum(kube_pod_container_resource_limits{resource="cpu",container!=""}) by (pod, namespace)
              ) > 0.80
            for: 10m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU > 80%"
          - alert: HighMemoryUtilization
            expr: |
              (
                sum(container_memory_working_set_bytes{container!="",container!="POD"}) by (pod, namespace)
                /
                sum(kube_pod_container_resource_limits{resource="memory",container!=""}) by (pod, namespace)
              ) > 0.80
            for: 10m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} memory > 80%"
          - alert: PersistentVolumeUsageHigh
            expr: |
              (
                kubelet_volume_stats_used_bytes
                / kubelet_volume_stats_capacity_bytes
              ) > 0.80
            for: 5m
            labels:
              severity: warning
              project: ${project_name}
            annotations:
              summary: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} usage > 80%"

## ── kube-state-metrics ───────────────────────────────────────────────────────
kube-state-metrics:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

## ── node-exporter ────────────────────────────────────────────────────────────
prometheus-node-exporter:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

## ── Prometheus Operator ──────────────────────────────────────────────────────
prometheusOperator:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
