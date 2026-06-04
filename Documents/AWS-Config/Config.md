# AWS Config: Cloud Governance & Automated Remediation
### 📖 Comprehensive Governance Framework, Systems Manager Integration, & Real-World Scenarios

This guide serves as an engineering manual and self-learning workbook for AWS Config and AWS Systems Manager (SSM). It establishes the operational mindset required to manage cloud environments at scale, detailing how to turn on configuration recording, define policy rules, audit changes, and execute automated remediations.

---

## 🧠 AWS Config Mindset: The "Vacation" Scenario

To understand why AWS Config is vital, consider this operational scenario:

> *An administrator goes on a one-week vacation. While they are away, a developer needs to quickly debug a connection issue on an internal database instance. To solve it, they edit the instance's Security Group to temporarily open Port 22 (SSH) and Port 5432 (PostgreSQL) to the entire public internet (`0.0.0.0/0`). They resolve the issue but forget to delete the temporary ingress rules.*
> 
> *When the administrator returns, they face several critical operational questions:*
> 1. *How do they know that a security rule was changed?*
> 2. *Who initiated the change and at what exact timestamp?*
> 3. *What did the security group configuration look like before the modification?*
> 4. *Which EC2 instances and databases are now vulnerable because of this specific change?*
> 5. *How can they immediately revert this open security group back to a locked state automatically?*

AWS Config resolves this by acting as a continuous flight data recorder for your AWS resource configurations, pairing with Systems Manager to execute automated, self-healing repairs.

---

## 📘 PART 1 — INITIAL SETUP: ENABLING AWS CONFIG

If AWS Config has never been enabled in your account, you must initialize the recording engine. This creates the background recording system (the "Flight Recorder") and sets up where storage snapshots are saved.

### Step-by-Step Console Walkthrough

```
          1. CONFIG RECORDER             2. CONFIGURATION TIMELINE          3. S3 AUDIT VAULT
┌────────────────────────────────────┐ ┌───────────────────────────┐ ┌─────────────────────────────┐
│  Continuous API Poller & Logger    ├─►  Generates JSON snapshots ├─►  Saves audit trails for      │
│  - Captures CRUD resource changes │ │  of state at change times │ │  historical security audits │
└────────────────────────────────────┘ └───────────────────────────┘ └─────────────────────────────┘
```

#### 1. Turn on the Configuration Recorder
*   **What is Happening:** We are activating the background recording process (the configuration recorder). Once active, it monitors the AWS control plane, logging any API calls that create, update, or delete resources.
*   **What you are Changing/Doing:** In the AWS Config Console, click **Get Started**. Under **Settings**, select **Record all resources supported in this region** (or choose specific resource types to save costs) and create a new S3 bucket to act as your configuration history repository.
*   **Consequence:** AWS Config begins compiling historical timelines of your infrastructure. This introduces recording costs (charged per Configuration Item recorded) and starts populating your compliance dashboards.

#### 2. Create the IAM Service Role
*   **What is Happening:** AWS Config needs permission to describe your resources (e.g., query S3 bucket properties or check EC2 instance states) and write these snapshots to your S3 history bucket.
*   **What you are Changing/Doing:** Choose **Create AWS Config service-linked role** (or select an existing IAM role with the `AWS_ConfigRole` managed policy attached).
*   **Consequence:** The platform gains read-only access to query configurations across your account, enabling it to catalog resource details securely.

#### 3. Define the S3 Bucket & SNS Notification Triggers
*   **What is Happening:** We are establishing a durable storage repository (S3) for our configuration files and setting up notification paths (SNS) to alert administrators when drifts occur.
*   **What you are Changing/Doing:** Provide an S3 bucket name (e.g., `config-bucket-logs-[account-id]`) and check the box to send configuration stream logs to a new or existing Amazon SNS topic.
*   **Consequence:** AWS Config will automatically drop a JSON configuration snapshot into S3 every time a resource is modified, and send live alerts via email or Slack (via SNS/Chatbot integration) when changes are detected.

---

## 📘 PART 2 — CORE ARCHITECTURE: "BRAIN VS. MUSCLE"

Effective cloud governance requires two distinct phases: **Detection** (identifying issues) and **Remediation** (fixing issues).

```
   AWS CONFIG (The Brain)                      AWS SYSTEMS MANAGER (The Muscle)
┌──────────────────────────────┐              ┌────────────────────────────────┐
│  - System of Record          │  Non-        │  - Task Execution Engine       │
│  - Tracks Historic Timelines ├─────────────►│  - Runs Operational Documents  │
│  - Audits State Compliance   │  Compliant   │  - Executes Auto-Remediations  │
└──────────────────────────────┘              └────────────────────────────────┘
```

### 1. AWS Config (The Brain)
*   **The System of Record:** Config continuously tracks the state of your infrastructure over time. It maintains a historical timeline of configurations, maps dependencies between resources, and evaluates changes against your compliance policies.
*   **Role:** It detects when a resource is configured incorrectly but **does not make changes to your resources directly**. It acts as the auditing and decision-making brain.

### 2. AWS Systems Manager (The Muscle)
*   **The Operational Engine:** Systems Manager (SSM) executes automation runbooks and run-commands across your AWS resources and virtual machines.
*   **Role:** When AWS Config flags a resource as non-compliant, Systems Manager acts as the execution force. It runs predefined Python/Bash automation documents to repair, lock down, or shut down resources to enforce your security baseline.

---

## 📘 PART 3 — ESSENTIAL TERMINOLOGY

| Term | Definition | Operational Relevance |
| :--- | :--- | :--- |
| **Configuration Item (CI)** | A JSON-formatted snapshot of a resource's metadata, attributes, and tags at a specific point in time. | The base unit of audit. If you change an EC2 instance size, Config generates a new CI showing the change. |
| **Recorder** | The underlying agent mechanism that detects regional API actions and translates them into CIs. | Must be turned on for Config to track changes. If disabled, history logging stops. |
| **Relationship Map** | A dependency graph generated by Config showing how resources are linked together. | Helps you trace blast radiuses (e.g., seeing which EC2 instances are attached to an open Security Group). |
| **Drift** | When the live configuration state of a resource deviates from your desired organizational policy. | Config rule dashboards flag drift by shifting status icons from green (Compliant) to red (Non-Compliant). |
| **Managed Rule** | Pre-built compliance templates provided by AWS to check for common security, cost, or operational issues. | Allows you to quickly deploy best practice checks (e.g., checking if all S3 buckets block public access) without writing custom code. |

---

## 📘 PART 4 — THE GOVERNANCE LOOP: TECHNICAL WORKFLOW

<img width="1536" height="1024" alt="aws-config-architecture" src="https://github.com/user-attachments/assets/92e1648c-aa8a-4f19-9e0b-a64de1d14e04" />


1.  **Trigger (The Change):** A configuration change occurs. For example, a developer disables the "Block Public Access" switch on a sensitive S3 bucket.
2.  **Detection (Recording):** The Configuration Recorder detects the API modification event, captures the new state, and generates a fresh Configuration Item (CI).
3.  **Evaluation (Audit):** AWS Config compares the generated JSON CI against your active Config rules. Because the S3 bucket is now public, Config flags the resource state as `NON_COMPLIANT`.
4.  **Remediation (The Fix):** AWS Config uses a dedicated IAM role to trigger an associated AWS Systems Manager (SSM) Automation Document (e.g., `AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock`).
5.  **Resolution:** The SSM Runbook executes the API call to re-enable "Block Public Access" on the S3 bucket. Config records this new configuration change, updates the bucket's status to `COMPLIANT`, and logs the recovery in the audit timeline.

---

## 📘 PART 5 — governance DEMO SCENARIOS

---

### DEMO 1 & 2 — Sizing Governance, Drift Timelines, & Relationship Mapping

#### Scenario:
An organization has a budget policy that restricts EC2 instances to the cost-efficient `t3.micro` instance type. A developer changes an instance size to `m5.large` to speed up a local test script, violating the baseline policy.

```
       1. POLICY VIOLATION                     2. CONFIG DETECTS COMPLIANCE DRIFT
┌───────────────────────────────┐              ┌────────────────────────────────┐
│  Developer changes size:      │   Config     │  - Timeline highlights diff    │
│  t3.micro ──► m5.large        ├─────────────►│  - Instance state = Red        │
│  (Triggers cost policy drift) │    Check     │  - Shows linked EBS volumes    │
└───────────────────────────────┘              └────────────────────────────────┘
```

#### Console Steps & Actions:
1.  **Simulate the Action:** In the EC2 Console, select your test instance (`t3.micro`), click **Instance state** -> **Stop**. Once stopped, select **Instance settings** -> **Change instance type** -> Select `m5.large` -> Click **Save**. Restart the instance.
2.  **Observe the Compliance Drift:** Open the **AWS Config Console** and navigate to **Rules**. Under your active `desired-instance-type` rule, the compliance status of your EC2 instance will refresh and flag the resource as **Non-compliant** (marked with a red status flag).
3.  **Audit the Timeline Diff (Forensics):**
    *   Click on the non-compliant EC2 instance resource ID in the Config console.
    *   Select **Resource Timeline**. This displays a chronological map of every API change made to the VM.
    *   Locate the newest change entry. It will show a **Changes** diff block highlighting:
        ```json
        - configuration.instanceType: "t3.micro"
        + configuration.instanceType: "m5.large"
        ```
4.  **Inspect the Relationship Map:** On the same timeline page, select **Relationship Map**. This displays an interactive node graph showing all EBS storage volumes, Network Interfaces (ENIs), EIPs, and Security Groups associated with the modified instance, letting you analyze the potential impact of the change.

---

### DEMO 3 — The Native Healer: Automated S3 Public Access Lock

#### Scenario:
An administrator wants to guarantee that no S3 bucket in the account can ever be exposed to the public internet. If someone attempts to disable the S3 public access block, AWS Config and Systems Manager must automatically detect and revert the change immediately.

<img width="1536" height="1024" alt="Demo3-config" src="https://github.com/user-attachments/assets/0183e767-323b-4364-9aea-b8886fbbecc1" />


#### Console Steps & Actions:
1.  **Configure the Managed Rule & Remediation:**
    *   In AWS Config, navigate to **Rules** -> **Add rule** -> Select `s3-bucket-level-public-access-prohibited` -> **Next** -> **Add rule**.
    *   Select the newly created rule -> Click **Actions** -> **Manage Remediation**.
    *   Choose **Automatic Remediation**.
    *   Under **Remediation action**, search for and select the SSM document: `AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock`.
    *   Under **Resource ID parameter**, select `BucketName`.
    *   Configure the **Parameters** section to set `RestrictPublicBuckets`, `BlockPublicAcls`, `IgnorePublicAcls`, and `BlockPublicPolicy` all to `true`.
    *   Under **Remediation Role**, provide the ARN of your SSM execution role that has permissions to write S3 public access settings. Save the settings.
2.  **Simulate the Attack/Accident:**
    *   Navigate to the **S3 Console**, select your test bucket, and click on the **Permissions** tab.
    *   Under **Block public access (bucket settings)**, click **Edit**.
    *   **Uncheck** "Block *all* public access" -> Click **Save changes** -> Type `confirm` to expose the bucket.
3.  **Verify the Self-Healing Fix:**
    *   Within 1-2 minutes, refresh the S3 Permissions console.
    *   You will see that the S3 "Block *all* public access" settings have automatically turned back on, and the bucket is locked down again.
    *   Navigate to the **Systems Manager Console** -> **Automation** -> **Execution history**. You will find an entry for the runbook showing a status of `Success`, verifying that the automated fix resolved the drift.

---

## 📘 PART 6 — BEST PRACTICES & LIMITATIONS

### 1. Cost Management & Selective Recording
AWS Config charges a fee for every Configuration Item (CI) recorded. If you leave the recorder turned on for all resource types, minor background updates (such as IAM policy updates or cloud security scans) can generate thousands of unnecessary CIs, inflating your monthly bill.
*   **Best Practice:** In non-production and personal learning accounts, configure the recorder to only track key structural resources (e.g., `AWS::EC2::Instance`, `AWS::S3::Bucket`, `AWS::EC2::SecurityGroup`, `AWS::RDS::DBInstance`) instead of recording all supported types.

### 2. Least Privilege for Remediation Roles
The IAM role that AWS Config assumes to trigger Systems Manager automation must have sufficient permissions to perform the required fix (e.g. modifying S3 buckets or stopping instances).
*   **Best Practice:** Never assign `AdministratorAccess` to your SSM remediation roles. If the role is compromised, an attacker could use it to gain administrative control of the account. Instead, limit the role to specific API actions on specific resources, such as:
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutBucketPublicAccessBlock"
          ],
          "Resource": "arn:aws:s3:::*"
        }
      ]
    }
    ```

### 3. Evaluation Latency & Live Testing
There is typically a **1 to 2 minute delay** between when an API change occurs and when the Configuration Recorder logs the CI, updates the dashboard, and triggers remediation. 

For fast-loop testing, you can use the AWS CLI to manually bypass this latency and force AWS Config to run an immediate compliance evaluation.

```bash
# Force AWS Config to evaluate your S3 public access rule immediately
aws configservice start-config-rules-evaluation \
  --config-rule-names s3-bucket-level-public-access-prohibited
```

