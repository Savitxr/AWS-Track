# Terraform Modules & Custom Registry Publishing
### 📖 Part 3: Sibling, Child, and Parent References, & Custom Module Publishing workflows

This guide covers building modular code structures in Terraform. It explains how to pass data between **Parent**, **Child**, and **Sibling** modules, and details the step-by-step workflow of publishing custom modules to a private or public GitHub-linked **Terraform Registry**.

---

## 🏗️ 1. Module Reference Paths & Publishing Lifecycle

The diagrams below illustrate the data flow of module references and the GitHub-to-Registry integration loop.

### Module Reference Data Flow
```
        PARENT CONFIGURATION (Root Module)
        ┌────────────────────────────────────────────────────────┐
        │  module "vpc" {                                        │
        │    source = "./modules/vpc"   ◄── Child Reference      │
        │  }                                                     │
        │                                                        │
        │  module "security_group" {                             │
        │    source = "./modules/sg"                             │
        │    vpc_id = module.vpc.vpc_id ◄── Sibling Reference    │
        │  }                                                     │
        └────────────────────────────────────────────────────────┘
```

### GitHub-to-Registry Publishing Flow
```
 ┌──────────────────────┐        ┌──────────────────────┐
 │  Local HCL Module    │        │  GitHub Repository   │
 │  (Code Development)  ├───────►│  terraform-aws-ec2   │
 └──────────────────────┘ Push   └──────────┬───────────┘
                                            │ Tag: v1.0.0
                                            ▼
 ┌──────────────────────┐        ┌──────────────────────┐
 │  Terraform Registry  │◄───────┤ Webhook/Git Watcher  │
 │  (Published version) │ Sync   │ (Triggers on Tag)    │
 └──────────────────────┘        └──────────────────────┘
```



## 📘 3. Topic 7: Sibling, Child, and Parent Module References

Modules are self-contained packages of Terraform configurations that allow you to group related resources together. To structure modular designs, you must master the three reference spaces.

---

### Reference Space A: Parent Reference
* **Syntax Context:** Declared in the root directory's configuration file (e.g., `./main.tf`).
  ```hcl
  module "network" {
    source   = "./modules/vpc"
    vpc_cidr = "10.0.0.0/16"
  }
  ```
* **🔍 What is Happening:** The Parent module (root caller) initializes the Child module (`./modules/vpc`) and inputs data (like the CIDR block parameter) into it.
* **💡 Why it is Happening:** To instantiate a blueprint configuration, passing custom input parameters to tailor the deployment.
* **⚡ If you do this (Consequences):** Terraform allocates a separate, isolated namespace for the module's resources (prefixed in state as `module.network.aws_vpc.main`).

---

### Reference Space B: Child Reference
* **Syntax Context:** Declared *inside* the module subdirectory's code (e.g. `./modules/vpc/main.tf`).
  ```hcl
  resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr # Internal input reference
  }
  ```
* **🔍 What is Happening:** The resources inside the module reference variables defined in the module's own `variables.tf`.
* **💡 Why it is Happening:** To write decoupled, generic code that does not depend on hardcoded root values.
* **⚡ If you do this (Consequences):** The module is completely portable. It can be called multiple times with different CIDR blocks without internal code changes.

---

### Reference Space C: Sibling Reference
* **Syntax Context:** Exchanging output data between two independent modules in the parent configuration.
  ```hcl
  module "vpc" {
    source = "./modules/vpc"
  }
  module "app_sg" {
    source = "./modules/sg"
    vpc_id = module.vpc.vpc_id # Sibling Reference
  }
  ```
* **🔍 What is Happening:** We feed the output parameter of the `vpc` child module directly into the input argument of the `app_sg` child module.
* **💡 Why it is Happening:** In multi-module designs, downstream resources (like security groups or EC2 instances) must know the ID or attributes of upstream resources (like the created VPC or subnets).
* **⚡ If you do this (Consequences):** Terraform automatically resolves the resource graph dependencies. It knows it must completely build the `vpc` module before starting the `app_sg` module.
* **🧠 Deep Tech Explanation (Explicit vs Implicit Sibling Graphing):**
  Using a sibling reference creates an **implicit dependency** between the two modules in Terraform's DAG. You do not need to add a `depends_on` block inside `module "app_sg"`. The parser analyzes the variable reference `module.vpc.vpc_id` and automatically schedules the VPC build thread first.

---

## 📘 4. Topic 8: Custom Module Publishing to the Terraform Registry

Publishing modules to a central registry allows organizations to distribute vetted, standard infrastructure blueprints across multiple teams. Here is the exact end-to-end publishing workflow.

---

### Step 1: Design the Repository Structure
The Terraform Registry enforces a strict naming convention and directory structure.

#### 1. Repository Naming Convention
The repository name in GitHub **must** follow this exact format:
```
terraform-<PROVIDER>-<NAME>
```
*Example:* `terraform-aws-secure-ec2`
* If the name does not match this structure, the registry will reject it during the sync step.

#### 2. Directory Structure Layout
Your repository must contain these exact files at the root level:
```
terraform-aws-secure-ec2/
├── README.md        # Technical usage guide and input/output descriptions
├── main.tf          # Core HCL resource declarations
├── variables.tf     # Explicitly defined variable configurations
├── outputs.tf       # Exported resource attribute definitions
└── LICENSE          # Open-source license (e.g., Apache 2.0 or MIT)
```

---

### Step 2: Implement the Custom Module Code
Here is the code for our standard `terraform-aws-secure-ec2` module.

#### `main.tf`
```hcl
# main.tf of custom EC2 module
resource "aws_instance" "ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Name        = var.instance_name
    Provisioner = "Terraform-Registry"
  }
}
```

#### `variables.tf`
```hcl
variable "ami_id" {
  type        = string
  description = "Target AMI ID to deploy"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 computing sizing"
}

variable "subnet_id" {
  type        = string
  description = "Target subnet network placement ID"
}

variable "instance_name" {
  type        = string
  description = "Resource name tag"
}
```

#### `outputs.tf`
```hcl
output "instance_id" {
  value       = aws_instance.ec2.id
  description = "The unique AWS ID of the created virtual server"
}

output "private_ip" {
  value       = aws_instance.ec2.private_ip
  description = "Internal assigned private IP"
}
```

---

### Step 3: Git Tagging & Semantic Versioning (SemVer)
The Terraform Registry relies entirely on Git tags to identify module versions.

```bash
# 1. Initialize local repository and commit code
git init
git add .
git commit -m "feat: Initial commit of secure EC2 module"

# 2. Add remote GitHub origin and push main branch
git remote add origin https://github.com/your-org/terraform-aws-secure-ec2.git
git branch -M main
git push -u origin main

# 3. Create a Semantic Version Tag
git tag v1.0.0
git push origin v1.0.0
```

> [!IMPORTANT]
> **🧠 Deep Tech Explanation (The Importance of Git Tags & SemVer):**
> Terraform Registry parses your Git history for tags that match **Semantic Versioning** rules (e.g., `vX.Y.Z` or `X.Y.Z`).
> - **Major (v1.0.0 -> v2.0.0):** Indicates breaking API changes (e.g. changing an input variable name from `ami_id` to `image_id`).
> - **Minor (v1.0.0 -> v1.1.0):** Adds backward-compatible functionality (e.g., adding a new optional input variable `enable_monitoring`).
> - **Patch (v1.0.0 -> v1.0.1):** Backward-compatible bug fixes.
> If you make changes to your module code in GitHub but **fail to push a new tag**, the registry will not register a new version, and users referencing version constraints (like `version = "~> 1.0"`) will not receive the update.

---

### Step 4: Register and Link the Module in the Terraform Registry
1. Go to [registry.terraform.io](https://registry.terraform.io) and log in using your GitHub account credentials.
2. Click **Publish** -> **Modules**.
3. Select the repository `terraform-aws-secure-ec2` from your GitHub repository list.
4. Agree to the Terms of Service and click **Publish Module**.
5. The registry registers a GitHub webhook. Whenever you push a new git tag (e.g. `v1.1.0`), the webhook triggers automatically, making the new version available on the registry within seconds.

---

### Step 5: Consuming the Published Registry Module in HCL
To use your newly published module in another project, call it directly using the registry's source path and version constraints:

```hcl
# calling configuration (main.tf)
module "production_ec2" {
  source  = "app.terraform.io/your-org/secure-ec2/aws" # Registry source target
  version = "~> 1.0.0"                                  # Stable SemVer limit

  ami_id        = "ami-0c7217cdde317cfec"
  subnet_id     = "subnet-0123456789abcdef0"
  instance_name = "Prod-Registry-Node"
}
```

---

## 🔍 5. Verification & Architectural Review

### **What is Happening:**
We created a modularized architecture where our EC2 setup was written in a separate, isolated codebase. We pushed it to GitHub, registered it in the Terraform Registry, and loaded it into a calling configuration using a secure version constraint.

### **Why it is structured this way:**
Decoupling configurations into standard modules prevents code duplication across projects. Centralizing these blueprints in a central registry allows organizations to enforce infrastructure security standards (like ensuring all EC2 modules have encryption enabled) across different engineering teams.

### **Consequences of Version Constraints:**
By using the pessimistic version constraint operator `~> 1.0.0`, the developer tells Terraform: "I will accept minor and patch updates (e.g., `v1.0.1`, `v1.1.0`) automatically, but **block any major releases** (e.g., `v2.0.0`) because they contain breaking API changes that would break my build." This provides a balance between automated bug fixes and stable deployment pipelines.
