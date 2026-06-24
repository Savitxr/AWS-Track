# FanVault Observability Platform

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  EKS Cluster (fanvault-dev-eks)                                 │
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐  │
│  │ Application │   │  monitoring │   │  amazon-cloudwatch  │  │
│  │ Pods (dev/) │   │  namespace  │   │  namespace          │  │
│  │             │   │             │   │                     │  │
│  │ user-svc    │──▶│ Prometheus  │   │ CloudWatch Agent    │  │
│  │ commerce-svc│   │ Grafana     │   │ (Container Insights)│  │
│  │ ai-svc      │──▶│ Alertmanager│   │                     │  │
│  │ frontend    │   │ Loki        │   └──────────┬──────────┘  │
│  └─────────────┘   │ Promtail    │              │             │
│        │           └──────┬──────┘              │             │
│        │ (logs)           │                     │             │
│        └──────────────────┘                     │             │
└─────────────────────────────────────────────────┼─────────────┘
                                                  │
                    ┌─────────────────────────────▼─────────────┐
                    │  AWS Services                              │
                    │                                            │
                    │  CloudWatch Logs  SNS (operational alerts) │
                    │  CloudWatch Metrics                        │
                    └────────────────────────────────────────────┘
```

## Components

### 1. EKS Control Plane Logging
All 5 log types enabled: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`.
Log group: `/aws/eks/fanvault-dev-eks/cluster` in CloudWatch.

### 2. CloudWatch Container Insights
- **Addon**: `amazon-cloudwatch-observability` (latest version, managed via `aws_eks_addon`)
- **IRSA**: `fanvault-cloudwatch-agent-irsa-role` with `CloudWatchAgentServerPolicy`
- **Service account**: `cloudwatch-agent` in `amazon-cloudwatch` namespace
- Delivers: CPU, memory, disk, network metrics per pod; structured logs via Fluent Bit

### 3. kube-prometheus-stack (Helm 65.8.1)
Deploys Prometheus + Alertmanager + Grafana + kube-state-metrics + node-exporter in the `monitoring` namespace.

**Prometheus**
- Storage: 20Gi gp2 PVC
- Retention: 15 days (dev), 30 days (prod)
- Service monitors: discovers all `ServiceMonitor` CRDs cluster-wide (`serviceMonitorSelectorNilUsesHelmValues: false`)

**Alertmanager**
- Storage: 5Gi gp2 PVC
- SNS integration via sigv4 receiver → `fanvault-dev-admin-operational-alerts`
- IRSA: `fanvault-alertmanager-irsa-role` with `sns:Publish` + KMS decrypt permissions
- Alert routing: all `critical` alerts → SNS → email/SMS via subscription

**Grafana**
- Storage: 10Gi gp2 PVC
- Access: ClusterIP only (no external exposure — port-forward for access)
- Credentials: admin password in SSM at `/fanvault/grafana/admin_password`
- Dashboards: auto-provisioned via ConfigMaps with label `grafana_dashboard: "1"`

### 4. Pre-configured Alert Rules
| Alert | Condition |
|-------|-----------|
| `NodeNotReady` | Node not ready for > 5 min |
| `NodeMemoryPressure` | Node memory pressure |
| `NodeDiskPressure` | Node disk pressure |
| `PodCrashLoopBackOff` | Pod restart rate > 5 per 15 min |
| `DeploymentUnavailable` | Available replicas < desired for > 5 min |
| `HighCPUUtilization` | Container CPU > 80% of limit for > 5 min |
| `HighMemoryUtilization` | Container memory > 80% of limit for > 5 min |
| `PersistentVolumeUsageHigh` | PV usage > 85% |

### 5. Loki + Promtail
- **Loki** (grafana/loki 6.20.0): SingleBinary mode, 20Gi gp2 PVC, auth disabled
- **Promtail** (grafana/promtail 6.16.6): DaemonSet on all nodes (tolerates any taint)
- Log labels: `cluster`, `namespace`, `pod`, `container`, `node`
- Retention: 7 days (dev), 30 days (prod)
- Grafana datasource: auto-configured at `http://loki.monitoring.svc.cluster.local:3100`

### 6. ServiceMonitors
All 4 application services have `ServiceMonitor` CRDs in their Helm charts.
- Enabled in dev via `serviceMonitor.enabled: true` in `environments/dev/values-*.yaml`
- Disabled by default in base `values.yaml` (off in prod until metrics endpoints are confirmed)
- Scrape path: `/metrics`, interval: `30s`

### 7. Auto-provisioned Grafana Dashboards
| Dashboard | Source | Description |
|-----------|--------|-------------|
| Cluster Overview | Community ID 7249 | Node resource usage |
| Node Exporter Full | Community ID 1860 | Detailed node metrics |
| Kubernetes Deployments | Community ID 8588 | Deployment status |
| FanVault Services | Custom | Per-service request rate, error rate, latency |
| AI Service | Custom | Bedrock invocation rates, latency |

## Access

### Grafana (port-forward)
```bash
# Get admin password
aws ssm get-parameter --name /fanvault/grafana/admin_password \
  --with-decryption --query Parameter.Value --output text

# Port-forward
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Open: http://localhost:3000 (admin / <password from SSM>)
```

### Prometheus (port-forward)
```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090
# Check targets: http://localhost:9090/targets
```

### Alertmanager (port-forward)
```bash
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
# Open: http://localhost:9093
```

### Loki (port-forward)
```bash
kubectl port-forward svc/loki 3100:3100 -n monitoring
curl http://localhost:3100/ready
```

## Troubleshooting

### Prometheus targets showing DOWN
1. Check ServiceMonitor label — must have `release: kube-prometheus-stack`
2. Check NetworkPolicy allows ingress from `monitoring` namespace
3. Verify `/metrics` endpoint responds on the target pod

### Alertmanager not sending SNS
1. Verify IRSA annotation on alertmanager pod: `eks.amazonaws.com/role-arn`
2. Check SNS topic subscription is confirmed
3. Test with `amtool alert add --alertmanager.url=http://localhost:9093`

### Loki missing logs
1. Check Promtail pods are running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail`
2. Verify Promtail can reach Loki: `kubectl logs -n monitoring -l app.kubernetes.io/name=promtail`
3. In Grafana → Explore → Loki → `{namespace="dev"}` should return results
