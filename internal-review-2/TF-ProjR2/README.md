# FanVault Infrastructure — Terraform

Terraform configuration for the FanVault v2 AWS infrastructure. Manages all cloud resources for a fan-merchandise e-commerce platform across networking, compute, storage, event processing, observability, and security layers.

- **Region:** `us-east-1`
- **Terraform:** `>= 1.5.0`
- **AWS Provider:** `~> 5.0`
- **State backend:** S3 (`fanvault-v2-tfstate-899071933396`) + DynamoDB locking (`fanvault-v2-tfstate-locks`)

---

## Repository Structure

```
Terraform-Fanvault-Infra/
├── main.tf                     # Root module — wires all child modules together
├── variables.tf                # Input variable declarations
├── outputs.tf                  # Root-level outputs
├── providers.tf                # AWS provider + S3 remote state backend
├── terraform.tfvars            # Default variable values
├── imports.tf / moved.tf       # Resource import & move blocks
├── environment/
│   ├── dev.tfvars
│   └── prod.tfvars
├── modules/
│   ├── networking/             # VPC, subnets, routing, VPC endpoints
│   ├── security_groups/        # All security groups
│   ├── backend/                # EC2 (bastion + ASGs), ALB, launch templates
│   ├── storage/                # DynamoDB tables, S3 buckets, CloudFront, Lambda
│   ├── event_processing/       # EventBridge bus, Lambda consumers, SQS DLQ
│   ├── notifications/          # SNS topics, SQS alert queues, KMS key
│   ├── iam/                    # IAM roles, instance profiles, GitHub OIDC
│   ├── configuration/          # SSM Parameter Store parameters
│   ├── monitoring/             # CloudWatch alarms, log groups, dashboard
│   ├── governance/             # WAFv2 Web ACL (CloudFront scope)
│   └── dns/                    # Route 53 private hosted zone (fanvault.internal)
└── .github/workflows/
    ├── terraform-apply.yml     # Push to main → plan + apply
    ├── terraform-pr.yml        # PR → format check + validate + plan
    └── terraform-drift.yml     # Daily drift detection (10:00 UTC)
```

---

## Architecture Overview

Traffic enters exclusively through a **CloudFront distribution** protected by **WAFv2**. CloudFront forwards requests to two origins — an **Application Load Balancer** (ALB) for dynamic content and a private **S3 bucket** for static media. The ALB uses a secret custom header (`X-Custom-Header`) to reject any requests that bypass CloudFront.

Behind the ALB, two **Auto Scaling Groups** run in private subnets:
- **Frontend ASG** — Nginx serving a compiled React/Vite SPA
- **Backend ASG** — Both Node.js microservices (Identity on `:3001`, Commerce on `:3002`) co-hosted on the same instances

The backend services interact with **DynamoDB** (6 tables), **S3** (product images), and **EventBridge** (event bus) — all reachable without public internet via **VPC Gateway/Interface Endpoints**. A **Bastion Host** in the public subnet provides SSH access for administration.

An event-driven pipeline driven by **EventBridge** triggers three **Lambda consumers** for audit logging, thumbnail generation, and inventory monitoring. **SNS topics** (4) with **SQS queues** relay operational alerts. All secrets and configuration are stored in **SSM Parameter Store**.

---

## Module Details

### networking

| Resource | Name | CIDR |
|---|---|---|
| VPC | `fanvault-vpc` | `10.0.0.0/16` |
| Public subnets | `fanvault-public-1a/1b` | `10.0.1.0/24`, `10.0.2.0/24` |
| Frontend private subnets | `fanvault-frontend-1a/1b` | `10.0.11.0/24`, `10.0.12.0/24` |
| Backend private subnets | `fanvault-backend-1a/1b` | `10.0.21.0/24`, `10.0.22.0/24` |
| Database private subnets | `fanvault-db-1a/1b` | `10.0.31.0/24`, `10.0.32.0/24` |
| Internet Gateway | `fanvault-igw` | — |
| NAT Gateway + EIP | `fanvault-nat-gw` | Public subnet 1a |

**VPC Endpoints:**

| Endpoint | Type | Used by |
|---|---|---|
| S3 | Gateway | Private + DB route tables |
| DynamoDB | Gateway | Private + DB route tables |
| SSM | Interface | Backend private subnets |
| SSMMessages | Interface | Backend private subnets |
| EC2Messages | Interface | Backend private subnets |
| SecretsManager | Interface | Backend private subnets |

---

### security_groups

| Security Group | Inbound | Outbound |
|---|---|---|
| `fanvault-alb-sg` | `:80` from CloudFront managed prefix list only | All |
| `fanvault-bastion-sg` | `:22` from `admin_ssh_ip` | All |
| `fanvault-frontend-sg` | `:80` from ALB SG; `:22` from Bastion SG | All (via NAT) |
| `fanvault-backend-sg` | `:3001`, `:3002` from ALB SG; `:22` from Bastion SG | All (via NAT) |
| `fanvault-vpc-endpoints-sg` | `:443` from `10.0.0.0/16` | All |

---

### backend

**Bastion Host**
- Instance type: `t3.micro`, Ubuntu 22.04 LTS
- Placed in public subnet 1a with IMDSv2 enforced

**Application Load Balancer**
- Internet-facing, spans public subnets 1a and 1b
- Default action: `403 Access Denied` (blocks direct access bypassing CloudFront)

**ALB Listener Rules (Port 80):**

| Priority | Condition | Target |
|---|---|---|
| 5 | Host: `arch.fanvault.com` + custom header | Lambda (arch page) |
| 10 | Path: `/api/auth*` + custom header | Identity TG (`:3001`) |
| 15 | Path: `/api/admin*` + custom header | Commerce TG (`:3002`) |
| 20 | Path: `/api/users*` + custom header | Identity TG (`:3001`) |
| 30 | Path: `/api/products*` + custom header | Commerce TG (`:3002`) |
| 40 | Path: `/api/orders*` + custom header | Commerce TG (`:3002`) |
| 99 | Path: `/*` + custom header | Frontend TG (`:80`) |

**Launch Templates & ASGs:**

| | Frontend | Backend |
|---|---|---|
| Instance type | `t3.small` | `t3.small` |
| AMI | Ubuntu 22.04 LTS (latest) | Ubuntu 22.04 LTS (latest) |
| Subnets | Frontend private | Backend private |
| Services | Nginx (React SPA) | Identity (`:3001`) + Commerce (`:3002`) via PM2 |
| Desired / Min / Max | 1 / 1 / 1 | 1 / 1 / 1 |
| Scale-out trigger | CPU > 70% | CPU > 70% |
| Refresh strategy | Rolling (50% healthy) | Rolling (50% healthy) |

> **Production note:** Raise `max_size` to 4 and `desired_capacity` to 2 on both ASGs for HA.

---

### storage

**DynamoDB Tables (6):**

| Table | PK | SK | GSIs | Notes |
|---|---|---|---|---|
| `fanvault-users` | `userId` | — | `email-index` | Auth credentials |
| `fanvault-profiles` | `userId` | — | — | User profile data (1:1 with users) |
| `fanvault-products` | `productId` | — | `sku-index`, `category-franchise-index` | Product catalog |
| `fanvault-orders` | `orderId` | — | `userId-createdAt-index`, `orderNumber-index`, `status-createdAt-index` | Customer orders |
| `fanvault-audit-logs` | `logId` | — | `entityType-timestamp-index`, `adminId-timestamp-index` | 1-day TTL on `ttlExpiry` |
| `fanvault-metadata` | `metaType` | `metaId` | — | Admin-managed category/franchise lookup |

All tables: **PAY_PER_REQUEST**, KMS encryption enabled, PITR enabled.

**S3 Buckets:**

| Bucket | Purpose | Public | Versioning |
|---|---|---|---|
| `fanvault-product-images-*` | Product images, thumbnails, category images | Blocked | Enabled |
| `fanvault-architecture-*` | Architecture diagram PNG | Blocked | — |

Product images bucket lifecycle: noncurrent versions → STANDARD_IA after 30 days → expire after 90 days; incomplete multipart uploads abort after 7 days.

**CloudFront Distribution:**

| Path Pattern | Origin | Caching |
|---|---|---|
| `/products/*` | S3 product images | CachingOptimized |
| `/thumbnails/*` | S3 product images | CachingOptimized |
| `/categories/*` | S3 product images | CachingOptimized |
| `/images/*` | S3 product images | CachingOptimized |
| `/api/*` | ALB | CachingDisabled + AllViewer |
| `/*` (default) | ALB | CachingDisabled + AllViewer |

- OAC (Origin Access Control) with SigV4 signing restricts S3 access to this distribution only
- WAFv2 Web ACL attached at distribution level
- `redirect-to-https` enforced on all behaviors
- IPv6 enabled; `PriceClass_100` (US, Canada, Europe)

**Architecture Lambda** (`fanvault-arch-page-lambda`): Node.js 20.x function that reads `architecture.png` from the private S3 bucket and returns it as a base64-encoded PNG to the ALB.

---

### event_processing

**EventBridge Custom Bus:** `fanvault-event-bus`  
All commerce domain events are sourced from `fanvault.commerce`.

**SQS Dead-Letter Queue:** `fanvault-event-dlq` (14-day retention, long-polling)

**Lambda Consumers (Node.js 20.x, all via EventBridge rules):**

| Lambda | Trigger | Action |
|---|---|---|
| `fanvault-audit-logging-consumer` | All `fanvault.commerce` events | Writes audit log to `fanvault-audit-logs` DynamoDB |
| `fanvault-thumbnail-generator-consumer` | `ProductCreated`, `ProductUpdated` | Copies `products/*` images to `thumbnails/`, updates product record; publishes to `product-upload-failures` SNS on error |
| `fanvault-inventory-monitor-consumer` | `InventoryLow` | Publishes formatted alert to `low-inventory-alerts` SNS |

All EventBridge rules: retry up to 3 times over 1 hour; failed events land in the SQS DLQ.

A fourth rule routes `InventoryLow` events directly to the `low-inventory-alerts` SNS topic (in addition to the Lambda consumer).

---

### notifications

**KMS Key:** `fanvault-sns-key` — key rotation enabled, 7-day deletion window. Used to encrypt all SNS topics and SQS alert queues.

**SNS Topics → SQS Queues (fan-out with SNS DLQ for failed subscriptions):**

| Topic | Queue | Purpose |
|---|---|---|
| `fanvault-low-inventory-alerts` | `fanvault-low-inventory-alerts-queue` | Stock below threshold |
| `fanvault-order-failure-alerts` | `fanvault-order-failure-alerts-queue` | Order processing errors |
| `fanvault-product-upload-failures` | `fanvault-product-upload-failures-queue` | Image upload / thumbnail failures |
| `fanvault-admin-operational-alerts` | `fanvault-admin-operational-alerts-queue` | General operational incidents |

All topics support optional email subscription via the `alert_email` variable.  
All topics have delivery logging (success + failure) at 100% sample rate via `fanvault-sns-feedback-role`.

---

### iam

| Role | Principal | Permissions |
|---|---|---|
| `fanvault-lambda-s3-role` | Lambda | S3 ReadOnly + Lambda basic execution (arch page) |
| `fanvault-lambda-consumers-role` | Lambda | DynamoDB R/W (audit-logs, products), S3 R/W (product images), SNS publish (low-inventory, product-upload-failures), KMS |
| `fanvault-ec2-backend-role` | EC2 | DynamoDB full access (6 tables + GSIs), SSM `/fanvault/*`, S3 `fanvault-*`, CloudWatch logs + metrics, EventBridge PutEvents, SNS publish (4 topics) + KMS |
| `fanvault-ec2-frontend-role` | EC2 | SSM `/fanvault/git/*` (read-only), CloudWatch logs + metrics |
| `fanvault-github-actions-role` | GitHub OIDC (`repo:Savitxr/TF-ProjR1:*`) | `AdministratorAccess` |
| `fanvault-sns-feedback-role` | SNS | CloudWatch logs (for SNS delivery feedback) |

---

### configuration

All SSM Parameters stored under `/fanvault/` prefix:

| Path | Type | Value source |
|---|---|---|
| `/fanvault/git/repo_url` | String | `git_repo_url` var |
| `/fanvault/git/branch` | String | `git_branch` var |
| `/fanvault/app/cors_origin` | String | `cors_origin` var |
| `/fanvault/app/jwt_secret` | SecureString | `jwt_secret` var (lifecycle: ignore_changes) |
| `/fanvault/app/jwt_refresh_secret` | SecureString | `jwt_refresh_secret` var (lifecycle: ignore_changes) |
| `/fanvault/dynamodb/table_users` | String | DynamoDB table name |
| `/fanvault/dynamodb/table_profiles` | String | DynamoDB table name |
| `/fanvault/dynamodb/table_products` | String | DynamoDB table name |
| `/fanvault/dynamodb/table_orders` | String | DynamoDB table name |
| `/fanvault/dynamodb/table_audit_logs` | String | DynamoDB table name |
| `/fanvault/dynamodb/table_metadata` | String | DynamoDB table name |
| `/fanvault/s3/bucket` | String | Product images bucket name |
| `/fanvault/s3/region` | String | `aws_region` var |
| `/fanvault/s3/cloudfront_url` | String | CloudFront domain name |
| `/fanvault/eventbridge/bus_name` | String | EventBridge bus name |
| `/fanvault/sns/topic_low_inventory` | String | SNS topic ARN |
| `/fanvault/sns/topic_order_failure` | String | SNS topic ARN |
| `/fanvault/sns/topic_product_upload_failure` | String | SNS topic ARN |
| `/fanvault/sns/topic_admin_operational_alert` | String | SNS topic ARN |

---

### monitoring

**CloudWatch Alarms (all route to `fanvault-admin-operational-alerts` SNS):**

| Category | Alarm | Threshold |
|---|---|---|
| ALB | `fanvault-alb-5xx-alarm` | ≥ 5 HTTP 5XX in 1 min |
| Target Groups (×4) | `fanvault-tg-{name}-5xx-alarm` | ≥ 1 HTTP 5XX in 1 min |
| ASG CPU (×2) | `fanvault-asg-{frontend/backend}-cpu-alarm` | > 80% average over 5 min |
| Bastion CPU | `fanvault-bastion-cpu-alarm` | > 80% average over 10 min |
| Bastion Status | `fanvault-bastion-status-check-alarm` | Any failed status check |
| DynamoDB Read (×6) | `fanvault-ddb-{table}-read-throttle` | ≥ 1 throttle event in 1 min |
| DynamoDB Write (×6) | `fanvault-ddb-{table}-write-throttle` | ≥ 1 throttle event in 1 min |
| Lambda Errors (×4) | `fanvault-lambda-{name}-errors` | ≥ 1 error in 1 min |
| Lambda Duration (×4) | `fanvault-lambda-{name}-duration` | > 10 s average in 1 min |
| SNS Failures (×4) | `fanvault-sns-{topic}-delivery-failures` | ≥ 1 delivery failure in 1 min |

**CloudWatch Log Groups** (1-day retention): one per Lambda function.

**CloudWatch Dashboard:** `fanvault-observability-dashboard` — 7 widgets covering ALB 5XX errors, target group 5XX errors, ASG and bastion CPU, DynamoDB throttle events, Lambda errors, Lambda duration, and SNS delivery failures.

---

### governance

**WAFv2 Web ACL** (`fanvault-cf-waf`, CLOUDFRONT scope) attached to the CloudFront distribution:

| Priority | Rule | Action |
|---|---|---|
| 10 | `AWSManagedRulesCommonRuleSet` | Managed (block on match) |
| 20 | `AWSManagedRulesKnownBadInputsRuleSet` | Managed (block on match) |
| 30 | `AWSManagedRulesAmazonIpReputationList` | Managed (block on match) |
| 40 | Rate limit: 100 requests per 5 min per IP | Block |
| 50 | Geo block (when `geo_blocked_countries` is non-empty) | Block |

All rules emit CloudWatch metrics with sampled requests enabled.

---

### dns

**Route 53 Private Hosted Zone:** `fanvault.internal` (associated with the VPC)

| Record | Type | Value |
|---|---|---|
| `db.fanvault.internal` | A | `mongodb_private_ip` var |

> The DNS module is defined but not wired into the root `main.tf` on this branch. It is available for future use when a database tier is added.

---

## CI/CD Pipelines

| Workflow | Trigger | Steps |
|---|---|---|
| `terraform-apply.yml` | Push to `main` | OIDC auth → `init` → `plan` → `apply -auto-approve` |
| `terraform-pr.yml` | PR targeting `main` | OIDC auth → `fmt -check` → `init` → `validate` → `plan` → upload `tfplan` artifact |
| `terraform-drift.yml` | Daily 10:00 UTC + manual dispatch | OIDC auth → `init` → `plan -detailed-exitcode`; fails workflow on drift |

AWS credentials are obtained via **GitHub OIDC** — no long-lived access keys. The GitHub Actions role (`fanvault-github-actions-role`) is constrained to the repository set in the `github_repo` variable.

**Required GitHub secret:** `AWS_ROLE_ARN` — the ARN of `fanvault-github-actions-role`.

---

## Input Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Target AWS region |
| `project_name` | `fanvault` | Resource name prefix |
| `environment` | `production` | Environment tag |
| `admin_ssh_ip` | `0.0.0.0/0` | CIDR for Bastion SSH access |
| `key_name` | `fanvault-key` | EC2 key pair name |
| `cors_origin` | `https://fanvault.example.com` | Allowed CORS origin |
| `jwt_secret` | — | JWT access token secret (sensitive, ≥ 32 chars) |
| `jwt_refresh_secret` | — | JWT refresh token secret (sensitive, ≥ 32 chars) |
| `github_repo` | `Savitxr/TF-ProjR1` | GitHub repo for OIDC trust |
| `alert_email` | `""` | Optional email for SNS alert subscriptions |
| `geo_blocked_countries` | `[]` | ISO codes to block via WAF |
| `git_repo_url` | `https://github.com/Savitxr/Fanvault-v2.git` | App repo URL (stored in SSM) |
| `git_branch` | `main` | App deployment branch |
| `dynamodb_billing_mode` | `PAY_PER_REQUEST` | DynamoDB billing mode |
| `dynamodb_enable_pitr` | `true` | Enable Point-in-Time Recovery |
| `dynamodb_enable_encryption` | `true` | Enable DynamoDB KMS encryption |
| `ssm_parameter_prefix` | `/fanvault` | SSM path prefix |
| `cloudfront_to_alb_custom_header` | `FanVaultSecureHeaderToken2026!` | Secret header value for CF→ALB verification |

---

## Outputs

| Output | Description |
|---|---|
| `alb_dns_name` | Public DNS name of the ALB |
| `bastion_public_ip` | Public IP of the Bastion host |
| `github_actions_role_arn` | IAM role ARN assumed by GitHub Actions |
| `event_bus_name` | EventBridge custom bus name |
| `event_dlq_name` | SQS Dead-Letter Queue name |
| `sns_topic_low_inventory_arn` | Low inventory alerts SNS ARN |
| `sns_topic_order_failure_arn` | Order failure alerts SNS ARN |
| `sns_topic_product_upload_failure_arn` | Product upload failures SNS ARN |
| `sns_topic_admin_operational_alert_arn` | Admin operational alerts SNS ARN |
| `waf_web_acl_arn` | WAFv2 Web ACL ARN |
| `waf_web_acl_id` | WAFv2 Web ACL ID |
| `waf_web_acl_name` | WAFv2 Web ACL name |

---

## Deployment

**Prerequisites**
- Terraform `>= 1.5.0`
- AWS CLI configured with permissions to assume the deployment role
- S3 state bucket and DynamoDB lock table already exist (one-time bootstrap)
- EC2 key pair `fanvault-key` created in `us-east-1`

**Deploy**
```bash
# From the repo root
terraform init
terraform plan -var-file=environment/prod.tfvars -out=tfplan
terraform apply tfplan
```

**Switch environments**
```bash
terraform plan -var-file=environment/dev.tfvars -out=tfplan
terraform apply tfplan
```

**Restrict Bastion SSH access (recommended)**
```hcl
# terraform.tfvars
admin_ssh_ip = "203.0.113.42/32"
```

**Enable geo-blocking**
```hcl
# terraform.tfvars
geo_blocked_countries = ["CN", "RU", "KP"]
```

**Scale for production**
Set `desired_capacity = 2`, `min_size = 2`, and `max_size = 4` on both ASGs in [modules/backend/main.tf](modules/backend/main.tf).
