# Enterprise-Grade AWS IAM Self-Learning & Hands-On Lab Guide
### 📖 Comprehensive Walkthrough, Operational Best Practices, & Advanced Practical Scenarios

This guide serves as a comprehensive hands-on workbook for mastering AWS Identity and Access Management (IAM). It is structured specifically for personal learning accounts to build enterprise-level security habits without introducing unnecessary operational overhead. It covers foundational security protocols, policy evaluation logic, conditional access keys, and complex multi-layer security tasks.

---

## 📘 SECTION 1: Personal AWS Learning Account Security Setup

### Phase 1: Securing the Root Account (Steps 1 & 2)

```
                       ┌────────────────────────────────────────┐
                       │       AWS ROOT ACCOUNT (Emergency)     │
                       │  - Hardened Password & Hardware MFA    │
                       │  - Alternate Contacts & Budgets Active │
                       └───────────────────┬────────────────────┘
                                           │
                                           │ Log Out & Lock Away
                                           ▼
                       ┌────────────────────────────────────────┐
                       │     DAILY WORKLOAD ADMINISTRATION      │
                       │  - AWS IAM Identity Center (SSO)       │
                       │  - Temporary Command Line Sessions     │
                       └────────────────────────────────────────┘
```

#### Step 1 — Enable Multi-Factor Authentication (MFA) on Root
* **Action:** Log into the AWS Console as the root user. Navigate to **IAM** -> **My Security Credentials** -> **Assign MFA device**. Choose an Authenticator App (or physical hardware token like a YubiKey) and complete the configuration. Set a strong, unique 32+ character password and store it in a secure password manager.
* **Action (Alternate Contacts):** Navigate to **Billing and Cost Management** -> **Account Settings**. Populate the **Alternate Contacts** fields for Billing, Operations, and Security.
* **Action (Billing Alerts):** Navigate to **AWS Budgets** -> **Create budget** -> **Zero Spend Budget** (or monthly limit of $5.00). Configure email alerts to trigger when actual or forecasted spend exceeds 80% of the budget.

> [!NOTE]
> **🔍 What is Happening:** We are establishing multiple layers of administrative defense on the root billing and account entity, setting billing alerts, and assigning alternate operations contacts.
> 
> **💡 Why it is Happening:** The Root User has absolute, unblockable authority over all resources, data, and billing streams in the account. Compromise of the root account is catastrophic. Alternate contacts ensure AWS communications bypass a single email inbox, and budgets prevent "bill shock" if you accidentally launch expensive instances (like GPU nodes) during learning labs.
> 
> **⚡ If you do this (Consequences):**
> 1. The root user is secured behind multi-factor challenges.
> 2. You receive immediate emails if cost thresholds are exceeded, preventing massive bills.
> 3. AWS security notices are directed to dedicated, active communication channels.
> 
> **🧠 Deep Tech Explanation (Root User Bypass):**
> Unlike IAM users, the root user's permissions **cannot be restricted by IAM policies, Service Control Policies (SCPs), or boundaries**. The only way to secure the root user is to lock it behind MFA and physically isolate it, reserving it strictly for emergency tasks (e.g., changing support plans, closing the account, or recovering lost administrator MFA tokens).

---

### Phase 2: Administrative Strategy — IAM User vs. AWS IAM Identity Center (Step 3)

```
        ┌────────────────────────────────────────────────────────┐
        │                 CHOOSE YOUR ADMIN PATH                 │
        ├────────────────────────────┬───────────────────────────┤
        │  OPTION A: IAM USER        │  OPTION B: IDENTITY CENTER│
        │  - Quick & Direct          │  - SSO Permission Sets    │
        │  - Simpler for basic labs  │  - No permanent API Keys  │
        │  - Static Access Keys      │  - Realistic Enterprise    │
        └────────────────────────────┴───────────────────────────┘
```

#### Option A: IAM User (Simple & Direct Setup)
1. In the IAM Console, click **Users** -> **Create user**.
2. Name the user `Admin-Learner`. Check **Provide user access to the AWS Management Console**.
3. Under Permissions, select **Attach policies directly** -> Check **AdministratorAccess** (Temporarily).
4. Require MFA enrollment on this user immediately upon first login.

#### Option B: AWS IAM Identity Center (Recommended Enterprise Setup)
1. Search for **AWS IAM Identity Center** in the console and click **Enable**.
2. Navigate to **Multi-account permissions** -> **Permission sets** -> **Create permission set**. Select **Predefined permission set** -> **AdministratorAccess**.
3. Click **Users** -> **Add user**. Set username `sso-admin-learner` and configure their email.
4. Assign this user to your AWS Account and link them to the Admin permission set.

> [!NOTE]
> **🔍 What is Happening:** We are establishing our primary administrative identity, choosing either a legacy static IAM User (Option A) or a modern single sign-on Identity Center permission set (Option B).
> 
> **💡 Why it is Happening:** Daily administrative tasks should never be executed via the root account. Option B represents modern cloud best practices. It avoids static security credentials and mimics the Single Sign-On (SSO) architectures used in enterprise environments.
> 
> **⚡ If you do this (Consequences):** You log out of the root user and use your new admin identity for daily configurations. Option B generates temporary, short-lived session tokens for CLI and Console usage instead of permanent access keys.

---

### Phase 3: The Danger of Long-Term Keys & Modern Access Mechanics (Step 4)

```
       ❌ DANGEROUS STATIC PRACTICE             ✅ SECURE DYNAMIC PRACTICE
 ┌──────────────────────────────────────┐  ┌──────────────────────────────────────┐
 │  ~/.aws/credentials                  │  │  aws sso login                       │
 │  [default]                           │  │  - Calls AWS STS API                 │
 │  aws_access_key_id = AKIAXXXXXXXXX   │  │  - Generates 1-Hour Session Token    │
 │  aws_secret_access_key = wJalrXUtn...│  │  - Automatically Rotated Credentials  │
 └──────────────────────────────────────┘  └──────────────────────────────────────┘
```

> [!CAUTION]
> **🔍 What is Happening:** We are eliminating long-term, hardcoded programmatic access keys (`AKIA...`) from our local computers and transition to secure session alternatives.
> 
> **💡 Why it is Happening:** Hardcoded access keys are the #1 cause of cloud data breaches and billing exploits. If you accidentally push an access key to a public GitHub repository, automated crawlers will steal it within seconds, spin up dozens of crypto-mining instances, and saddle your account with tens of thousands of dollars in debt.
> 
> **⚡ If you do this (Consequences):** You delete static keys and instead authenticate via **AWS CloudShell** directly in the browser, or execute `aws sso login` to generate 1-hour temporary tokens for your local terminal.
> 
> **🧠 Deep Tech Explanation (Temporary Credentials):**
> Modern access utilizes the **AWS Security Token Service (STS)**. When authenticating via SSO or assuming roles, STS returns a packet containing three strings:
> 1. `AccessKeyId` (starts with `ASIA` to indicate temporary credentials).
> 2. `SecretAccessKey`.
> 3. `SessionToken` (a cryptographic proof of authentication).
> These credentials expire automatically after a set duration (default: 1 hour) and become completely useless to an attacker once expired.

---

## 📘 SECTION 2: Experiential Roles & STS Mechanics (Step 5 & 10)

To learn IAM deeply, you must write custom roles and policy documents. Below are five standard roles you should build to study access control.

```
       TRUST POLICY (Who can assume it?)      IDENTITY POLICY (What can they do?)
┌──────────────────────────────────────┐      ┌──────────────────────────────────────┐
│  "Principal": {                      │      │  "Action": [                         │
│    "Service": "ec2.amazonaws.com"    ├─────►│    "s3:GetObject",                   │
│  }                                   │      │    "s3:ListBucket"                   │
│  Allows EC2 to assume this role.     │      │  ] Allows reading S3 data.           │
└──────────────────────────────────────┘      └──────────────────────────────────────┘
```

### 1. `EC2-S3-ReadOnly-Role`
* **Trust Policy (Allows EC2 to assume this role):**
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  ```
* **Permissions Policy (`AmazonS3ReadOnlyAccess`):**
  Allows listing buckets and reading objects, but blocks all writes or deletions.

### 2. `Lambda-DynamoDB-Role`
* **Trust Policy:** Service Principal is `lambda.amazonaws.com`.
* **Permissions Policy:** Allows `dynamodb:GetItem`, `dynamodb:PutItem`, and `dynamodb:UpdateItem` on a specific database table ARN.

### 3. `Terraform-Deployment-Role`
* **Trust Policy:** Trusted Entity is your specific IAM Admin User ARN or your OIDC Github Actions provider.
* **Permissions Policy:** Broad permissions over VPC, EC2, and RDS, but blocks access to IAM role creation unless restricted by permissions boundaries.

### 4. `CrossAccountAuditRole`
* **Trust Policy (Allows external accounts to access this role):**
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::ANALYTICS_ACCOUNT_ID:root"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "SecureAuditToken987"
          }
        }
      }
    ]
  }
  ```

### 5. `BreakGlassAdminRole`
* **Trust Policy:** Trusted Entity is your primary Administrator ARN, requiring active MFA.
* **Permissions Policy:** `AdministratorAccess` containing a tight session duration limit (e.g. 1 hour).

> [!WARNING]
> **🧠 Deep Tech Explanation (The privilege Escalation Danger of `iam:PassRole`):**
> A common security mistake is granting a developer both `ec2:RunInstances` and `iam:PassRole` over all roles (`Resource: "*"`). If a developer has these permissions, they can launch a new EC2 instance, "pass" the highly privileged `BreakGlassAdminRole` to that instance's profile, SSH into the new instance, and execute commands with full admin access, completely bypassing their original restrictive developer policies.

---

## 📘 SECTION 3: Deep-Dive Policy Evaluation Logic & Conditions (Step 6, 9, 12, 14)

```
                              ┌──────────────────────────┐
                              │     REQUEST INITIATED    │
                              └────────────┬─────────────┘
                                           ▼
                              ┌──────────────────────────┐
                              │  Is there an EXPLICIT   │ ─── YES ───► [ ACCESS DENIED ]
                              │          DENY?           │
                              └────────────┬─────────────┘
                                           ▼ NO
                              ┌──────────────────────────┐
                              │  Is there an Identity    │
                              │     or Resource ALLOW?   │ ─── NO ────► [ ACCESS DENIED ]
                              └────────────┬─────────────┘
                                           ▼ YES
                              ┌──────────────────────────┐
                              │ Does boundary or SCP     │
                              │       restrict it?       │ ─── YES ───► [ ACCESS DENIED ]
                              └────────────┬─────────────┘
                                           ▼ NO
                                    [ ACCESS ALLOWED ]
```

### 1. The Policy Evaluation Hierarchy
AWS evaluates policies deterministically using a series of logical gates:
1. **Default Deny:** By default, all requests are denied.
2. **Explicit Deny Precedence:** If *any* policy (SCP, Resource Policy, Permissions Boundary, or Identity Policy) contains an explicit `"Effect": "Deny"`, the request is **immediately denied**, overriding all allows.
3. **Identity + Resource Union:** The request is allowed if an identity policy **or** a resource policy allows the action (for resources in the same account). If the resource has an explicit resource policy, it must allow the action.
4. **Permissions Boundary Intersect:** If a permissions boundary is active, the requested action must be allowed by **both** the identity policy and the permissions boundary.
5. **Service Control Policy (SCP) Intersect:** In AWS Organizations, the request must be allowed by both the account-level policies and the parent Organization SCPs.
