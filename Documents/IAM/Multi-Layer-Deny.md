# AWS Multi-Layer Deny Conflict Lab

## Understanding SCPs, Permissions Boundaries, and IAM Policy Evaluation

### Objective

This lab demonstrates how AWS evaluates permissions when multiple authorization layers are involved.

The goal is to understand why a user with **AdministratorAccess** can still receive an **Access Denied** error and how to troubleshoot such scenarios systematically.

This is one of the most common real-world AWS IAM troubleshooting scenarios.

---

# Learning Outcomes

After completing this lab, you will understand:

* How AWS evaluates permissions across multiple layers
* How Service Control Policies (SCPs) work
* How Permissions Boundaries work
* Why AdministratorAccess does not guarantee full access
* How Explicit Deny overrides Allow
* How to troubleshoot AccessDenied errors in enterprise AWS environments

---

# Lab Environment

| Component            | Value               |
| -------------------- | ------------------- |
| AWS Account          | 773384830607        |
| AWS Organizations    | Enabled             |
| Organizational Unit  | Engineering         |
| IAM User             | Dev-Admin           |
| IAM Policy           | AdministratorAccess |
| Permissions Boundary | DevBoundary         |
| SCP                  | Deny-RDS-Create     |
| Service Used         | Amazon RDS          |

---

# Architecture Overview

```text
AWS Organization
│
└── Root
    │
    └── Engineering OU
          │
          └── Account (773384830607)
                │
                └── IAM User: Dev-Admin
                        │
                        ├── AdministratorAccess
                        ├── Permissions Boundary
                        └── SCP Evaluation
```

---

# Understanding AWS Permission Evaluation

AWS does not evaluate permissions using a simple "Allow = Access Granted" model.

Instead, AWS evaluates multiple policy layers together.

Conceptually:

```text
Effective Permissions =
IAM Policy
AND
Permissions Boundary
AND
SCP
AND
Resource Policies
AND
Session Policies
```

The most restrictive layer always wins.

---

# Enterprise Analogy

Think of AWS authorization like airport security.

### IAM Policy

The user possesses a valid boarding pass.

```text
AdministratorAccess
```

The boarding pass says:

```text
You may travel anywhere.
```

---

### Permissions Boundary

The airline places a restriction.

```text
You may only fly domestic routes.
```

Even though the boarding pass allows everything, the boundary limits what can actually be used.

---

### SCP

The government imposes a restriction.

```text
No flights allowed to specific destinations.
```

Regardless of airline permissions, the government restriction wins.

---

# Step 1 - Create an AWS Organization

Navigate to:

```text
AWS Organizations
```

Create an organization using:

```text
Enable All Features
```

Why?

SCPs only function when Organizations is operating in All Features mode.

---

# Step 2 - Create an Organizational Unit

Create an OU named:

```text
Engineering
```

Purpose:

Organizational Units allow governance policies to be applied to groups of accounts.

Structure:

```text
Root
 └── Engineering
```

---

# Step 3 - Move Account into the OU

Move account:

```text
773384830607
```

into:

```text
Engineering OU
```

Result:

```text
Root
 └── Engineering
      └── 773384830607
```

Now any SCP attached to Engineering affects this account.

---

# Step 4 - Create the SCP

Create a Service Control Policy named:

```text
Deny-RDS-Create
```

Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRDSCreation",
      "Effect": "Deny",
      "Action": [
        "rds:CreateDBInstance"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach the SCP to:

```text
Engineering OU
```

---

# What the SCP Does

The SCP explicitly blocks:

```text
rds:CreateDBInstance
```

for every account inside the OU.

Important:

SCPs do not grant permissions.

They only define the maximum permissions an account may use.

---

# Step 5 - Create the Permissions Boundary

Create an IAM policy named:

```text
DevBoundary
```

Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOnlyS3AndEC2",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyIAMChanges",
      "Effect": "Deny",
      "Action": [
        "iam:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

# What the Boundary Does

The boundary only allows:

```text
S3
EC2
```

Everything else becomes unavailable.

This includes:

```text
RDS
Lambda
CloudFormation
SNS
SQS
ECR
ECS
```

even if an IAM policy grants access.

Important concept:

Permissions Boundaries do not grant permissions.

They define the maximum permissions an identity can ever receive.

---

# Step 6 - Create the IAM User

Create:

```text
Dev-Admin
```

Attach:

```text
AdministratorAccess
```

Apply the boundary:

```text
DevBoundary
```

Result:

```text
User = AdministratorAccess
Boundary = S3 + EC2 Only
```

---

# Initial Permission Evaluation

| Layer                | RDS Create Allowed? |
| -------------------- | ------------------- |
| AdministratorAccess  | Yes                 |
| Permissions Boundary | No                  |
| SCP                  | No                  |
| Final Result         | Denied              |

---

# Expected Behavior

Login as:

```text
Dev-Admin
```

Navigate to:

```text
RDS → Create Database
```

Attempt to create a database.

Result:

```text
AccessDenied
```

---

# Why the Request Fails

Two separate layers block the request.

### Layer 1 - SCP

The SCP explicitly denies:

```text
rds:CreateDBInstance
```

---

### Layer 2 - Permissions Boundary

The boundary does not allow:

```text
rds:*
```

Even without the SCP, the request still fails.

This demonstrates layered security controls.

---

# Troubleshooting Approach

When you receive:

```text
AccessDenied
```

Always investigate in this order:

### 1. SCP

Check:

```text
AWS Organizations
```

Look for:

```text
Explicit Deny
```

---

### 2. Permissions Boundary

Check:

```text
IAM User
→ Permissions Boundary
```

Verify the action is allowed.

---

### 3. IAM Policies

Check:

```text
Attached Policies
Inline Policies
Groups
```

---

### 4. Resource Policies

Examples:

```text
S3 Bucket Policies
KMS Key Policies
SNS Topic Policies
```

---

# Fixing the Problem

## Phase 1 - Remove SCP Restriction

Detach:

```text
Deny-RDS-Create
```

or remove the deny statement.

Current state:

| Layer    | Result |
| -------- | ------ |
| IAM      | Allow  |
| Boundary | Deny   |
| SCP      | Allow  |
| Final    | Denied |

Access still fails.

---

## Why It Still Fails

Because the boundary remains restrictive.

Remember:

```text
IAM Policy
AND
Permissions Boundary
AND
SCP
```

All layers must allow the action.

---

# Phase 2 - Modify the Boundary

Update the boundary:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCoreServices",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "ec2:*",
        "rds:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

# Final Permission Evaluation

| Layer        | RDS Create Allowed? |
| ------------ | ------------------- |
| IAM          | Yes                 |
| Boundary     | Yes                 |
| SCP          | Yes                 |
| Final Result | Allowed             |

---

# Key AWS Security Principles Demonstrated

## Principle 1 - Explicit Deny Wins

AWS always prioritizes:

```text
Deny
```

over:

```text
Allow
```

Regardless of where the allow originates.

---

## Principle 2 - SCPs Are Guardrails

SCPs:

* Do not grant permissions
* Restrict accounts
* Apply organization-wide
* Are managed by central governance teams

---

## Principle 3 - Permissions Boundaries Are Identity Guardrails

Boundaries:

* Restrict IAM users and roles
* Define maximum permissions
* Are commonly used for delegated administration

---

## Principle 4 - AdministratorAccess Is Not Absolute

Having:

```text
AdministratorAccess
```

does not guarantee access.

The permission must survive every evaluation layer.

---

# Real-World Enterprise Mapping

| Layer                | Typical Owner       |
| -------------------- | ------------------- |
| SCP                  | Cloud Security Team |
| Permissions Boundary | IAM / Platform Team |
| IAM Policies         | Application Team    |
| Resource Policies    | Service Owners      |

This separation of responsibilities is one reason enterprise AWS environments are secure and governed at scale.

---

# Common Interview Question

### Question

Why would a user with AdministratorAccess receive AccessDenied?

### Answer

Because AWS evaluates multiple authorization layers.

Possible causes include:

* Service Control Policies (SCPs)
* Permissions Boundaries
* Explicit Deny statements
* Resource Policies
* Session Policies

An explicit deny or restrictive boundary can override AdministratorAccess and prevent the action.

---

# Key Takeaway

Whenever troubleshooting AWS permissions, remember:

```text
AdministratorAccess
≠
Unlimited Access
```

The actual permission is determined by the intersection of every applicable policy layer.

Always investigate:

1. SCPs
2. Permissions Boundaries
3. IAM Policies
4. Resource Policies
5. Session Policies

in that order.
