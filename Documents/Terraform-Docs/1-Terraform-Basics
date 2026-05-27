# Terraform Fundamentals & Static 3-Tier AWS Infrastructure (Without Meta-Arguments)
### 📖 Part 1: Core CLI Commands, HCL Blocks, Network provisioning, & Static 3-Tier Design

This learning guide is structured to help you master the foundational elements of Terraform. It begins with the fundamental CLI commands and configuration blocks, demonstrates how to build standard AWS networking components, and concludes with an explicit, static 3-tier architecture.

---

## 🏗️ 1. 3-Tier Network Architecture (Static)

The following layout represents the architecture we are building statically using HCL:

```
VPC (10.10.0.0/16)
┌────────────────────────────────────────────────────────────────────────┐
│  PUBLIC SUBTIER (10.10.1.0/24 & 10.10.2.0/24)                         │
│  ┌───────────────────────────────┐   ┌───────────────────────────────┐ │
│  │ Public Subnet AZ-A            │   │ Public Subnet AZ-B            │ │
│  │ ┌───────────────────────────┐ │   │ ┌───────────────────────────┐ │ │
│  │ │ Public ALB / Web Instance │ │   │ │ NAT Gateway / Web Inst    │ │ │
│  │ └───────────────────────────┘ │   │ └───────────────────────────┘ │ │
│  └───────────────────────────────┘   └───────────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────┤
│  PRIVATE APP SUBTIER (10.10.3.0/24 & 10.10.4.0/24)                     │
│  ┌───────────────────────────────┐   ┌───────────────────────────────┐ │
│  │ Private Subnet AZ-A           │   │ Private Subnet AZ-B           │ │
│  │ ┌───────────────────────────┐ │   │ ┌───────────────────────────┐ │ │
│  │ │ Application Instance      │ │   │ │ Application Instance      │ │ │
│  │ └───────────────────────────┘ │   │ └───────────────────────────┘ │ │
│  └───────────────────────────────┘   └───────────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────┤
│  ISOLATED DATABASE SUBTIER (10.10.5.0/24 & 10.10.6.0/24)               │
│  ┌───────────────────────────────┐   ┌───────────────────────────────┐ │
│  │ DB Subnet AZ-A                │   │ DB Subnet AZ-B                │ │
│  │ ┌───────────────────────────┐ │   │ ┌───────────────────────────┐ │ │
│  │ │ RDS Primary Database      │ │   │ │ RDS Standby Replica       │ │ │
│  │ └───────────────────────────┘ │   │ └───────────────────────────┘ │ │
│  └───────────────────────────────┘   └───────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```



## 📘 3. Topic 1: Core Terraform CLI Commands

Each CLI command is analyzed down to its core engineering lifecycle mechanisms.

---

### Command A: `terraform init`

> [!NOTE]
> **🔍 What is Happening:** Terraform scans the `.tf` configuration files in the working directory, downloads the required provider plugins (e.g., AWS, Azure, GCP) and module source code, and initializes backend state storage.
> 
> **💡 Why it is Happening:** Terraform is plugin-based. The core engine is provider-agnostic. In order to translate HCL statements into API requests (e.g. EC2, RDS APIs), it must download the appropriate provider binaries that contain the API schemas.
> 
> **⚡ If you do this (Consequences):**
> 1. A hidden directory `.terraform/` is created, housing the compiled provider binaries.
> 2. A dependency lock file `.terraform.lock.hcl` is generated (or updated).
> 3. The backend configuration (local or S3/GCS state storage) is established.
> 
> **🧠 Deep Tech Explanation (The Lock File):**
> The `.terraform.lock.hcl` file locks the exact version and SHA hashes of the provider plugins installed. In multi-developer teams, this ensures that subsequent `terraform init` executions on other systems download the exact same provider binaries, preventing silent configuration drifts or parsing errors caused by out-of-date or upgraded provider plugins.

---

### Command B: `terraform validate`

> [!NOTE]
> **🔍 What is Happening:** Terraform performs a static code analysis check on the configuration files in the directory to verify syntactical correctness and internal attribute mappings.
> 
> **💡 Why it is Happening:** Running plans against live cloud infrastructures is slow. `validate` provides a fast loop to catch typographical errors, missing variables, or wrong block declarations locally.
> 
> **⚡ If you do this (Consequences):** It returns `Success!` or a compilation log highlighting files, lines, and errors. It does not contact cloud APIs and does not check if resources (like specific AMI IDs) actually exist.
> 
> **🧠 Deep Tech Explanation (Lexical Scoping & HCL Parsing):**
> `terraform validate` runs the HCL parser against your files. It builds a syntax tree and validates attribute types against the provider schemas saved in `.terraform/`. It checks if a resource's references (e.g. `subnet_id = aws_subnet.public.id`) map to declared resources, ensuring reference graph integrity before deployment.

---

### Command C: `terraform fmt`

> [!NOTE]
> **🔍 What is Happening:** Terraform automatically rewrites all HCL configuration files in the directory to conform to standard formatting conventions (nesting, alignments, spacing).
> 
> **💡 Why it is Happening:** To maintain consistency, readability, and clean git diffs across an organization without developers arguing over formatting styles.
> 
> **⚡ If you do this (Consequences):** Rewrites files in-place. If called with `terraform fmt -check`, it returns non-zero codes if changes are needed, which is ideal for CI/CD checks.

---

### Command D: `terraform plan`

> [!NOTE]
> **🔍 What is Happening:** Terraform performs a dry run. It queries the target cloud API (or reads current state) to construct a detailed execution path of what resources it needs to create, modify, or destroy to match the declarative target.
> 
> **💡 Why it is Happening:** To let you review the exact changes Terraform will make in production before executing them.
> 
> **⚡ If you do this (Consequences):**
> 1. Displays a detailed output (`+` create, `~` update in-place, `-/+` destroy and recreate).
> 2. No changes are applied to actual cloud assets.
> 
> **🧠 Deep Tech Explanation (State Refresh vs. Drift Detection):**
> During `plan`, Terraform reads the current local/remote `terraform.tfstate` file, contacts the cloud provider endpoints in real-time to query the true state of live assets (a process called "refreshing state"), and then performs a three-way diff between the **Live Infrastructure**, the **State File**, and the **Local HCL Configurations**. This detects "out-of-band" manual changes (drift).

---

### Command E: `terraform apply`

> [!NOTE]
> **🔍 What is Happening:** Terraform executes the plan, calling the cloud provider APIs in an ordered sequence to instantiate, change, or tear down live cloud resources.
> 
> **💡 Why it is Happening:** To realize the desired state declared in HCL into actual working infrastructure.
> 
> **⚡ If you do this (Consequences):**
> 1. Actual resources are created/updated/deleted.
> 2. The metadata is written to `terraform.tfstate`.
> 
> **🧠 Deep Tech Explanation (State Locking & Mutexes):**
> When running `apply`, Terraform places a lock on the state backend (using mechanisms like DynamoDB locks for S3, or native API locks for GCS). This acts as a distributed mutex. If another developer attempts to run `apply` or `destroy` concurrently, they are blocked, preventing race conditions that could corrupt the state database.

---

### Command F: `terraform destroy`

> [!NOTE]
> **🔍 What is Happening:** Terraform tears down all live cloud resources managed by the current workspace configuration.
> 
> **💡 Why it is Happening:** Used to clean up temporary environments, dev clusters, or deprecated stacks safely without having to click around the console.
> 
> **⚡ If you do this (Consequences):** All declared resources in the configuration are permanently terminated, and the local `terraform.tfstate` is updated to contain an empty mapping.

---

## 📘 4. Topic 2: Fundamental HCL Block Types

Let's dissect the four core building block types in HashiCorp Configuration Language (HCL).

```
 ┌──────────────────────┐        ┌──────────────────────┐
 │  provider "aws"      │        │  variable "reg"      │
 │  (Configures APIs)   │        │  (Parametric Input)  │
 └──────────┬───────────┘        └──────────┬───────────┘
            │                               │
            └──────────────┬────────────────┘
                           ▼
                 ┌──────────────────┐
                 │  resource "ec2"  │
                 │  (Spins up VM)   │
                 └─────────┬────────┘
                           ▼
                 ┌──────────────────┐
                 │  output "public" │
                 │  (Exposes Value) │
                 └──────────────────┘
```

### 1. `provider` Block
* **Syntax:**
  ```hcl
  provider "aws" {
    region = "us-east-1"
  }
  ```
* **🔍 What is it:** Configures the targeted cloud service API provider, passing keys, regions, and endpoint settings.
* **💡 Why it is used:** To tell Terraform *where* to deploy and which regional APIs to authenticate against.
* **⚡ If you define this:** Terraform loads the API endpoint credentials and formats API requests for that region.

### 2. `variable` Block
* **Syntax:**
  ```hcl
  variable "instance_type" {
    type        = string
    default     = "t3.micro"
    description = "Instance type for our servers"
  }
  ```
* **🔍 What is it:** Defines parameter variables that act as input values to customize configurations.
* **💡 Why it is used:** To avoid hardcoding values and allow reusability (e.g. deploying dev vs prod type).
* **⚡ If you define this:** You can pass values via CLI (`-var`), environment variables (`TF_VAR_`), or variable files (`.tfvars`).

### 3. `resource` Block
* **Syntax:**
  ```hcl
  resource "aws_instance" "app_server" {
    ami           = "ami-0c7217cdde317cfec"
    instance_type = var.instance_type
  }
  ```
* **🔍 What is it:** Declares a concrete infrastructure component that Terraform must manage (create, update, delete).
* **💡 Why it is used:** It is the primary vehicle for defining what you want built.
* **⚡ If you define this:** Terraform checks state, tracks the resource lifecycle, and calls the API to deploy it.

### 4. `output` Block
* **Syntax:**
  ```hcl
  output "server_public_ip" {
    value       = aws_instance.app_server.public_ip
    description = "The public IP of our web server"
  }
  ```
* **🔍 What is it:** Exposes specific information/attributes of resources to the console or other configurations.
* **💡 Why it is used:** To retrieve critical data (like Database DNS endpoints, public IPs) without hunting through consoles, or to share outputs between modules.
* **⚡ If you define this:** Terraform prints the resolved values to the terminal screen at the end of `terraform apply`.

---

## 📘 5. Topic 3: Task — AWS Network Components Statically Created

Below is the static, production-grade HCL code to build an AWS Virtual Private Cloud (VPC), Internet Gateway, Subnets, and Route tables.

### `main.tf`
```hcl
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. VPC Creation
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Static-Core-VPC"
  }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "Static-Core-IGW"
  }
}

# 3. Subnets (Statically declared without loops)
resource "aws_subnet" "public_az_a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-AZ-A"
  }
}

resource "aws_subnet" "public_az_b" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-AZ-B"
  }
}

resource "aws_subnet" "private_az_a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-Subnet-AZ-A"
  }
}

resource "aws_subnet" "private_az_b" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-Subnet-AZ-B"
  }
}

# 4. Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-RouteTable"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "Private-RouteTable"
  }
}

# 5. Route Table Subnet Associations
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_az_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_az_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_az_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_az_b.id
  route_table_id = aws_route_table.private_rt.id
}
```

### `variables.tf`
```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
```

### `outputs.tf`
```hcl
output "vpc_id" {
  value = aws_vpc.custom_vpc.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_az_a.id,
    aws_subnet.public_az_b.id
  ]
}
```

---

## 📘 6. Topic 4: Static 3-Tier Infrastructure (Without Meta-Arguments)

We expand the architecture above into a full **3-Tier Stack** (Web Tier, App Tier, Database Tier) statically without using loops, arrays, or metadata helpers.

```hcl
# ==========================================
# 3-TIER NETWORKING & INFRASTRUCTURE
# ==========================================

# Additional database subnets (DB Tier)
resource "aws_subnet" "db_az_a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.5.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "DB-Subnet-AZ-A"
  }
}

resource "aws_subnet" "db_az_b" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.10.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "DB-Subnet-AZ-B"
  }
}

# DB Subnet group needed by RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.db_az_a.id, aws_subnet.db_az_b.id]

  tags = {
    Name = "DB-Subnet-Group"
  }
}

# ==========================================
# SECURITY GROUPS (TIER ISOLATION)
# ==========================================

# 1. Public ALB Security Group (Web ingress)
resource "aws_security_group" "alb_sg" {
  name        = "public-alb-sg"
  description = "Allows incoming HTTP traffic"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. App Instance Security Group (Only accepts traffic from public ALB)
resource "aws_security_group" "app_sg" {
  name        = "app-instance-sg"
  description = "Allows traffic only from ALB"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Database Security Group (Only accepts traffic from App security group)
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allows postgres ingress from App SG"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# VIRTUAL COMPONENT COMPUTE PROVISIONING
# ==========================================

# Statically launching two App servers in AZ-A and AZ-B
resource "aws_instance" "app_server_a" {
  ami                    = "ami-0c7217cdde317cfec" # Standard Ubuntu AMI
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_az_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "3Tier-AppServer-A"
  }
}

resource "aws_instance" "app_server_b" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_az_b.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "3Tier-AppServer-B"
  }
}

# RDS Postgres Instance in the DB subnet group
resource "aws_db_instance" "db_primary" {
  allocated_storage      = 20
  db_name                = "appdb"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t4g.micro"
  username               = "dbadmin"
  password               = "StaticSuperSecretPassword123!"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "3Tier-Primary-DB"
  }
}
```

---

## 🔍 7. Verification & Educational Analysis

### **What is Happening Statically:**
We declared every single asset explicitly. The two subnet paths, the two separate EC2 instances, and the distinct route tables were coded one by one.

### **Why it is structured this way:**
Writing configurations statically is critical during early development phases or small projects. It eliminates logical abstractions and dynamic loops, making the execution graph visually transparent and highly straightforward to debug.

### **Consequences of this Approach:**
1. **Low Scalability**: If we decided to deploy in 6 Availability Zones instead of 2, we would have to copy and paste hundreds of lines of identical HCL block configurations, inflating the codebase and creating major code duplication issues.
2. **Maintenance Drag**: Changing any attribute (like the database instance class) requires finding and editing all duplicate blocks manually, which increases the likelihood of human error.
3. **Explicit Sequencing**: Dependency ordering is explicitly defined by direct variable outputs (e.g. `vpc_id = aws_vpc.custom_vpc.id`).
