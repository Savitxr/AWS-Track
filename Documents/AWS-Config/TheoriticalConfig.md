# AWS Config: Governance & Remediation Theory
### 📖 Architectural Foundations of Change Tracking, Compliance Auditing, and Self-Healing Loops

This documentation details the theoretical mechanics and architectural patterns of AWS Config and AWS Systems Manager (SSM). It analyzes how AWS tracks resource states, evaluates compliance rules, and executes self-healing remediation routines to enforce governance policies at scale.

---

## 📘 PART 1 — CHANGE VISIBILITY & RESOURCE FORENSICS

### 1. The Scenario: Deleting a Production Ingress Rule
To understand the theory of change visibility, consider an active EC2 Security Group protecting a critical production MySQL database or HTTPS web server. A user deletes a rule allowing traffic on Port 3306 (MySQL) or Port 443 (HTTPS), which instantly breaks application connectivity. 

Instead of searching through millions of unrelated API logs in AWS CloudTrail, an administrator opens AWS Config to view the resource timeline, immediately identifying the exact change and its downstream dependencies.

```
       1. PRODUCTION OUTAGE                    2. TRADITIONAL TRACING (Hard)
┌───────────────────────────────┐              ┌───────────────────────────────┐
│ App loses DB connectivity     │ ────────────►│ Read millions of CloudTrail   │
│ Ingress Port 3306 deleted     │              │ JSON lines to find API calls  │
└───────────────────────────────┘              └───────────────────────────────┘
                                                       │
                                                       ▼
                                               3. AWS CONFIG TRACING (Easy)
                                               ┌───────────────────────────────┐
                                               │ View Security Group Timeline  │
                                               │ - Visual JSON Diff            │
                                               │ - Relationship Dependency Map │
                                               └───────────────────────────────┘
```

---

### 2. Theoretical Breakdown of Change Visibility

#### A. Configuration Item (CI)
The fundamental building block of AWS Config is the **Configuration Item (CI)**. A CI is a static, JSON-formatted representation of an AWS resource's state at a specific point in time. It is generated automatically when a change occurs.

A standard CI contains the following key components:
*   **Metadata:** Information about the resource (e.g., Resource ID, ARN, AWS Account ID, region, and creation time).
*   **Attributes:** The resource's configuration details (e.g., instance type, S3 permissions, or Security Group rules).
*   **Relationships:** A list of other resources linked to this one (e.g., an EBS volume attached to an EC2 instance, or an ENI associated with a Security Group).
*   **Configuration State:** The resource-specific configuration data mapped directly from describe API calls.

```
                        ┌────────────────────────────────────────┐
                        │      CONFIGURATION ITEM (CI) SCHEMA    │
                        ├────────────────────────────────────────┤
                        │  - Metadata (ARN, Region, Account ID)  │
                        │  - Attributes (Current state values)   │
                        │  - Relationships (Associated resources)│
                        │  - State Context (Active configurations)│
                        └────────────────────────────────────────┘
```

#### B. Resource Recording Process
The Configuration Recorder is the engine that generates CIs. It polls the AWS control plane and integrates with AWS CloudTrail to monitor API activity. When a resource is created, updated, or deleted, the recorder:
1.  Intercepts the configuration event.
2.  Executes a `Describe` or `List` API call against the resource.
3.  Composes a new Configuration Item JSON document.
4.  Stores the CI in your dedicated S3 history bucket.

#### C. Configuration History & Timeline
The **Configuration History** is the chronological collection of all CIs generated for a resource since recording was enabled. The **Resource Timeline** is the visual representation of this history. It allows administrators to select any resource and view its state transitions day-by-day, hour-by-hour, showing exactly how the resource evolved over its lifecycle.

#### D. Change Tracking (The JSON Diff)
When a resource is modified, AWS Config compares the new Configuration Item with the previous one. The console highlights the differences between the two JSON schemas, displaying a delta (diff) showing exactly what was added, modified, or removed (e.g., indicating that the `IpRanges` parameter on Port 3306 went from allowed to null).

```
                      JSON DIFFERENCE (BEFORE VS. AFTER)
┌──────────────────────────────────────┐  ┌──────────────────────────────────────┐
│ BEFORE (COMPLIANT)                   │  │ AFTER (NON-COMPLIANT)                │
│ "ipRanges": [                        │  │ "ipRanges": []                       │
│   { "cidrIp": "192.168.1.0/24" }     │  │                                      │
│ ]                                    │  │ (Ingress rule deleted)               │
└──────────────────────────────────────┘  └──────────────────────────────────────┘
```

#### E. Resource Relationships
AWS Config builds an active dependency graph of your resources. When looking at a Security Group, Config maps its relationships to the Elastic Network Interfaces (ENIs) using it, and the EC2 instances attached to those ENIs. 

This mapping helps administrators trace the blast radius of a change, showing which servers and applications are impacted by an altered security policy.

#### F. Architectural Comparison: AWS Config vs. CloudTrail
Understanding the difference between AWS Config and AWS CloudTrail is a core requirement for cloud governance.

*   **AWS CloudTrail (The "Who" and "When"):** Logs API calls. It records *activity*—detailing who made the API request, from what source IP, at what time, and what parameters were passed. It is an operational log of API transactions.
*   **AWS Config (The "What" and "Current State"):** Logs *state*. It tracks the physical properties of the resource itself. It does not record the active user session details; instead, it shows what the resource looked like before the change, what it looks like now, how it relates to other resources, and whether it complies with your governance policies.

```
       AWS CLOUDTRAIL (Activity Log)                  AWS CONFIG (State Ledger)
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│  - "Who executed the API call?"      │        │  - "What is the resource state now?" │
│  - User: Developer-Bob               │        │  - State: Port 3306 is open          │
│  - API Call: DeleteSecurityGroupRule │        │  - Diff: Deleted cidr 192.168.1.0/24 │
└──────────────────────────────────────┘        └──────────────────────────────────────┘
```

#### G. AWS Config Rules & Managed Rules
*   **Config Rules:** Declarative policies that define your desired state for AWS resources. They act as automated guardrails that continuously evaluate the compliance of your Configuration Items.
*   **Managed Rules:** Pre-built compliance checks developed and maintained by AWS (e.g., `s3-bucket-ssl-requests-only` or `ssh-restricted-common-ports`). They compile industry best practices into turnkey auditing policies.

#### H. Compliance Evaluation Cycle
Config rules are evaluated based on two trigger types:
*   **Configuration Change Triggers:** The rule runs immediately when the Configuration Recorder detects a state change for the specified resource type (near real-time auditing).
*   **Periodic Triggers:** The rule runs at a scheduled interval (e.g., every 1, 3, or 24 hours) to verify the compliance state of your resources.

#### I. Drift Detection
Drift occurs when a resource's live configuration deviates from your desired organizational policy. Drift detection is the process where AWS Config evaluates a resource's current Configuration Item against your defined rules, identifies the differences, and flags compliance deviations on your dashboard.

```
  DESIRED STATE (Managed Rule)                  LIVE STATE (Resource CI)
┌──────────────────────────────┐              ┌──────────────────────────────┐
│ S3 Public Access: BLOCKED    │ ◄─── Diff ── │ S3 Public Access: ALLOWED    │
│                              │  Evaluation  │ (Drift Detected - Status Red)│
└──────────────────────────────┘              └──────────────────────────────┘
```

#### J. Compliance Dashboards
A centralized operational interface that aggregates compliance metrics across your entire AWS account or multi-account AWS Organization. It highlights the percentage of compliant resources, alerts you to non-compliant assets, and organizes findings by severity level to help prioritize security remediations.

#### K. Key Governance Use Cases
*   **Continuous Compliance:** Automatically verifying that resources meet security standards (e.g., checking that all EBS volumes are encrypted at rest).
*   **Change Management:** Auditing the history of resource changes to help troubleshoot system failures and investigate security incidents.
*   **Vulnerability Assessment:** Identifying exposed ports, unencrypted storage, or overly permissive policies to reduce your security attack surface.
*   **Audit Reporting:** Providing compliance logs and historic resource timelines for industry audits (e.g., PCI-DSS, SOC 2, HIPAA).

---

## 📘 PART 2 — THE SELF-HEALING GRID & REMEDIATION

### 1. The Scenario: Reverting an Insecure Public S3 Bucket
To understand automated remediation, consider this scenario:

An engineer disables the "Block All Public Access" setting on an Amazon S3 bucket, exposing sensitive company data to the public internet. 

Within 60 seconds, an event-driven remediation loop detects the drift, flags the bucket as non-compliant, and passes the execution to an AWS Systems Manager (SSM) Automation Runbook. The runbook executes an API call to re-enable "Block Public Access," locking the bucket down without human intervention.

```
 1. DRIFT EVENT (Public S3)     2. DETECTION (AWS Config)       3. REPAIR EVENT (SSM Document)
┌─────────────────────────┐    ┌─────────────────────────┐    ┌───────────────────────────┐
│ User disables S3 public │ ──►│ Config flags resource   │ ──►│ SSM Runbook executes API  │
│ access blocks           │    │ as NON_COMPLIANT        │    │ PutBucketPublicAccessBlock│
└─────────────────────────┘    └─────────────────────────┘    └─────────────┬─────────────┘
                                                                            │
                                                                            ▼
                                                              ┌───────────────────────────┐
                                                              │ S3 Bucket auto-reverts to │
                                                              │ COMPLIANT (Secure) state  │
                                                              └───────────────────────────┘
```

---

### 2. Theoretical Breakdown of Automated Remediation

#### A. Compliance State Lifecycle
A resource's compliance lifecycle flows through a series of defined state transitions:
1.  **Compliant:** The resource matches your defined policies.
2.  **Non-Compliant:** A change is made that violates a rule.
3.  **Remediating:** Config initiates an automation runbook to resolve the violation.
4.  **Compliant (Resolved):** The runbook corrects the configuration, and Config records the new, compliant state.

```
  [ COMPLIANT ] ─── (Resource Drift) ───► [ NON_COMPLIANT ]
         ▲                                         │
         │                                (Trigger Remediation)
         │                                         ▼
  [ COMPLIANT ] ◄─── (State Sync CI) ◄─── [ REMEDIATING ]
```

#### B. Remediation Workflows
Remediation workflows link detection rules to automated recovery actions. You can configure remediation to execute:
*   **Manually:** An administrator reviews the compliance dashboard and clicks a button to trigger the fix.
*   **Automatically:** The system triggers the fix immediately when a resource fails a compliance check, providing real-time protection against misconfigurations.

#### C. Systems Manager (SSM) Automation Triggers
AWS Systems Manager (SSM) is the execution engine for AWS Config remediations. 
1.  When a resource is flagged as `NON_COMPLIANT`, Config queries your remediation settings.
2.  Config uses an IAM service role to execute the STS `AssumeRole` action, obtaining the permissions defined in the remediation role.
3.  Config calls the Systems Manager API to trigger the specified **SSM Automation Document**, passing the non-compliant resource's ID (e.g., S3 Bucket Name or EC2 Instance ID) as an input parameter.

#### D. Automatic Remediation (The Reversion Loop)
The SSM Automation Document runs a series of actions (e.g., executing Python scripts or calling AWS APIs) to correct the resource's configuration. 

For the S3 public access scenario, the runbook calls the S3 API endpoint `PutBucketPublicAccessBlock` to re-apply the block settings. Once the update is complete, Config evaluates the new state and updates the resource's status to `COMPLIANT`.

#### E. Auditability & Security Guardrails
To prevent automated remediation loops from causing security issues or system outages, you must implement the following controls:
*   **CloudTrail Auditing:** Every action taken by the SSM Automation Role is logged in AWS CloudTrail, providing a clear audit trail of automated repairs.
*   **Remediation Rate Limits:** Configuring rate limits prevents remediation tasks from executing too quickly, avoiding API throttling and reducing the impact of misconfigured rules.
*   **Remediation Loop Protection:** Config stops executing remediation runbooks if a resource fails compliance checks repeatedly, preventing endless repair loops that can occur if a local configuration conflicts with your compliance rules.
