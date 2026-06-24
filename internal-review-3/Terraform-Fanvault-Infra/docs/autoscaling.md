# FanVault Autoscaling Platform

## Architecture

```
User Traffic ──▶ Pods need scaling ──▶ HPA scales Pods
                                              │
                               Not enough Nodes?
                                              │
                                    Karpenter provisions Nodes
                                    (spot preferred, on-demand fallback)
                                              │
                                    VPA recommends right-sizing
```

## Components

### 1. Metrics Server
- **Chart**: `kubernetes-sigs/metrics-server` v3.12.1 in `kube-system`
- **Purpose**: Provides CPU/memory metrics for HPA to function
- **Flag**: `--kubelet-insecure-tls` (required on EKS)
- **Verification**: `kubectl top nodes && kubectl top pods -n dev`

### 2. Horizontal Pod Autoscaler (HPA)
All 4 application services have HPAs configured.

| Service | Min | Max | CPU Target | Memory Target |
|---------|-----|-----|-----------|---------------|
| frontend | 2 | 3 | 70% | 75% |
| user-service | 2 | 4 | 70% | 75% |
| commerce-service | 2 | 4 | 70% | 75% |
| ai-service | 2 | 3 | 70% | 75% |

Dev overrides (in `environments/dev/values-*.yaml`):
- `replicaCount: 2` (ensures warm-standby in dev)
- `hpa.maxReplicas: 4` (user/commerce can scale wider in dev)

### 3. Karpenter (Node Autoscaling)
Karpenter provisions new EC2 nodes when pods are pending due to insufficient node capacity.

**EC2NodeClass** (`fanvault-default`):
- AMI family: AL2023
- EBS: 20Gi gp3, encrypted
- Subnet/SecurityGroup: selected by `kubernetes.io/cluster/<name>: owned` tags
- IAM role: existing `fanvault-dev-eks-node-role`

**NodePool** (`fanvault-default`):
| Parameter | Value |
|-----------|-------|
| Instance types | t3.medium, t3.large, t3a.medium, t3a.large |
| Capacity types | spot (preferred), on-demand |
| Architecture | amd64 |
| CPU limit | 20 cores (dev), 40 cores (prod) |
| Memory limit | 40Gi (dev), 80Gi (prod) |
| Consolidation | WhenEmptyOrUnderutilized, after 30s |

**Spot Interruption Handling**:
- SQS queue receives interruption warnings from EventBridge
- 3 EventBridge rules: spot interruption, rebalance recommendation, instance state-change
- Karpenter gracefully drains nodes before termination

**Cost optimization**:
- Spot instances are preferred (typically 60-70% cheaper)
- Consolidation removes underutilized nodes every 30 seconds
- Node limits prevent runaway cost

### 4. Vertical Pod Autoscaler (VPA) — Recommendation Mode
- **Chart**: fairwinds/vpa v4.4.6
- **Mode**: Recommender only — updater and admission controller are **disabled**
- `updateMode: Off` on all VPA objects → never mutates running pods

VPA objects exist for all 4 services. To view recommendations:
```bash
kubectl describe vpa -n dev dev-user-service-vpa
kubectl describe vpa -n dev dev-commerce-service-vpa
kubectl describe vpa -n dev dev-ai-service-vpa
kubectl describe vpa -n dev dev-frontend-vpa
```

Use recommendations to manually tune `resources.requests` in values files.

## Operations

### Check HPA Status
```bash
kubectl get hpa -n dev
# All targets should show actual%/target% (not <unknown>)
# <unknown> means metrics-server is not providing data
```

### Check Karpenter Nodes
```bash
# View Karpenter controller
kubectl get pods -n karpenter

# View provisioned NodePools and NodeClasses
kubectl get nodepools
kubectl get ec2nodeclasses

# View Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool
```

### Simulate Scale-out
```bash
# Create a deployment that needs more resources
kubectl run load-test --image=nginx --replicas=20 -n dev
# Karpenter should provision new nodes within ~30 seconds
kubectl get nodes -w
```

### Karpenter Troubleshooting
```bash
# Controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Why is a node not being provisioned?
kubectl describe nodeclaim <name>

# Why is a node not being consolidated?
kubectl get nodes -o wide
kubectl describe node <name>
```

### Force Consolidation
```bash
# Annotate a node to trigger immediate draining
kubectl annotate node <node-name> karpenter.sh/do-not-disrupt-

# Or via disruption budget
kubectl get nodedisruptionbudgets
```

## Cost Visibility

Karpenter tags all provisioned nodes with:
- `karpenter.sh/nodepool: fanvault-default`
- `Environment: dev`
- `Project: fanvault`

Filter AWS Cost Explorer by tag `karpenter.sh/nodepool` to see Karpenter-specific cost.

Spot vs on-demand breakdown visible in EC2 console → Instances → filter by "Instance lifecycle: spot".
