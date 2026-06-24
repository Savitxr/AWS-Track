# Fanvault-GitOps

GitOps repository for FanVault v3 — Helm charts, ArgoCD applications, and Kubernetes Gateway API configuration for deploying the FanVault platform to an EKS cluster.

- **GitOps Tool:** ArgoCD (App of Apps pattern)
- **Package Manager:** Helm 3
- **Ingress:** Kubernetes Gateway API (`kgateway`)
- **Environments:** `dev` (namespace `dev`) and `prod` (namespace `prod`)
- **Container Registry:** AWS ECR (account `773384830607`)

---

## Repository Structure

```
Fanvault-GitOps/
├── argocd/
│   ├── bootstrap-dev.yaml        # Root ArgoCD App — manages apps-dev/ folder
│   ├── bootstrap-prod.yaml       # Root ArgoCD App — manages apps-prod/ folder
│   ├── projects/
│   │   ├── fanvault-dev.yaml     # ArgoCD AppProject — dev environment
│   │   └── fanvault-prod.yaml    # ArgoCD AppProject — prod (sync window: weekdays 8–16h)
│   ├── apps-dev/                 # ArgoCD Application manifests (dev)
│   │   ├── user-service.yaml
│   │   ├── commerce-service.yaml
│   │   ├── frontend.yaml
│   │   ├── ai-service.yaml
│   │   └── gateway-api-crds.yaml # Gateway API CRDs (sync-wave -3, pinned v1.2.1)
│   └── apps-prod/                # ArgoCD Application manifests (prod)
│       ├── user-service.yaml
│       ├── commerce-service.yaml
│       ├── frontend.yaml
│       └── ai-service.yaml
├── charts/
│   ├── user-service/             # Helm chart — fanvault-user-service
│   ├── commerce-service/         # Helm chart — fanvault-commerce-service
│   ├── frontend/                 # Helm chart — fanvault-frontend
│   └── ai-service/               # Helm chart — fanvault-ai-service
├── environments/
│   ├── dev/                      # Dev environment value overrides
│   │   ├── values-user.yaml
│   │   ├── values-commerce.yaml
│   │   ├── values-frontend.yaml
│   │   └── values-ai.yaml
│   └── prod/                     # Prod environment value overrides
│       ├── values-user.yaml
│       ├── values-commerce.yaml
│       ├── values-frontend.yaml
│       └── values-ai.yaml
└── gateway/
    ├── gateway-config.yaml       # GatewayParameters + Gateway (NLB, internet-facing)
    ├── httproutes-dev.yaml       # HTTPRoutes for dev namespace
    └── httproutes-prod.yaml      # HTTPRoutes for prod namespace
```

---

## Kubernetes Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  EKS Cluster                                                                    │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  kgateway-system namespace                                               │   │
│  │                                                                          │   │
│  │  ┌──────────────────────────────────────────────────────────────────┐    │   │
│  │  │  Gateway: fanvault-gateway                                       │    │   │
│  │  │  GatewayClass: kgateway                                          │    │   │
│  │  │  Service type: LoadBalancer (AWS NLB, internet-facing, IP mode)  │    │   │
│  │  │  Listener: HTTP :80 — allowedRoutes: namespaces: All            │    │   │
│  │  └──────────────────────────┬───────────────────────────────────────┘    │   │
│  └─────────────────────────────┼────────────────────────────────────────────┘   │
│                                │  NLB routes HTTP :80 traffic                   │
│                                │                                                │
│         ┌──────────────────────┼──────────────────────────────┐                 │
│         │                      │                              │                 │
│         ▼ HTTPRoute: dev        │                              ▼ HTTPRoute: prod │
│         namespace: dev         │                              namespace: prod   │
│                                │                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  dev namespace                                                           │   │
│  │                                                                          │   │
│  │  Hostnames: dev.fanvault.garden / api-dev.fanvault.garden               │   │
│  │                                                                          │   │
│  │  HTTPRoute rules:                                                        │   │
│  │  /api/auth/*    → dev-user-service:3001                                  │   │
│  │  /api/users/*   → dev-user-service:3001                                  │   │
│  │  /api/products/ → dev-commerce-service:3002                              │   │
│  │  /api/orders/   → dev-commerce-service:3002                              │   │
│  │  /api/admin/    → dev-commerce-service:3002                              │   │
│  │  /api/ai/       → dev-ai-service:8000                                    │   │
│  │  /              → dev-frontend:80                                        │   │
│  │                                                                          │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐                       │   │
│  │  │ user-service        │  │ commerce-service     │                       │   │
│  │  │ (dev-user-service)  │  │ (dev-commerce-svc)   │                       │   │
│  │  │                     │  │                      │                       │   │
│  │  │ Pods: 2             │  │ Pods: 2              │                       │   │
│  │  │ HPA: 2-4            │  │ HPA: 2-4             │                       │   │
│  │  │ Port: 3001          │  │ Port: 3002            │                       │   │
│  │  │ Image: ECR v0.4.3   │  │ Image: ECR v0.4.3    │                       │   │
│  │  │ IRSA: user-role     │  │ IRSA: commerce-role  │                       │   │
│  │  │ DynamoDB: dev-* tbl │  │ DynamoDB: dev-* tbl  │                       │   │
│  │  │ Cognito: prod pool  │  │ EventBridge: dev-bus │                       │   │
│  │  └─────────────────────┘  └─────────────────────┘                       │   │
│  │                                                                          │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐                       │   │
│  │  │ frontend            │  │ ai-service           │                       │   │
│  │  │ (dev-frontend)      │  │ (dev-ai-service)     │                       │   │
│  │  │                     │  │                      │                       │   │
│  │  │ Pods: 2             │  │ Pods: 2              │                       │   │
│  │  │ HPA: 2-4            │  │ HPA: 2-4             │                       │   │
│  │  │ Port: 80 (Nginx)    │  │ Port: 8000 (FastAPI) │                       │   │
│  │  │ Image: ECR v0.4.4   │  │ Image: ECR v0.7.0    │                       │   │
│  │  │ ConfigMap: svc hosts│  │ Bedrock cross-acct   │                       │   │
│  │  │ No IRSA needed      │  │ IRSA: ai-role        │                       │   │
│  │  └─────────────────────┘  └─────────────────────┘                       │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  prod namespace                                                          │   │
│  │  [same structure; hostnames: fanvault.garden / api.fanvault.garden]      │   │
│  │  HPA: 2-5 replicas; sync window: weekdays 08:00-16:00 UTC               │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  argocd namespace                                                        │   │
│  │                                                                          │   │
│  │  fanvault-bootstrap-dev  → watches argocd/apps-dev/ (auto-sync + heal)   │   │
│  │  fanvault-bootstrap-prod → watches argocd/apps-prod/ (auto-sync + heal)  │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## ArgoCD App of Apps Pattern

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ArgoCD — App of Apps                                                       │
└─────────────────────────────────────────────────────────────────────────────┘

  Bootstrap (applied manually once):
  kubectl apply -f argocd/bootstrap-dev.yaml
  kubectl apply -f argocd/bootstrap-prod.yaml

  Bootstrap App: fanvault-bootstrap-dev
    source.path: argocd/apps-dev/
    syncPolicy: automated (prune + selfHeal)
    │
    │  Manages these Application CRs:
    ├── gateway-api-crds   (sync-wave: -3, no prune — installs CRDs before everything)
    ├── dev-user-service
    ├── dev-commerce-service
    ├── dev-frontend
    └── dev-ai-service

  Each Application CR:
    source.path: charts/<service>/
    source.helm.valueFiles:
      - values.yaml                         ← chart defaults
      - ../../environments/dev/values-*.yaml ← env overrides (image tag, replicas, config)
    destination.namespace: dev
    syncPolicy: automated (prune + selfHeal)
    syncOptions: CreateNamespace=true + ServerSideApply=true

  Prod is identical but:
    Bootstrap path: argocd/apps-prod/
    Namespace: prod
    Project: fanvault-prod
    Sync window: allow weekdays 08:00–16:00 UTC (8h), manual sync permitted
```

---

## Service Catalog

| Service | Port | Image (Dev) | Image (Prod) | HPA Dev | HPA Prod |
|---|---|---|---|---|---|
| `user-service` | 3001 | `fanvault-dev-user-service:v0.4.3` | `fanvault-prod-user-service:v0.0.1` | 2-4 | 2-5 |
| `commerce-service` | 3002 | `fanvault-dev-commerce-service:v0.4.3` | `fanvault-prod-commerce-service:v0.0.1` | 2-4 | 2-5 |
| `frontend` | 80 | `fanvault-dev-frontend:v0.4.4` | `fanvault-prod-frontend:v0.0.1` | 2-4 | 2-5 |
| `ai-service` | 8000 | `fanvault-dev-ai-service:v0.7.0` | `fanvault-prod-ai-service:v0.0.1` | 2-4 | 2-5 |

All images from ECR: `773384830607.dkr.ecr.us-east-1.amazonaws.com`

---

## Helm Charts

Each chart (`charts/<service>/`) contains:

```
Chart.yaml
values.yaml              ← base defaults
templates/
  deployment.yaml        ← Deployment with security contexts, liveness/readiness probes
  service.yaml           ← ClusterIP Service
  configmap.yaml         ← ConfigMap from .Values.config (iterates key-value pairs)
  secret.yaml            ← Opaque Secret (conditional on .Values.secrets)
  hpa.yaml               ← HorizontalPodAutoscaler (autoscaling/v2) — CPU 70% + Mem 75%
  networkpolicy.yaml     ← NetworkPolicy — restrict ingress to gateway + prometheus
  pdb.yaml               ← PodDisruptionBudget (minAvailable: 1)
  serviceaccount.yaml    ← ServiceAccount with IRSA annotation
  role.yaml              ← RBAC Role (configmap read) — user-service + ai-service only
  rolebinding.yaml       ← RoleBinding — user-service + ai-service only
  servicemonitor.yaml    ← Prometheus ServiceMonitor (enabled per env values)
```

### Security Posture

All pods run with:
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001      # (101 for frontend/nginx)

containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

Frontend additionally mounts `emptyDir` volumes for `/tmp` and `/var/cache/nginx` to allow Nginx to run as non-root without write access to the rest of the filesystem.

### Network Policies

```
user-service & commerce-service:
  Ingress: from kgateway pods (component: gateway) OR frontend pods OR prometheus
  Egress:  unrestricted (DynamoDB VPC endpoint, SNS, SSM, Secrets Manager)

frontend:
  Ingress: from kgateway pods (component: gateway) OR prometheus
  Egress:  unrestricted (proxies to user-service and commerce-service in-cluster)

ai-service:
  Ingress: from commerce-service pods OR prometheus ONLY
           (never directly reachable from gateway or browser)
  Egress:  unrestricted (S3, Bedrock, STS, CloudWatch)
```

---

## IRSA Configuration

Each service's ServiceAccount is annotated with an IAM role ARN for pod-level AWS access (EKS IRSA):

| Service | IRSA Role | Permissions |
|---|---|---|
| `user-service` | `arn:aws:iam::773384830607:role/fanvault-user-irsa-role` | DynamoDB (`fanvault-*-profiles`), Secrets Manager |
| `commerce-service` | `arn:aws:iam::773384830607:role/fanvault-commerce-irsa-role` | DynamoDB, S3, EventBridge, SNS, SSM |
| `ai-service` | `arn:aws:iam::773384830607:role/fanvault-ai-irsa-role` | S3 (`fanvault-*-product-images-*`), STS (cross-account Bedrock) |
| `frontend` | None | No AWS access needed |

**Dev AI cross-account Bedrock:** `fanvault-ai-irsa-role` (account `773384830607`) assumes `fanvault-bedrock-cross-account-role` (account `899071933396`) to invoke `amazon.nova-pro-v1:0`.

---

## Gateway API Routing

```
Kubernetes Gateway API (kgateway)
─────────────────────────────────────────────────────────────────────────────
GatewayClass: kgateway
Gateway: fanvault-gateway (kgateway-system namespace)
  Service:      LoadBalancer (AWS NLB)
  Scheme:       internet-facing
  Target type:  ip (pod-level routing)
  Listener:     HTTP :80, allowedRoutes: All namespaces

HTTPRoute: fanvault-dev (dev namespace)
  parentRefs: fanvault-gateway
  Hostnames:
    - dev.fanvault.garden
    - api-dev.fanvault.garden

  Path rules (evaluated top to bottom):
  PathPrefix /api/auth      -> dev-user-service:3001
  PathPrefix /api/users     -> dev-user-service:3001
  PathPrefix /api/products  -> dev-commerce-service:3002
  PathPrefix /api/orders    -> dev-commerce-service:3002
  PathPrefix /api/admin     -> dev-commerce-service:3002
  PathPrefix /api/ai        -> dev-ai-service:8000
  PathPrefix /              -> dev-frontend:80

HTTPRoute: fanvault-prod (prod namespace)
  parentRefs: fanvault-gateway
  Hostnames:
    - fanvault.garden
    - api.fanvault.garden
  [same path rules pointing to prod-* services]
```

---

## ArgoCD Projects

### fanvault-dev

- Source repos: GitOps repo, kgateway charts, `kubernetes-sigs/gateway-api` (for CRDs)
- Destinations: `dev`, `kgateway-system`, `argocd`, `*` namespaces
- Cluster resources: Namespace, GatewayClass, Gateway, CRD
- No sync window restrictions

### fanvault-prod

- Source repos: GitOps repo only
- Destinations: `prod` namespace only
- Cluster resources: Namespace only (tighter RBAC)
- **Sync window:** Allow weekdays `08:00–16:00 UTC` (`"0 8 * * 1-5"`, duration `8h`)
  - Prevents accidental off-hours deploys to production
  - Manual sync permitted within the window

---

## Observability

ServiceMonitor resources (enabled in dev via `serviceMonitor.enabled: true` in `environments/dev/values-*.yaml`) configure Prometheus scraping on `/metrics` every 30s.

Health endpoints polled by Kubernetes liveness/readiness probes:

| Service | Path | Liveness delay | Readiness delay |
|---|---|---|---|
| user-service | `/health` | 10s (period 15s) | 5s (period 10s) |
| commerce-service | `/health` | 10s (period 15s) | 5s (period 10s) |
| frontend | `/health` | 10s (period 15s) | 5s (period 10s) |
| ai-service | `/health` | 15s (period 20s) | 10s (period 10s) |

The AI service has a longer liveness delay to allow the Bedrock STS client to initialize.

---

## Deploying

### Prerequisites

```bash
# EKS cluster with:
# - OIDC provider configured (IRSA)
# - kgateway installed in kgateway-system namespace
# - ArgoCD installed in argocd namespace
# - ECR repositories created and images pushed
```

### Bootstrap (first time)

```bash
# 1. Apply ArgoCD projects
kubectl apply -f argocd/projects/

# 2. Apply bootstrap apps (triggers auto-sync of all child apps)
kubectl apply -f argocd/bootstrap-dev.yaml
kubectl apply -f argocd/bootstrap-prod.yaml

# 3. Apply Gateway API configuration
kubectl apply -f gateway/gateway-config.yaml
kubectl apply -f gateway/httproutes-dev.yaml
kubectl apply -f gateway/httproutes-prod.yaml
```

### Deploying a New Image Version

1. Build and push image to ECR with new tag
2. Update `image.tag` in `environments/<env>/values-<service>.yaml`
3. `git commit` and `git push` to `main`
4. ArgoCD auto-syncs (dev) or waits for sync window (prod)

### Checking Sync Status

```bash
# ArgoCD CLI
argocd app list
argocd app sync dev-user-service
argocd app get dev-commerce-service

# kubectl
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get httproute -n dev
```

---

## Environment Configuration Reference

### Dev DynamoDB Tables

```
fanvault-dev-profiles, fanvault-dev-products, fanvault-dev-orders,
fanvault-dev-audit-logs, fanvault-dev-metadata
```

### Dev ECR Images

```
773384830607.dkr.ecr.us-east-1.amazonaws.com/fanvault-dev-user-service:v0.4.3
773384830607.dkr.ecr.us-east-1.amazonaws.com/fanvault-dev-commerce-service:v0.4.3
773384830607.dkr.ecr.us-east-1.amazonaws.com/fanvault-dev-frontend:v0.4.4
773384830607.dkr.ecr.us-east-1.amazonaws.com/fanvault-dev-ai-service:v0.7.0
```

### Cognito (shared dev + prod)

```
User Pool ID: us-east-1_O7cQQXD1P
Client ID:    3fioa78u18rkf7c3kiqb3sud55
```

### Dev EventBridge + SNS

```
EventBridge bus: fanvault-dev-event-bus
SNS order-failure: arn:aws:sns:us-east-1:773384830607:fanvault-dev-order-failure-alerts
```

### Bedrock

```
Model:        amazon.nova-pro-v1:0
Cross-acct:   arn:aws:iam::899071933396:role/fanvault-bedrock-cross-account-role
S3 bucket:    fanvault-dev-product-images-773384830607
```

---

## GitOps + Kubernetes Deployment Flow

```
Developer
  │
  │  git push (bump image tag in environments/dev/values-user.yaml)
  ▼
GitHub (Fanvault-GitOps repo)
  │
  │  ArgoCD polls / webhook
  ▼
ArgoCD (argocd namespace)
  │
  │  Detects drift: desired state (Git) != current state (cluster)
  │  selfHeal = true -> auto-applies diff
  ▼
Kubernetes API Server
  │
  ├── Deployment rollout (rolling update)
  │     Old pods: Terminating after new pods pass readiness probe
  │     New pods: Pull IfNotPresent (prod) / Always (dev), run as non-root
  │
  ├── HPA watches CPU (70%) + Memory (75%) -> auto-scales pods
  │     Dev:  2 - 4 replicas
  │     Prod: 2 - 5 replicas
  │
  ├── PDB enforces minAvailable=1 (no full outage during drain / rollout)
  │
  ├── NetworkPolicy restricts inter-pod traffic (least privilege)
  │
  └── ServiceMonitor -> Prometheus -> Grafana (dev monitoring stack)

Traffic path:
  Browser -> NLB -> kgateway (fanvault-gateway) -> HTTPRoute -> Service -> Pod
```
