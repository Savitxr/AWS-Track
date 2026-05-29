## 📘 SECTION: Advanced Hands-On Lab Tasks

The following hands-on labs represent real-world enterprise architectures and security scenarios. They are attributed to specific educational tracks to form a comprehensive IAM training syllabus.

---

### 🛠️ TASK 1 — IAM Policy Variables and Dynamic Referencing for User-Scoped Access (Track: Pruthvi Bhat)

#### 🔍 What is Happening:
We are configuring dynamic, identity-based resource isolation inside a shared AWS S3 bucket named `shared-corporate-home-dirs`. Instead of creating separate IAM policies for every single developer, we deploy a single IAM policy that uses the runtime variable `${aws:username}` to lock users into their own folders.

```
       S3 SHARED BUCKET: s3://shared-corporate-home-dirs/
┌────────────────────────────────────────────────────────┐
│  /alice/*  ◄──── Accessible only by Alice              │
│  /bob/*    ◄──── Accessible only by Bob                │
│  /charlie/*◄──── Accessible only by Charlie            │
└────────────────────────────────────────────────────────┘
```

#### 💡 Why it is Happening:
In large enterprises, writing and maintaining separate security policies for hundreds of individual users is operationally impossible. IAM Policy Variables allow you to construct a single, generic blueprint policy. When a user makes an API call, AWS automatically evaluates their active username at runtime and substitutes it into the resource path.

#### ⚡ If you do this (Consequences):
Every engineer gains a private "home directory" folder inside S3. If user `alice` attempts to read an object in the path `/bob/sensitive.txt`, AWS evaluates the policy, resolves `s3:::shared-corporate-home-dirs/alice/*`, finds no match for `/bob/`, and returns an explicit `Access Denied`.

#### 🔧 How to Implement:
1. Create a shared S3 bucket named `shared-corporate-home-dirs`.
2. Attach this IAM Policy to your developer group or SSO permission set:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListSharedBucketRoot",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::shared-corporate-home-dirs"],
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "",
            "${aws:username}/*"
          ]
        }
      }
    },
    {
      "Sid": "UserHomeDirectoryAccessOnly",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::shared-corporate-home-dirs/${aws:username}/*"
      ]
    }
  ]
}
```

---

### 🛠️ TASK 2 — AWS IAM Service Role Demo using Lambda (Track: Nandana Suresh)

#### 🔍 What is Happening:
We are creating an IAM Service Role named `Lambda-ServiceRole-Demo` containing a trust policy that permits the AWS Lambda service to assume it. We attach basic execution permissions and link this role to a Python-based Lambda function to verify CloudWatch logging and dynamic STS credential usage.

#### 💡 Why it is Happening:
AWS services do not inherently have permission to access other regional services. To write logs to CloudWatch or read from databases, a service must assume an **execution role** created by you, which allows it to act on your behalf securely.

#### ⚡ If you do this (Consequences):
When the Lambda function is invoked, the underlying Lambda container contacts the AWS Security Token Service (STS), assumes the `Lambda-ServiceRole-Demo` role, receives temporary credentials starting with `ASIA...`, and uses them to write logs. No static API access keys are ever generated.

#### 🔧 How to Implement:
1. Create an IAM Role named `Lambda-ServiceRole-Demo` with the following **Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```
2. Attach the AWS-managed policy `AWSLambdaBasicExecutionRole` directly to this role (grants permission to write streams to Amazon CloudWatch Logs).
3. Create a Python 3.9 Lambda function named `service-role-demo` and bind it to this IAM Role.
4. Deploy the following Python code to print and verify the dynamic STS tokens:
```python
import json
import os

def lambda_handler(event, context):
    # Retrieve the dynamic access key assigned to the container by STS
    aws_access_key = os.environ.get('AWS_ACCESS_KEY_ID', 'Not Found')
    print(f"Executing Lambda with temporary STS credential ID: {aws_access_key[:8]}...")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Successfully executed using dynamic service role!',
            'sts_key_prefix': aws_access_key[:8]
        })
    }
```
5. Test the function and open **CloudWatch Logs** to verify the logged `ASIA` temporary credentials.

---

### 🛠️ TASK 3 — IAM Condition-Based Access Control (S3 + MFA Enforcement) (Track: Nandana Suresh)

#### 🔍 What is Happening:
We are designing a custom IAM policy for a highly sensitive S3 bucket named `prod-classified-vault` that denies any read or list requests unless the user has actively authenticated their session using Multi-Factor Authentication (MFA).

#### 💡 Why it is Happening:
Standard username/password credentials are vulnerable to local session hijacking and phishing. Enforcing MFA validation directly at the IAM policy level ensures that even if an attacker steals an active command-line session token, they cannot access sensitive database backups without completing a fresh physical MFA challenge.

#### ⚡ If you do this (Consequences):
An IAM user with full S3 administrative rights will receive an `Access Denied` error when listing the bucket contents if they did not log in using MFA. Once MFA is entered, the session context variable `aws:MultiFactorAuthPresent` flips to `true`, and access is immediately unlocked.

#### 🔧 How to Implement:
1. Create a private S3 bucket named `prod-classified-vault`.
2. Attach the following custom IAM Policy directly to your target learning user:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3OnlyWithActiveMFA",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::prod-classified-vault",
        "arn:aws:s3:::prod-classified-vault/*"
      ],
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```
3. Test S3 list commands via the CLI with standard credentials to verify the denial, then configure MFA, retrieve temporary MFA-assumed tokens via `aws sts get-session-token`, and successfully list the bucket.

---

### 🛠️ TASK 4 — Temporary Privileged Emergency Access Architecture (Track: Kajapathy Kandhasamy)

#### 🔍 What is Happening:
We are implementing a secure "Break-Glass" temporary privileged access framework using AWS STS and IAM Roles. Rather than granting permanent `AdministratorAccess` to engineers, they normally operate with limited read-only permissions and assume the role `EmergencyAdminRole` only during active operational incidents.

```
       NORMAL OPERATIONS                       ACTIVE INCIDENT (BREAK-GLASS)
┌──────────────────────────────┐               ┌──────────────────────────────┐
│  Developer IAM User          │  sts:Assume   │  EmergencyAdminRole          │
│  - ReadOnlyAccess Only       ├──────────────►│  - Full AdministratorAccess  │
│  - No write or delete rights │  1-Hour Max   │  - Auto-expires session      │
└──────────────────────────────┘               └──────────────────────────────┘
```

#### 💡 Why it is Happening:
Maintaining permanent high-privilege credentials violates the core Principle of Least Privilege and increases the blast radius of any identity compromise. Forcing users to explicitly request and "assume" a role ensures that administrative power is only wielded when absolutely necessary.

#### ⚡ If you do this (Consequences):
Administrative permissions are bounded to a maximum of 1 hour. Every action taken is logged in CloudTrail under the assumed role session name, making incident audits transparent.

#### 🔧 How to Implement:
1. Create an IAM Role named `EmergencyAdminRole` with a **Session Duration** set to `3600` seconds (1 hour).
2. Attach the AWS-managed policy `AdministratorAccess` directly to this role.
3. Configure the **Trust Policy** to restrict who can assume it, enforcing active MFA:
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
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

---

### 🛠️ TASK 5 — Hardened Security Controls for Temporary Privileged Access (Track: Kajapathy Kandhasamy)

#### 🔍 What is Happening:
We are hardening the `EmergencyAdminRole` from Task 4 by adding multi-factor authentication (MFA) enforcement and strict IP-based conditional access locks (`aws:SourceIp`) targeting approved corporate office IP ranges.

#### 💡 Why it is Happening:
Emergency admin roles hold the keys to your entire cloud kingdom. They must be heavily protected. Restricting the source IP addresses prevents an attacker who has stolen the role session tokens from utilizing them from outside the company's approved network boundary.

#### ⚡ If you do this (Consequences):
Even if an engineer's STS session token is leaked, any API requests initiated from an unauthorized IP address (like a public café or home network) are blocked by the policy engine.

#### 🔧 How to Implement:
Modify the permissions policy of `EmergencyAdminRole` to wrap all actions under a global condition block:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "HardenedMfaAndIpEgressAdmin",
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["192.0.2.0/24"]
        },
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```
*(Replace `192.0.2.0/24` with your active corporate VPN or network gateway IP address block).*

---

### 🛠️ TASK 6 — Secure 3-Tier EC2 Identity Architecture (Track: Pavithra)

#### 🔍 What is Happening:
We are designing a secure, credential-less identity framework that allows an application running on an EC2 instance to safely write to an S3 bucket (`app-data-storage`), write state values to DynamoDB, and retrieve passwords from Secrets Manager using IAM roles and conditional transit policies.

```
┌────────────────────────────────────────────────────────────────────────┐
│  EC2 APP SERVER                                                        │
│  - Assumes IAM Instance Profile Role                                   │
│  - No static keys on disk                                              │
├────────────────────────────────────────────────────────────────────────┤
│                          SECURITY CONTROLS:                            │
│  - Enforce Transit TLS (aws:SecureTransport)                          │
│  - KMS decryption locked to local account                             │
└────────────────────────────────────────────────────────────────────────┘
```

#### 💡 Why it is Happening:
Embedding database passwords or AWS credentials inside source code files is a major security risk. Using **EC2 Instance Profiles** allows the virtual server to request temporary, rotating STS credentials automatically. Enforcing TLS transit protection (`aws:SecureTransport`) prevents man-in-the-middle data interception.

#### ⚡ If you do this (Consequences):
No static secrets exist on the server's disk. If the server is compromised, the temporary credentials expire quickly, and access is tightly restricted to the specific S3, DynamoDB, and Secrets Manager resources declared in the policy.

#### 🔧 How to Implement:
1. Create an IAM Role named `EC2-3Tier-Application-Role` with a trust policy allowing `ec2.amazonaws.com` to assume it.
2. Attach the following custom policy to the role, enforcing TLS transit and resource boundaries:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecureS3ReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::app-data-storage/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "AllowDynamoDBAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/app-state-table"
    },
    {
      "Sid": "AllowSecretsManagerRead",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:*:*:secret:prod-db-creds-*"
    }
  ]
}
```
3. Attach this role to your EC2 instance via the instance profile settings and test access.

---

### 🛠️ TASK 7 — Cross-Account Data Access Role (Track: Jayabaaskar Baskaran)

#### 🔍 What is Happening:
We are configuring a secure pathway that allows an IAM role running inside a separate **Analytics Account** (`222222222222`) to read objects from a private, encrypted S3 bucket located inside our **Production Account** (`111111111111`).

#### 💡 Why it is Happening:
In professional environments, data is separated into isolated accounts. The analytics engine must read raw production data to generate reports, but it should not have administrative or write access to the production environment, nor should it use static credentials.

#### ⚡ If you do this (Consequences):
An external system can securely assume a local role in the production account to access S3 data. This access is protected by a unique external ID to prevent the **Confused Deputy** vulnerability, and the session token expires automatically after 1 hour.

#### 🔧 How to Implement:

##### 1. Production Account Configuration (`111111111111`)
Create an IAM Role named `CrossAccountReadRole` with the following configuration:
* **Trust Policy (Allows the Analytics Account to assume this role with an External ID):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:root"
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
* **Permissions Policy (Grants read-only access to our specific S3 bucket):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::prod-sensitive-data"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::prod-sensitive-data/*"
    }
  ]
}
```

##### 2. Analytics Account Configuration (`222222222222`)
Attach this policy to the analytics user or compute engine running in the Analytics account:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::111111111111:role/CrossAccountReadRole"
    }
  ]
}
```

---

### 🛠️ TASK 8 — Multi-Layer Deny Conflict (SCP + Permission Boundary + IAM) (Track: Jayabaaskar Baskaran)

#### 🔍 What is Happening:
We are debugging a scenario where an administrator named `Dev-Admin` is attempting to create a new DynamoDB database table but receives an `Access Denied` error, even though their IAM user has `AdministratorAccess` attached.

```
       ORGANIZATION SCP                  PERMISSIONS BOUNDARY                  USER IAM POLICY
┌──────────────────────────────┐   ┌──────────────────────────────┐   ┌──────────────────────────────┐
│  Allows: *                   │   │  Allows: S3, EC2, DynamoDB   │   │  Allows: AdministratorAccess │
│  Denies: DynamoDB Delete     │   │  Denies: IAM Changes         │   │                              │
└──────────────┬───────────────┘   └──────────────┬───────────────┘   └──────────────┬───────────────┘
               │                                  │                                  │
               └──────────────────────────────────┼──────────────────────────────────┘
                                                  ▼
                                       Logical Intersection (AND)
                                                  ▼
                                       Only S3 & EC2 Allowed.
                                     DynamoDB is BLOCKED!
```

#### 💡 Why it is Happening:
This issue is caused by the interaction between three separate security layers: the Organization **Service Control Policy (SCP)**, a local **Permissions Boundary**, and the identity's **IAM Policy**. AWS evaluates the intersection (logical AND) of these layers, so the most restrictive policy always wins.

#### 🔧 The Conflict Resolution:
1. Identify the Core Conflict: The Permissions Boundary lacks `dynamodb:*` permissions, acting as a functional ceiling.
2. How to Fix the Issue:
   - Step 1: Remove the explicit deny blocking `dynamodb:CreateTable` from the Organization SCP.
   - Step 2: Edit the Permissions Boundary policy to add `dynamodb:*` to its allowed actions list:
```json
     "Action": [
       "s3:*",
       "ec2:*",
       "rds:*",
       "dynamodb:*"
     ]
```

---

### 🛠️ TASK 9 — Enterprise ABAC with Tag Enforcement & Conditional Access (Track: Jayabaaskar Baskaran)

#### 🔍 What is Happening:
We are building an **Attribute-Based Access Control (ABAC)** system that dynamically controls access based on resource and user tags. Users are only allowed to manage EC2 instances if the user's `Team` tag matches the EC2 instance's `Team` tag. Additionally, users are prevented from launching new instances unless they tag them correctly during creation.

```
       USER: sso-admin-learner                 EC2 INSTANCE: WebServer-Prod
 ┌──────────────────────────────────┐        ┌──────────────────────────────────┐
 │  Tag Key: Team                   │        │  Tag Key: Team                   │
 │  Tag Value: billing              │        │  Tag Value: billing              │
 └────────────────┬─────────────────┘        └────────────────┬─────────────────┘
                  │                                           │
                  └───────────────────────┬───────────────────┘
                                          ▼
                               Are the values identical?
                                         (YES)
                                   [ ACCESS ALLOWED ]
```

#### ⚡ If you do this (Consequences):
You enforce clean tagging governance across the account. Users cannot spin up untagged or orphaned instances (which inflate costs), and access permissions are managed dynamically without updating your IAM policies.

#### 🔧 How to Implement (Step-by-Step configurations):

##### 1. Implement the Enforced Tagging & ABAC Policy
Attach this policy to your primary development role or group:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadAndListAll",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Get*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EnforceTaggingOnCreation",
      "Effect": "Allow",
      "Action": "ec2:RunInstances",
      "Resource": [
        "arn:aws:ec2:*:*:instance/*",
        "arn:aws:ec2:*:*:volume/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestTag/Team": "${aws:PrincipalTag/Team}"
        },
        "Null": {
          "aws:RequestTag/Team": "false"
        }
      }
    },
    {
      "Sid": "DynamicABACAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Team": "${aws:PrincipalTag/Team}"
        }
      }
    }
  ]
}
```

##### 2. How to Test & Verify:
1. Assign the tag `Team` = `billing` to your IAM user or assumed role.
2. Attempt to stop an EC2 instance that has the tag `Team` = `finance`. The request will fail with an `Access Denied` error.
3. Attempt to stop an EC2 instance tagged with `Team` = `billing`. The action will succeed immediately because the tags match (`aws:ResourceTag/Team` == `aws:PrincipalTag/Team`).
4. Attempt to launch a new EC2 instance without assigning a `Team` tag. The action will be blocked by the `EnforceTaggingOnCreation` policy statement.

---

### 🛠️ TASK 10 — Policy Evaluation Conflict (Allow vs Explicit Deny on EC2 Actions) (Track: Aswin Sathees)

#### 🔍 What is Happening:
We are analyzing and resolving a policy evaluation conflict where a local developer user possesses an IAM policy granting them `ec2:StartInstances` permissions, but they are blocked by a parent Organization **Service Control Policy (SCP)** containing an explicit deny over EC2 controls for all accounts except designated administrators.

```
       ORGANIZATION SCP (Parent Gate)                DEVELOPER IAM POLICY (Identity)
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│  Deny: ec2:StartInstances            │        │  Allow: ec2:StartInstances           │
│  Unless: Resource has Tag Sandbox   │        │  Resource: *                         │
└──────────────────┬───────────────────┘        └──────────────────┬───────────────────┘
                   │                                               │
                   └───────────────────────┬───────────────────────┘
                                           ▼
                                   Resulting access:
                           Allows starting ONLY Sandbox nodes.
                           Production nodes are DENIED!
```

#### 💡 Why it is Happening:
Organization SCPs establish absolute boundaries. An explicit deny in an SCP overrides any local identity permissions completely. To grant developers flexibility without violating root organization-level protections, the SCP should be restructured to implement tag-based exceptions (e.g. allowing developers to start instances only if the target resource has the tag `Environment = Sandbox`).

#### ⚡ If you do this (Consequences):
Engineers can successfully test and manage resource states in development/sandbox environments, while critical production or un-tagged systems remain protected by the organization-wide explicit deny.

#### 🔧 How to Implement:
1. In your AWS Organizations Management Account, attach the following **Service Control Policy (SCP)** to the member accounts:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyStartUnlessSandboxNode",
      "Effect": "Deny",
      "Action": "ec2:StartInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "aws:ResourceTag/Environment": "Sandbox"
        }
      }
    }
  ]
}
```
2. Test by attempting to start an EC2 instance that lacks the tag `Environment` = `Sandbox`. It will fail with an explicit `Access Denied` organization error. Assign the tag and verify that starting the instance is successfully allowed.

---

### 🛠️ TASK 11 — Developer Time-Bound Temporary Write Access (Track: Aswin Sathees)

#### 🔍 What is Happening:
We are designing a self-assumed debugging role (`Prod-Debug-Write-Role`) that temporarily elevates a developer's read-only access to time-bound write permissions on production resources during a troubleshooting session, ensuring all changes are audited in CloudTrail and automatically expire.

#### 💡 Why it is Happening:
Developers sometimes need temporary write permissions to production databases or applications to troubleshoot active bugs. Granting permanent write permissions to human users is a high security risk. Using **STS session duration conditions** ensures that the write access is tightly bounded and automatically revoked when the session timer expires.

#### ⚡ If you do this (Consequences):
The assumed session token is locked to a maximum duration of 2 hours. The developer can fix the issue and the role expires automatically, eliminating "forgotten elevated access" security risks.

#### 🔧 How to Implement:
1. Create an IAM Role named `Prod-Debug-Write-Role` containing a trust policy that requires MFA and enforces a session duration maximum of 7200 seconds (2 hours):
* **Trust Policy**:
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
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        },
        "NumericLessThanEquals": {
          "sts:DurationSeconds": 7200
        }
      }
    }
  ]
}
```
2. Attach permissions permitting write/put operations on specific production tables or objects.
3. Developers invoke this role via the CLI using a session token request:
```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::111111111111:role/Prod-Debug-Write-Role" \
  --role-session-name "IncidentTroubleshootSession" \
  --duration-seconds 7200
```
4. Verify the assumed role's session activity inside the centralized **AWS CloudTrail** logs.
