# AWS Cross-Account S3 Access Using IAM Role and STS

## Objective

Implement secure cross-account access where an IAM principal in an **Analytics Account** can read objects from a private S3 bucket located in a **Production Account** without using long-term access keys.

This pattern is widely used in enterprise environments for analytics, reporting, data lakes, SIEM integrations, and third-party SaaS access.

---

## Architecture Overview

```text
Analytics Account (111111111111)
        |
        | sts:AssumeRole + External ID
        v
CrossAccountReadRole
(Production Account - 222222222222)
        |
        | Read-Only Access
        v
S3 Bucket: prod-sensitive-data-jb-1
```

---

## Why Use Cross-Account Roles?

Organizations commonly separate workloads across multiple AWS accounts:

* Production account contains sensitive data.
* Analytics account performs reporting and analysis.
* Security account centralizes logs.
* Sandbox account is used for testing.

Rather than sharing IAM user credentials or access keys, AWS Security Token Service (STS) provides temporary credentials through role assumption.

### Benefits

* No long-term credentials
* Temporary session-based access
* Centralized permission management
* Supports least privilege principles
* Enables account isolation
* Easier auditing through CloudTrail

---

## Security Concepts Used

| Concept                 | Purpose                                        |
| ----------------------- | ---------------------------------------------- |
| IAM Role                | Delegates permissions securely                 |
| STS AssumeRole          | Issues temporary credentials                   |
| External ID             | Prevents Confused Deputy attacks               |
| Least Privilege         | Grants only required permissions               |
| S3 Resource Permissions | Restricts access to specific bucket            |
| Temporary Sessions      | Automatically expire after configured duration |

---

# Production Account Configuration

## Account Details

| Item        | Value                    |
| ----------- | ------------------------ |
| Account ID  | 222222222222             |
| Bucket Name | prod-sensitive-data-jb-1 |
| IAM Role    | CrossAccountReadRole     |

---

## Step 1: Create the S3 Bucket

Navigate to:

```text
AWS Console → S3 → Create Bucket
```

Configure:

| Setting             | Value                    |
| ------------------- | ------------------------ |
| Bucket Name         | prod-sensitive-data-jb-1 |
| Block Public Access | Enabled                  |
| Versioning          | Optional                 |
| Encryption          | Enabled                  |

Create the bucket.

---

## Step 2: Upload a Test Object

Upload a sample file:

```text
Day1 TakeAway.txt
```

This file will be used to verify cross-account access.

---

## Step 3: Create the Cross-Account IAM Role

Navigate to:

```text
IAM → Roles → Create Role
```

Choose:

```text
Trusted Entity Type:
AWS Account
```

Select:

```text
Another AWS Account
```

Enter:

```text
111111111111
```

Enable:

```text
Require External ID
```

External ID:

```text
SecureAnalyticsToken123
```

Continue to the permissions page.

---

## Step 4: Create the S3 Read Policy

Navigate to:

```text
IAM → Policies → Create Policy
```

Select the JSON editor and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::prod-sensitive-data-jb-1"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::prod-sensitive-data-jb-1/*"
    }
  ]
}
```

Policy Name:

```text
CrossAccountS3ReadPolicy
```

Create the policy.

---

## Step 5: Attach Policy to the Role

Attach:

```text
CrossAccountS3ReadPolicy
```

Role Name:

```text
CrossAccountReadRole
```

Create the role.

---

## Step 6: Verify Trust Relationship

Open:

```text
IAM → Roles → CrossAccountReadRole
```

Navigate to:

```text
Trust Relationships
```

Verify the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "SecureAnalyticsToken123"
        }
      }
    }
  ]
}
```

---

# Analytics Account Configuration

## Account Details

| Item       | Value          |
| ---------- | -------------- |
| Account ID | 111111111111   |
| IAM User   | analytics-user |

---

## Step 7: Create Analytics User

Navigate to:

```text
IAM → Users → Create User
```

Create:

```text
analytics-user
```

Enable access appropriate for your lab:

* AWS Management Console Access
* Programmatic Access

Complete user creation.

---

## Step 8: Create AssumeRole Policy

Navigate to:

```text
IAM → Policies → Create Policy
```

Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::222222222222:role/CrossAccountReadRole"
    }
  ]
}
```

Policy Name:

```text
AllowAssumeCrossAccountRole
```

Create policy.

---

## Step 9: Attach Policy to User

Open:

```text
IAM → Users → analytics-user
```

Attach:

```text
AllowAssumeCrossAccountRole
```

---

# Testing the Implementation

## Step 10: Configure AWS CLI

Configure the CLI using analytics-user credentials:

```bash
aws configure
```

Provide:

```text
Access Key ID
Secret Access Key
Region
Output Format
```

---

## Step 11: Assume the Production Role

### Windows CMD

```cmd
aws sts assume-role ^
--role-arn arn:aws:iam::222222222222:role/CrossAccountReadRole ^
--role-session-name analytics-session ^
--external-id SecureAnalyticsToken123
```

### PowerShell

```powershell
aws sts assume-role `
--role-arn arn:aws:iam::222222222222:role/CrossAccountReadRole `
--role-session-name analytics-session `
--external-id SecureAnalyticsToken123
```

The response will contain temporary credentials.

---

## Step 12: Export Temporary Credentials

### Windows CMD

```cmd
set AWS_ACCESS_KEY_ID=<TEMP_ACCESS_KEY>

set AWS_SECRET_ACCESS_KEY=<TEMP_SECRET_KEY>

set AWS_SESSION_TOKEN=<TEMP_SESSION_TOKEN>
```

### PowerShell

```powershell
$env:AWS_ACCESS_KEY_ID="<TEMP_ACCESS_KEY>"

$env:AWS_SECRET_ACCESS_KEY="<TEMP_SECRET_KEY>"

$env:AWS_SESSION_TOKEN="<TEMP_SESSION_TOKEN>"
```

---

## Step 13: Verify Current Identity

```bash
aws sts get-caller-identity
```

Expected output:

```text
arn:aws:sts::222222222222:assumed-role/CrossAccountReadRole/analytics-session
```

This confirms the role has been assumed successfully.

---

## Step 14: List Bucket Contents

```bash
aws s3 ls s3://prod-sensitive-data-jb-1
```

Expected:

```text
Day1 TakeAway.txt
```

or any uploaded objects.

---

## Step 15: Download an Object

```bash
aws s3 cp "s3://prod-sensitive-data-jb-1/Day1 TakeAway.txt" .
```

Expected:

```text
download: s3://prod-sensitive-data-jb-1/Day1 TakeAway.txt
```

---

## Step 16: Verify Write Access Is Denied

Attempt:

```bash
aws s3 cp test.txt s3://prod-sensitive-data-jb-1/
```

Expected result:

```text
AccessDenied
```

This confirms least-privilege enforcement.

---

# Understanding the External ID

## What Problem Does It Solve?

The External ID protects against the **Confused Deputy Problem**.

Without an External ID:

```text
Any principal in the trusted account with AssumeRole permission
could potentially assume the role.
```

With an External ID:

```text
The caller must know a unique shared secret
before AWS allows role assumption.
```

This is especially important when granting access to third-party vendors and SaaS platforms.

---

# Common Troubleshooting Scenarios

## AccessDenied During AssumeRole

Possible causes:

* Incorrect External ID
* Missing sts:AssumeRole permission
* Incorrect trust policy
* SCP restriction

---

## AccessDenied on S3 Bucket Listing

Possible causes:

* Missing s3:ListBucket permission
* Incorrect bucket ARN
* Explicit deny in bucket policy

---

## AccessDenied on GetObject

Possible causes:

* Missing s3:GetObject permission
* Incorrect object ARN

---

## KMS Access Denied

If bucket encryption uses SSE-KMS:

```text
Additional KMS permissions are required.
```

Example:

```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "*"
}
```

The KMS key policy must also trust the role.

---

# Enterprise Use Cases

This exact architecture is commonly used by:

* Snowflake
* Databricks
* Splunk
* SIEM Platforms
* Centralized Logging Accounts
* Data Lake Architectures
* ETL Pipelines
* Security Monitoring Platforms
* Third-Party SaaS Integrations

---

# Key Takeaways

* Cross-account access should use IAM roles rather than IAM users.
* STS provides temporary credentials that automatically expire.
* External IDs help prevent Confused Deputy attacks.
* Least privilege should always be enforced.
* Production data can remain isolated while still being securely accessible.
* This design pattern is widely adopted across enterprise AWS environments.
