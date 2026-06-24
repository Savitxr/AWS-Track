# Terraform-Fanvault-Infra

Infrastructure-as-Code for the FanVault platform, provisioned with Terraform. The **dev branch** deploys a fully containerised EKS-based architecture replacing the legacy EC2/ASG deployment model.

- **Cloud:** AWS (us-east-1)
- **Container Orchestration:** Amazon EKS 1.35
- **Autoscaling:** Karpenter (node) + HPA (pod)
- **GitOps:** ArgoCD deployed via Terraform Helm release
- **Environments:** `environments/dev/` (active) · `environments/prod/` (planned)

---

## Repository Layout

```
Terraform-Fanvault-Infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf          # Root module for the dev environment (EKS architecture)
│   │   ├── variables.tf     # dev-specific input variables
│   │   └── backend.tf       # S3 remote state config
│   └── prod/                # Prod environment (mirrors dev)
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT Gateway, route tables
│   ├── eks/                 # EKS cluster, node group, OIDC provider
│   ├── karpenter/           # Karpenter controller, IRSA, NodePool, EC2NodeClass
│   ├── eks_addons/          # metrics-server, CloudWatch observability, EBS CSI, VPA
│   ├── cognito/             # User Pool, App Client, domain, groups
│   ├── ecr/                 # ECR repositories with lifecycle policy
│   ├── dynamodb/            # 5 DynamoDB tables (profiles, products, orders, audit-logs, metadata)
│   ├── s3/                  # Product images S3 bucket
│   ├── cloudfront/          # CloudFront distribution (OAC → S3)
│   ├── secrets_manager/     # App secrets (Secrets Manager)
│   ├── configuration/       # SSM Parameter Store entries
│   ├── iam/                 # IRSA roles for all services
│   ├── argocd/              # ArgoCD Helm release
│   ├── observability/       # kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
│   ├── notifications/       # SNS topics, SQS queues, KMS key
│   ├── event_processing/    # EventBridge bus + Lambda consumers
│   ├── cloudwatch/          # CloudWatch log groups
│   ├── eks_monitoring/      # CloudWatch alarms for DDB, Lambda, SNS
│   ├── networking/          # (legacy root)
│   ├── security_groups/     # (legacy root)
│   ├── backend/             # (legacy root)
│   ├── storage/             # (legacy root)
│   ├── monitoring/          # (legacy root)
│   └── governance/          # Config rules, GuardDuty
└── main.tf                  # Legacy root (EC2/ASG modules — not used for dev env)
```

> **Note:** The root-level `main.tf` contains the original EC2/ASG-based modules. All active
> provisioning for the dev (and prod) environments is driven from `environments/dev/main.tf`.

---

## AWS Cloud Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  AWS Account 773384830607 — us-east-1                                               │
│                                                                                     │
│  ┌──────────────────────── VPC 10.0.0.0/16 ──────────────────────────────────┐    │
│  │                                                                             │    │
│  │  ┌─ Public Subnets ──────────────────────────────────────────────────┐    │    │
│  │  │  10.0.1.0/24 (us-east-1a)   10.0.2.0/24 (us-east-1b)           │    │    │
│  │  │  tag: kubernetes.io/role/elb = 1 (NLB placement)                 │    │    │
│  │  │  ┌──────────────┐                                                 │    │    │
│  │  │  │ NAT Gateway  │ ← Elastic IP                                   │    │    │
│  │  │  └──────────────┘                                                 │    │    │
│  │  └───────────────────────────────────────────────────────────────────┘    │    │
│  │         │ (outbound internet for private subnets)                          │    │
│  │  ┌─ Private Subnets ─────────────────────────────────────────────────┐    │    │
│  │  │  10.0.11.0/24 (us-east-1a)  10.0.12.0/24 (us-east-1b)           │    │    │
│  │  │  tag: kubernetes.io/role/internal-elb = 1                         │    │    │
│  │  │                                                                     │    │    │
│  │  │  ┌─────────────────── EKS Cluster ──────────────────────────────┐ │    │    │
│  │  │  │  Control Plane (managed)                                       │ │    │    │
│  │  │  │  Auth: API_AND_CONFIG_MAP   Logs: api, audit, authenticator,  │ │    │    │
│  │  │  │        controllerManager, scheduler                            │ │    │    │
│  │  │  │                                                                 │ │    │    │
│  │  │  │  Node Group (t2.large, desired 3, max 4, min 3)               │ │    │    │
│  │  │  │  ├── kube-system: CoreDNS, kube-proxy, metrics-server, VPA   │ │    │    │
│  │  │  │  ├── karpenter: Karpenter controller                           │ │    │    │
│  │  │  │  ├── argocd:    ArgoCD (Helm v7.1.3)                          │ │    │    │
│  │  │  │  ├── monitoring: Prometheus + Grafana + Alertmanager           │ │    │    │
│  │  │  │  ├── amazon-cloudwatch: CW Agent + Fluent Bit                  │ │    │    │
│  │  │  │  ├── dev:   user-service, commerce-service, ai-service, frontend │ │   │    │
│  │  │  │  └── prod:  (same services, prod values)                       │ │    │    │
│  │  │  │                                                                 │ │    │    │
│  │  │  │  Karpenter Burst Nodes (spot + on-demand, amd64)               │ │    │    │
│  │  │  │  Max: 20 vCPU / 40Gi memory — consolidates in 30s             │ │    │    │
│  │  │  └─────────────────────────────────────────────────────────────────┘ │    │    │
│  │  └───────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                 │    │
│  │  ┌─ Database Subnets ────────────────────────────────────────────────┐        │    │
│  │  │  10.0.21.0/24 (us-east-1a)  10.0.22.0/24 (us-east-1b)           │        │    │
│  │  │  (isolated — no route to IGW or NAT)                               │        │    │
│  │  └───────────────────────────────────────────────────────────────────┘        │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
│  ┌── Managed Services ──────────────────────────────────────────────────────────────┐  │
│  │                                                                                   │  │
│  │  Cognito User Pool (us-east-1_O7cQQXD1P)                                        │  │
│  │   ├── App Client: USER_PASSWORD_AUTH, REFRESH_TOKEN, USER_SRP_AUTH              │  │
│  │   ├── OAuth: code + implicit flows, scopes: openid, email, profile              │  │
│  │   ├── Groups: admins (precedence 1), customers (precedence 2)                   │  │
│  │   └── Domain: fanvault-dev-auth-{last4ofAccountId}                              │  │
│  │                                                                                   │  │
│  │  DynamoDB (PAY_PER_REQUEST, PITR, KMS)                                          │  │
│  │   ├── fanvault-dev-profiles         PK: userId                                  │  │
│  │   ├── fanvault-dev-products         PK: productId  GSI: sku-index,              │  │
│  │   │                                                GSI: category-franchise-index │  │
│  │   ├── fanvault-dev-orders           PK: orderId    GSI: userId-createdAt,       │  │
│  │   │                                                GSI: orderNumber-index,       │  │
│  │   │                                                GSI: status-createdAt-index   │  │
│  │   ├── fanvault-dev-audit-logs       PK: logId  TTL: ttlExpiry                   │  │
│  │   │                                 GSI: entityType-timestamp, adminId-timestamp │  │
│  │   └── fanvault-dev-metadata         PK: metaType  SK: metaId                    │  │
│  │                                                                                   │  │
│  │  S3: fanvault-dev-product-images-{accountId}                                    │  │
│  │   └── Versioning, AES256, CORS (presigned PUT), public-access-block             │  │
│  │                                                                                   │  │
│  │  CloudFront → S3 (OAC)                                                          │  │
│  │                                                                                   │  │
│  │  Secrets Manager: fanvault-dev-app-secrets  (recovery 7d)                       │  │
│  │                                                                                   │  │
│  │  SSM Parameter Store: /fanvault/dev/*  (Cognito IDs, SNS ARNs, S3/CF endpoints) │  │
│  │                                                                                   │  │
│  │  ECR (4 repos, KMS, scan-on-push, keep last 50 images):                         │  │
│  │   fanvault-dev-frontend · fanvault-dev-user-service                             │  │
│  │   fanvault-dev-commerce-service · fanvault-dev-ai-service                       │  │
│  │                                                                                   │  │
│  │  EventBridge: fanvault-dev-event-bus                                             │  │
│  │  SNS (KMS): low-inventory-alerts, order-failure-alerts,                         │  │
│  │             product-upload-failures, admin-operational-alerts                    │  │
│  │  SQS: 4 subscriber queues + 1 DLQ (14-day retention, KMS)                       │  │
│  │                                                                                   │  │
│  │  CloudWatch: log groups (14-day retention), Container Insights, Fluent Bit       │  │
│  │  GitHub Actions: EKS Access Entry (AmazonEKSClusterAdminPolicy)                  │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌── Cross-Account ──────────────────────────────────────────────────────────────────┐ │
│  │  Account 899071933396                                                              │ │
│  │   └── fanvault-bedrock-cross-account-role                                         │ │
│  │         ← assumed by ai-service IRSA role via STS AssumeRole                      │ │
│  │         → Bedrock InvokeModel (amazon.nova-pro-v1:0)                              │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Module Reference

### `vpc`

3-tier VPC across 2 AZs with a single shared NAT Gateway.

| Resource | Value |
|---|---|
| CIDR | `10.0.0.0/16` |
| Public subnets | `10.0.1.0/24`, `10.0.2.0/24` (tagged for NLB placement) |
| Private subnets | `10.0.11.0/24`, `10.0.12.0/24` (tagged for internal NLB) |
| Database subnets | `10.0.21.0/24`, `10.0.22.0/24` (isolated, no outbound route) |
| NAT Gateway | 1 Elastic IP, placed in public-a subnet |
| Internet Gateway | Attached to VPC, routes public subnets |

---

### `eks`

Managed EKS cluster with OIDC provider for IRSA.

| Resource | Value |
|---|---|
| Cluster name | `fanvault-dev-eks` |
| Version | `1.35` |
| Auth mode | `API_AND_CONFIG_MAP` |
| Endpoint | Public + Private |
| Control plane logs | api, audit, authenticator, controllerManager, scheduler |
| Node group type | `t2.large` |
| Desired / Min / Max nodes | 3 / 3 / 4 |
| Node role policies | AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly |
| OIDC provider | Created from cluster issuer URL for IRSA |

---

### `karpenter`

Karpenter node autoscaler with interruption handling.

```
Karpenter Controller
  IRSA role: fanvault-dev-karpenter-controller
  Helm chart: oci://public.ecr.aws/karpenter/karpenter

EC2NodeClass: fanvault-default
  AMI family: AL2023 (@latest)
  Subnets: private subnets (tagged kubernetes.io/cluster/fanvault-dev-eks = owned)
  Security groups: same tag selector
  Instance profile: EKS node role

NodePool: fanvault-default
  Architecture: amd64
  Capacity types: spot + on-demand
  Instance types: variable (configured via var.instance_types)
  Zones: us-east-1a, us-east-1b
  Limits: 20 CPU / 40Gi memory
  Disruption: WhenEmptyOrUnderutilized, consolidateAfter 30s

Interruption Queue (SQS):
  Receives: EC2 Spot Interruption, Instance Rebalance, Instance State-change
  Message retention: 5 minutes
  Karpenter drains nodes gracefully before termination
```

---

### `eks_addons`

| Addon | Deployment | Purpose |
|---|---|---|
| `metrics-server` | Helm (kube-system) | HPA + VPA CPU/memory metrics |
| `amazon-cloudwatch-observability` | EKS Addon | Container Insights + Fluent Bit log collection |
| `aws-ebs-csi-driver` | EKS Addon | PVC provisioning for Prometheus/Grafana persistent volumes |
| `vertical-pod-autoscaler` | Helm (Fairwinds, kube-system) | VPA recommender-only (no mutating webhooks) |

VPA objects (recommendation-only, `updateMode: Off`) are deployed for all 4 application services: user-service, commerce-service, ai-service, frontend.

---

### `cognito`

| Resource | Value |
|---|---|
| User Pool | `fanvault-dev-user-pool` |
| Username attribute | `email` |
| Auto-verified attributes | `email` |
| Password policy | Min 8 chars, upper + lower + numbers + symbols |
| Required schema attributes | `email`, `given_name`, `family_name` |
| App Client auth flows | `ALLOW_USER_PASSWORD_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`, `ALLOW_USER_SRP_AUTH` |
| OAuth flows | `code`, `implicit` |
| OAuth scopes | `openid`, `email`, `profile` |
| Callback URL (dev) | `http://localhost:3000` |
| Hosted domain | `fanvault-dev-auth-{last4ofAccountId}.auth.us-east-1.amazoncognito.com` |
| Groups | `admins` (precedence 1), `customers` (precedence 2) |

---

### `ecr`

4 repositories, one per service. Created as `fanvault-dev-{service}`.

| Repository | Image |
|---|---|
| `fanvault-dev-frontend` | React/Nginx SPA |
| `fanvault-dev-user-service` | Node.js identity service |
| `fanvault-dev-commerce-service` | Node.js commerce service |
| `fanvault-dev-ai-service` | Python FastAPI AI service |

All repositories: KMS encryption, scan-on-push enabled, lifecycle policy keeps last 50 images.

---

### `dynamodb`

5 tables, all with `PAY_PER_REQUEST` billing, PITR, and KMS server-side encryption.

| Table | PK | SK | GSIs | Notes |
|---|---|---|---|---|
| `fanvault-dev-profiles` | `userId` | — | — | Cognito sub as PK; no separate users table |
| `fanvault-dev-products` | `productId` | — | `sku-index`, `category-franchise-index` | |
| `fanvault-dev-orders` | `orderId` | — | `userId-createdAt-index`, `orderNumber-index`, `status-createdAt-index` | |
| `fanvault-dev-audit-logs` | `logId` | — | `entityType-timestamp-index`, `adminId-timestamp-index` | TTL: `ttlExpiry` |
| `fanvault-dev-metadata` | `metaType` | `metaId` | — | Categories + franchises |

---

### `s3`

Product images bucket `fanvault-dev-product-images-{accountId}`:
- Versioning enabled
- AES256 server-side encryption
- All public access blocked
- CORS configured for direct browser presigned-PUT uploads (PUT, POST, GET, HEAD — `ETag` exposed)

---

### `cloudfront`

CloudFront distribution in front of the S3 bucket using Origin Access Control (OAC). Browsers receive CDN-cached product images; no public S3 access.

---

### `secrets_manager`

A single secret `fanvault-dev-app-secrets` stores application credentials as a JSON object. Recovery window: 7 days. Services access it via IRSA-scoped `secretsmanager:GetSecretValue` policies.

---

### `configuration`

SSM Parameter Store parameters under `/fanvault/dev/*`:
- Cognito User Pool ID and Client ID
- SNS topic ARNs (for commerce-service)
- S3 bucket name and CloudFront domain (for presigned URL generation)

---

### `iam` (IRSA Roles)

5 IRSA roles, all scoped to the EKS OIDC provider. Trust conditions restrict each role to the specific `system:serviceaccount` that needs it.

| Role | Service Account | Permissions |
|---|---|---|
| `fanvault-user-irsa-role` | `dev:dev-user-service`, `prod:user-service` | DynamoDB profiles CRUD, Secrets Manager read |
| `fanvault-commerce-irsa-role` | `dev:dev-commerce-service`, `prod:commerce-service` | DynamoDB (products, orders, audit-logs, metadata), EventBridge PutEvents, SNS Publish (4 topics), SSM GetParameter `/fanvault/*`, S3 product images, Secrets Manager read |
| `fanvault-ai-irsa-role` | `dev:dev-ai-service`, `prod:ai-service` | Bedrock InvokeModel + InvokeModelWithResponseStream, CloudWatch PutMetricData, S3 GetObject (product images), Secrets Manager read |
| `fanvault-cloudwatch-agent-irsa-role` | `amazon-cloudwatch:cloudwatch-agent` | CloudWatchAgentServerPolicy (Container Insights + Fluent Bit) |
| `fanvault-alertmanager-irsa-role` | `monitoring:kube-prometheus-stack-alertmanager` | SNS Publish to `admin-operational-alerts`, KMS Decrypt |

Additional inline policies (attached in `environments/dev/main.tf` to break circular module deps):
- `lambda_consumers_sns_kms` — Lambda consumer execution roles can use the SNS KMS key
- `commerce_irsa_sns_kms` — commerce IRSA role can use the SNS KMS key
- `ai_bedrock_cross_account` — ai IRSA role can `sts:AssumeRole` on `arn:aws:iam::899071933396:role/fanvault-bedrock-cross-account-role`

---

### `argocd`

ArgoCD installed via Helm release `argo-cd` version `7.1.3` into the `argocd` namespace. Service type `ClusterIP` — exposed internally only (port-forward or Gateway HTTPRoute for UI access).

ArgoCD connects to the [Fanvault-GitOps](../Fanvault-GitOps/) repository and runs the App of Apps pattern to manage all application Helm charts.

---

### `observability`

Full Prometheus monitoring stack via `kube-prometheus-stack`:

```
kube-prometheus-stack (namespace: monitoring)
  ├── Prometheus        — 15-day retention, 20Gi PV (EBS gp2/gp3 via EBS CSI)
  ├── Grafana           — 10Gi PV, admin password stored in SSM (never in state)
  │     Dashboards (auto-discovered via ConfigMap labels):
  │       cluster-overview       gnetId 7249 — Kubernetes cluster overview
  │       node-exporter          gnetId 1860 — Node Exporter Full
  │       kubernetes-deployments gnetId 8588 — Kubernetes Deployments
  │       fanvault-services               — CPU, memory, HPA replicas, restart rate
  │       ai-service                      — AI service CPU + memory
  └── Alertmanager      — 5Gi PV, publishes alerts to SNS (admin-operational-alerts)
                          via IRSA role (SigV4 auth, no static keys)
```

VPA `VerticalPodAutoscaler` objects (recommendation mode) are also deployed for all 4 application services in the `dev` namespace.

---

### `notifications`

KMS-encrypted SNS + SQS alert pipeline:

```
KMS Key: fanvault-dev-sns-key (auto-rotate, 7d deletion window)
  Principals: SNS, EventBridge, SQS services

SNS Topics (all KMS-encrypted):
  ├── fanvault-dev-low-inventory-alerts
  │     → SQS: low-inventory-alerts-queue
  │     → Email (optional, var.alert_email)
  │     → EventBridge rule routes InventoryLow events here directly
  ├── fanvault-dev-order-failure-alerts
  │     → SQS: order-failure-alerts-queue
  │     → Email (optional)
  ├── fanvault-dev-product-upload-failures
  │     → SQS: product-upload-failures-queue
  │     → Email (optional)
  └── fanvault-dev-admin-operational-alerts
        → SQS: admin-operational-alerts-queue
        → Email (optional)
        ← Alertmanager publishes Prometheus alerts here (IRSA SigV4)

SQS DLQ: fanvault-dev-sns-dlq (14-day retention, KMS)
  ← Used as redrive target for all 4 SQS subscriptions
```

---

### `event_processing`

EventBridge custom bus `fanvault-dev-event-bus` with Lambda consumer functions. The commerce-service publishes events (source: `fanvault.commerce`):

| Event | Published by | Consumer Lambda |
|---|---|---|
| `ProductCreated` | commerce-service | Inventory / catalog indexer |
| `ProductUpdated` | commerce-service | Catalog sync |
| `InventoryLow` | commerce-service | → SNS `low-inventory-alerts` directly via EventBridge rule |
| `OrderPlaced` | commerce-service | Order fulfillment pipeline |

---

### `eks_monitoring`

CloudWatch alarms covering:
- DynamoDB tables (throttle events, system errors)
- Lambda consumer functions (error rate, duration)
- SNS topics (failed notifications)

Alarm actions publish to SNS `admin-operational-alerts`.

---

## Kubernetes Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  EKS Cluster: fanvault-dev-eks                                                          │
│                                                                                         │
│  ┌─────── kube-system ──────────────────────────────────────────────────────────────┐  │
│  │  CoreDNS  │  kube-proxy  │  metrics-server  │  aws-node (VPC CNI)               │  │
│  │  aws-ebs-csi-driver  │  VPA recommender                                          │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── karpenter ────────────────────────────────────────────────────────────────┐  │
│  │  karpenter-controller (IRSA: karpenter-controller)                               │  │
│  │  Watches for unschedulable pods → provisions EC2 instances (spot/on-demand)      │  │
│  │  SQS interruption queue → graceful drain on spot termination                     │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── argocd ───────────────────────────────────────────────────────────────────┐  │
│  │  argocd-server (ClusterIP)                                                        │  │
│  │  argocd-repo-server │ argocd-application-controller │ argocd-redis              │  │
│  │                                                                                   │  │
│  │  App of Apps → Fanvault-GitOps repo                                               │  │
│  │    bootstrap-dev.yaml → apps-dev/ → 4 ArgoCD Applications                        │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── monitoring ───────────────────────────────────────────────────────────────┐  │
│  │  Prometheus (20Gi PV)  │  Grafana (10Gi PV)  │  Alertmanager (5Gi PV)           │  │
│  │  node-exporter (DaemonSet)  │  kube-state-metrics                                │  │
│  │                                                                                   │  │
│  │  Alertmanager → SNS admin-operational-alerts (IRSA SigV4)                        │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── amazon-cloudwatch ────────────────────────────────────────────────────────┐  │
│  │  CloudWatch Agent (Container Insights)  │  Fluent Bit (log shipping)             │  │
│  │  IRSA: cloudwatch-agent-irsa-role → CloudWatchAgentServerPolicy                  │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── kgateway-system (deployed by GitOps) ─────────────────────────────────────┐ │
│  │  kgateway controller                                                              │ │
│  │  Gateway → AWS NLB                                                                │ │
│  │  HTTPRoutes: /api/auth|users → user-service:3001                                 │ │
│  │             /api/products|orders|admin → commerce-service:3002                   │ │
│  │             /api/ai → ai-service:8000                                             │ │
│  │             / → frontend:8080                                                     │ │
│  └──────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
│  ┌─────── dev (application namespace) ─────────────────────────────────────────────┐  │
│  │  dev-user-service     :3001  (Node.js)    IRSA: user-irsa-role                  │  │
│  │  dev-commerce-service :3002  (Node.js)    IRSA: commerce-irsa-role              │  │
│  │  dev-ai-service       :8000  (Python)     IRSA: ai-irsa-role                    │  │
│  │  dev-frontend         :8080  (Nginx)      No IRSA (static files only)           │  │
│  │                                                                                   │  │
│  │  All pods: runAsNonRoot, capabilities.drop ALL, NetworkPolicy enforced           │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌─────── prod (application namespace) ────────────────────────────────────────────┐  │
│  │  (mirror of dev namespace — prod Helm values applied by ArgoCD)                  │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## IRSA Flow

```
Pod (dev-commerce-service)
  │
  │  Kubernetes ServiceAccount: dev-commerce-service
  │  Annotation: eks.amazonaws.com/role-arn = arn:aws:iam::773384830607:role/fanvault-commerce-irsa-role
  │
  ▼
EKS OIDC Provider (eks.amazonaws.com/...)
  │  Issues projected ServiceAccount token (audience: sts.amazonaws.com)
  │
  ▼
AWS STS — AssumeRoleWithWebIdentity
  │  Trust policy checks: sub = system:serviceaccount:dev:dev-commerce-service
  │
  ▼
Temporary credentials (injected via AWS_WEB_IDENTITY_TOKEN_FILE)
  │
  ▼
DynamoDB, EventBridge, SNS, SSM, S3 — with least-privilege policies

─── AI Service (cross-account) ─────────────────────────────────────────────
ai-service pod (IRSA: fanvault-ai-irsa-role in account 773384830607)
  │
  ▼  STS AssumeRole
account 899071933396: fanvault-bedrock-cross-account-role
  │
  ▼
Bedrock: amazon.nova-pro-v1:0 (multimodal image → metadata)
```

---

## Deployment Order

Terraform applies the dev environment in dependency order:

```
1. vpc              — networking foundation
2. eks              — cluster + OIDC provider
3. cognito          — user pool (no EKS dependency)
4. ecr              — container registries (no EKS dependency)
5. dynamodb         — tables (no EKS dependency)
6. s3               — product images bucket
7. cloudfront       — distribution (depends on s3)
8. secrets_manager  — app secrets
9. notifications    — SNS + SQS + KMS key
10. event_processing — EventBridge + Lambda consumers (depends on notifications)
11. iam             — IRSA roles (depends on eks OIDC, dynamodb, s3, notifications)
12. configuration   — SSM parameters (depends on cognito, s3, cloudfront, notifications)
13. cloudwatch      — log groups
14. eks_addons      — Helm releases into cluster (depends on eks)
15. karpenter       — Helm release + NodePool + EC2NodeClass (depends on eks, iam)
16. argocd          — Helm release (depends on eks)
17. observability   — kube-prometheus-stack Helm (depends on eks_addons for EBS CSI + VPA CRDs)
18. eks_monitoring  — CloudWatch alarms (depends on dynamodb, event_processing, notifications)
```

> Terraform does not guarantee this exact order — the dependency graph is enforced by module
> output references. The sequence above reflects the logical data flow.

---

## Input Variables (dev)

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS target region |
| `project_name` | `fanvault` | Resource name prefix |
| `environment` | `dev` | Environment tag |
| `github_repo` | `Fanvault-CloudOps/Fanvault-v3-App` | GitHub repo for OIDC trust |
| `jwt_secret` | (required, sensitive) | JWT signing secret — stored in Secrets Manager |
| `jwt_refresh_secret` | (required, sensitive) | JWT refresh signing secret |
| `karpenter_max_cpu` | `"20"` | Max CPU for Karpenter burst nodes |
| `karpenter_max_memory` | `"40Gi"` | Max memory for Karpenter burst nodes |
| `prometheus_retention_days` | `15` | Prometheus TSDB retention |

Sensitive variables are never committed. Pass via `terraform.tfvars` (gitignored) or CI/CD environment.

---

## Remote State

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket = "fanvault-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

## Usage

```bash
cd environments/dev

# First-time setup
terraform init

# Review changes
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"

# After apply — configure kubectl
aws eks update-kubeconfig \
  --region us-east-1 \
  --name fanvault-dev-eks

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Get ArgoCD initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Get Grafana admin password
aws ssm get-parameter \
  --name /fanvault/grafana/admin_password \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

---

## CI/CD Integration

GitHub Actions workflows in [Fanvault-v3-App](../Fanvault-v3-App/) build and push images to ECR, then update image tags in [Fanvault-GitOps](../Fanvault-GitOps/). ArgoCD detects the diff and deploys.

GitHub Actions authenticates to the EKS cluster via the `github_actions` EKS Access Entry (OIDC → `AmazonEKSClusterAdminPolicy`), not static IAM keys.

```
GitHub Actions CI
  │  docker build + push → ECR (fanvault-dev-{service}:{tag})
  │  git push image tag → Fanvault-GitOps
  │
  ▼
ArgoCD (in-cluster)
  │  detects Helm value diff
  │  kubectl apply (Deployment, Service, HPA, NetworkPolicy)
  │
  ▼
Karpenter (if new pods are unschedulable)
  └── provisions EC2 nodes → pods scheduled → live
```

---

## Related Repositories

| Repository | Description |
|---|---|
| [Fanvault-v3-App](../Fanvault-v3-App/) | Application source (user-service, commerce-service, ai-service, frontend) |
| [Fanvault-GitOps](../Fanvault-GitOps/) | Helm charts + ArgoCD App of Apps configuration |
