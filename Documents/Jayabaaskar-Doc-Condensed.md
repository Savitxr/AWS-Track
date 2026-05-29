# AWS Cloud Documentation — Condensed
---

## Part 1: From On-Premises to Cloud Computing

### 1. Traditional On-Premises vs Cloud

**On-Premises Problems:**
- High upfront cost (servers, cooling, power, security, IT teams)
- Slow scaling — buying/installing servers takes time
- Resource wastage — servers idle during off-peak hours
- Maintenance complexity and risk of downtime

**Why Cloud?** AWS, Azure, and GCP built massive global infrastructure and offer computing resources on-demand, pay-as-you-go — no physical ownership needed.

> **Cloud Computing** = Delivery of servers, storage, databases, networking, software over the internet on a pay-as-you-go basis.

---

### 2. Key Cloud Characteristics
| Feature | Description |
|---|---|
| On-Demand Self-Service | Launch resources instantly, no human interaction |
| Scalability | Scale up/down based on demand |
| Pay-As-You-Go | Pay only for what you use |
| High Availability | Services remain accessible even during failures |
| Global Reach | Deploy closer to users worldwide |

---

### 3. Cloud Types & Service Models

**Cloud Types:**
- **Public** — AWS, Azure, GCP (most common)
- **Private** — Dedicated to one org (banks, gov't); more control, more expensive
- **Hybrid** — Mix of public + private

**Service Models:**
| Model | Provider Manages | User Manages | Example |
|---|---|---|---|
| IaaS | Hardware, networking | OS, apps | EC2 |
| PaaS | Infra + OS + runtime | Application code | Elastic Beanstalk |
| SaaS | Everything | Nothing | Gmail, Zoom |

---

### 4. AWS Global Infrastructure

| Component | Description |
|---|---|
| **Region** | Geographical area with multiple data centers (e.g., Mumbai, Frankfurt) |
| **Availability Zone (AZ)** | Physically separate data center within a Region, independent power/cooling/network |
| **Edge Location** | Smaller sites for content delivery/caching (CloudFront) |

**High Availability** = Minimize downtime using multiple AZs, load balancers, auto scaling.  
**Fault Tolerance** = System continues operating even when components fail (zero interruption goal).  
**Virtualization** = One physical server runs multiple virtual machines → better resource use.

---

## Part 2: Networking Fundamentals

### 1. IP Addressing Basics

**IPv4 Structure:** `192.168.1.10` = 4 octets × 8 bits = 32 bits total. Each octet: 0–255.

**Network vs Host Portion:**
- Network portion → identifies the network
- Host portion → identifies the device

**Subnet Mask:** Tells which bits are network (`1`) and which are host (`0`).
```
255.255.255.0 = 11111111.11111111.11111111.00000000
First 24 bits = network | Last 8 bits = host
```

**CIDR Notation:** Short form of subnet mask.
| CIDR | Subnet Mask | Network Bits |
|---|---|---|
| /8 | 255.0.0.0 | 8 |
| /16 | 255.255.0.0 | 16 |
| /24 | 255.255.255.0 | 24 |

---

### 2. Network Address, Broadcast & Usable Hosts

- **Network Address** = All host bits = 0 (e.g., `192.168.1.0`) — identifies the network, not assignable
- **Broadcast Address** = All host bits = 1 (e.g., `192.168.1.255`) — sends to all devices in subnet
- **Usable Hosts** = Total - 2 (e.g., `/24` → 254 usable IPs: `.1` to `.254`)

---

### 3. Public vs Private IPs

| Type | Description | Example Ranges |
|---|---|---|
| Public | Internet-accessible, globally unique | `13.234.55.10` |
| Private Class A | Internal use | `10.0.0.0/8` |
| Private Class B | Internal use | `172.16.0.0 – 172.31.255.255` |
| Private Class C | Internal use | `192.168.0.0/16` |

AWS VPC uses private IP addressing.

---

### 4. Subnetting & CIDR

**Why Classful networking failed:** Fixed sizes (/8, /16, /24) caused IP wastage.  
**CIDR solution:** Flexible sizes — `/20`, `/22`, `/27` etc.

**Subnetting** = Dividing a large network into smaller networks.
```
10.0.0.0/16  →  10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24 ... (each = 254 usable hosts)
```

**AWS VPC Example:**
| Purpose | Subnet |
|---|---|
| Public | 10.0.1.0/24 |
| Private | 10.0.2.0/24 |
| Database | 10.0.3.0/24 |

---

### 5. Public vs Private Subnets & Bastion Host

| Feature | Public Subnet | Private Subnet |
|---|---|---|
| Internet Access | Direct (via IGW) | Outbound only (via NAT) |
| Public IP | Assigned | Not assigned |
| Examples | Load Balancer, Bastion | Databases, App servers |

**Bastion Host:** Secure EC2 in public subnet for SSH access to private instances.
```
Laptop → Bastion Host → Private EC2
```

---

## Part 3: AWS VPC Networking

### 1. What is a VPC?

**VPC (Virtual Private Cloud)** = A logically isolated virtual network inside AWS where cloud resources are deployed.

**Default VPC** → Auto-created, beginner-friendly, not production-ready.  
**Custom VPC** → Manually designed, full control, preferred for enterprise.

### 2. VPC Core Components

| Component | Role |
|---|---|
| Subnets | Divide VPC into smaller networks |
| Route Tables | Rules for where traffic goes |
| Internet Gateway (IGW) | Connects VPC to internet |
| NAT Gateway | Outbound internet for private instances |
| Security Groups | Instance-level stateful firewall (allow rules only) |
| NACL | Subnet-level stateless firewall (allow + deny) |

**Security Group vs NACL:**
| Feature | Security Group | NACL |
|---|---|---|
| Level | Instance | Subnet |
| Stateful | Yes | No |
| Deny Rules | No | Yes |

**Route Table Examples:**
- Public RT: `0.0.0.0/0 → Internet Gateway`
- Private RT: `0.0.0.0/0 → NAT Gateway`

**Traffic Flows:**
```
User → Route53 → ALB → Private EC2
Admin → Bastion Host → Private EC2
Private EC2 → NAT Gateway → Internet
```

---

### 3. Practical Tasks — VPC Setup

#### LEVEL 1 — Beginner

**Task 1 – Create a Custom VPC**
1. AWS Console → VPC → Create VPC
2. Name: `My-VPC`, IPv4 CIDR: `10.0.0.0/16`, Tenancy: Default
3. Verify VPC state = `Available`

**Task 2 – Create Public Subnets**

| Subnet | VPC | AZ | CIDR |
|---|---|---|---|
| Public-Subnet-A | My-VPC | ap-south-1a | 10.0.1.0/24 |
| Public-Subnet-B | My-VPC | ap-south-1b | 10.0.2.0/24 |

**Task 3 – Create & Attach Internet Gateway**
1. VPC → Internet Gateways → Create IGW → Name: `My-IGW`
2. Attach to `My-VPC` → Verify State = `Attached`

**Task 4 – Configure Public Route Table**
1. Create Route Table → Name: `Public-RT`, VPC: `My-VPC`
2. Add Route: `0.0.0.0/0 → Internet Gateway`
3. Associate `Public-Subnet-A` + `Public-Subnet-B`

**Task 5 – Launch EC2 in Public Subnet**

| Setting | Value |
|---|---|
| Name | Public-Web-Server |
| AMI | Ubuntu Server 24.04 |
| Instance Type | t2.micro |
| Subnet | Public-Subnet-A |
| Auto Assign Public IP | Enabled |

Security Group: HTTP:80 (0.0.0.0/0), SSH:22 (My IP)

```bash
sudo apt update -y && sudo apt install apache2 -y
sudo systemctl start apache2 && sudo systemctl enable apache2
```
Validate: `http://EC2-Public-IP` → Apache default page appears.

---

#### LEVEL 2 — Intermediate

**Task 6 – Create Private Subnets**

| Subnet | AZ | CIDR |
|---|---|---|
| Private-Subnet-A | ap-south-1a | 10.0.11.0/24 |
| Private-Subnet-B | ap-south-1b | 10.0.12.0/24 |

**Task 7 – Configure NAT Gateway**
1. Create NAT Gateway: Subnet = `Public-Subnet-A`, Elastic IP = Allocate New
2. Create Private RT → Add Route: `0.0.0.0/0 → NAT Gateway`
3. Associate `Private-Subnet-A` + `Private-Subnet-B`

Validate: SSH to private EC2 → `sudo apt update` should succeed.

**Task 8 – Configure Security Groups**

| SG | Type | Port | Source |
|---|---|---|---|
| ALB-SG | HTTP/HTTPS | 80/443 | 0.0.0.0/0 |
| Bastion-SG | SSH | 22 | My Public IP |
| WebServer-SG | HTTP | 80 | ALB-SG |
| WebServer-SG | SSH | 22 | Bastion-SG |

**Task 9 – Configure Bastion Host**
1. Launch EC2: `Bastion-Host`, Subnet: `Public-Subnet-A`, Public IP: Enabled, SG: `Bastion-SG`
2. `ssh -i key.pem ubuntu@Bastion-Public-IP`
3. `ssh -i key.pem ubuntu@Private-IP`

---

#### LEVEL 3 — Advanced

**Task 10 – Multi-AZ Architecture**
1. Create subnets in both AZs (`ap-south-1a` and `ap-south-1b`)
2. Deploy EC2 in each AZ for redundancy

**Task 11 – Application Load Balancer**

Create Target Group:
| Setting | Value |
|---|---|
| Name | Apache-TG |
| Target Type | Instance |
| Protocol/Port | HTTP / 80 |
| Health Check Path | / |

Create ALB:
| Setting | Value |
|---|---|
| Name | Production-ALB |
| Scheme | Internet-facing |
| VPC/Subnets | My-VPC / Public-Subnet-A + B |
| Security Group | ALB-SG |

Register Web Server 1 + Web Server 2 as targets.  
Validate: `http://ALB-DNS-Name` → refresh to see traffic distribution.

**Task 12 – Auto Scaling Group**

Launch Template:
```bash
#!/bin/bash
apt update -y && apt install apache2 -y
systemctl start apache2 && systemctl enable apache2
echo "<h1>Apache Web Server from $(hostname)</h1>" > /var/www/html/index.html
```

| Setting | Value |
|---|---|
| Name | Apache-ASG |
| Launch Template | Apache-LT |
| Subnets | Private-Subnet-A + B |
| Target Group | Apache-TG |
| Desired/Min/Max | 2 / 2 / 4 |

---

#### LEVEL 4 — Full Production Architecture

**Task 13 – Deploy Highly Available Apache Web Application**

```
Users → Route53 → ALB → Private Apache EC2 (Auto Scaling Group)
Admin → Bastion Host → Private EC2
Private EC2 → NAT Gateway → Internet
```

| Step | Action | Key Config |
|---|---|---|
| 1 | Create VPC | Production-VPC, 10.0.0.0/16 |
| 2 | Public Subnets | 10.0.1.0/24 (1a), 10.0.2.0/24 (1b) |
| 3 | Private Subnets | 10.0.11.0/24 (1a), 10.0.12.0/24 (1b) |
| 4 | Create + Attach IGW | Production-IGW → Production-VPC |
| 5 | Public Route Table | 0.0.0.0/0 → IGW; associate public subnets |
| 6 | NAT Gateway | Subnet: Public-Subnet-A, new Elastic IP |
| 7 | Private Route Table | 0.0.0.0/0 → NAT; associate private subnets |
| 8 | Security Groups | ALB-SG, Bastion-SG, WebServer-SG |
| 9 | Bastion Host | Public-Subnet-A, public IP, Bastion-SG |
| 10 | Create ALB | Internet-facing, public subnets, ALB-SG |
| 11 | Target Group | HTTP:80, health check: / |
| 12 | Launch Template | Ubuntu, t2.micro, Apache user data |
| 13 | Create ASG | Private subnets, Desired:2, Max:4 |
| 14 | Test | `http://ALB-DNS-Name` → Apache page, refresh for distribution |

---

## Part 4a: VPC Peering

### What is VPC Peering?
A networking connection between two VPCs enabling **private communication** using AWS backbone — no internet, no VPN needed.

**Requirements:**
- VPC CIDR ranges must **NOT overlap**
- Routes must be manually added to both route tables
- Security Groups/NACLs must allow the traffic
- **No transitive peering** (A↔B and B↔C does NOT mean A↔C)

### Implementation Task – VPC Peering

**Scenario:** App servers in Application-VPC need to reach DB servers in Database-VPC.

| VPC | CIDR |
|---|---|
| Application-VPC | 10.0.0.0/16 |
| Database-VPC | 192.168.0.0/16 |

**Steps:**

1. Create Application-VPC (`10.0.0.0/16`) and Database-VPC (`192.168.0.0/16`)
2. Create subnets in each VPC (`App-Subnet: 10.0.1.0/24`, `DB-Subnet: 192.168.1.0/24`)
3. Launch EC2 instances in each subnet

4. Configure Security Groups:

| SG | Type | Port | Source |
|---|---|---|---|
| App-Server-SG | SSH/ICMP | 22/All | My IP / 192.168.0.0/16 |
| DB-Server-SG | SSH/ICMP | 22/All | My IP / 10.0.0.0/16 |

5. Create VPC Peering: VPC Console → Peering Connections → Create

| Setting | Value |
|---|---|
| Name | App-DB-Peering |
| Requester VPC | Application-VPC |
| Accepter VPC | Database-VPC |

6. Accept the peering request from Database-VPC side → Verify Status = `Active`

7. Update Route Tables:
   - Application RT: Add `192.168.0.0/16 → Peering Connection`
   - Database RT: Add `10.0.0.0/16 → Peering Connection`

8. Test: SSH to App-Server → `ping <DB-Private-IP>` → Should succeed

**Troubleshooting:**
| Issue | Likely Cause |
|---|---|
| Ping not working | Missing route or SG blocking ICMP |
| Peering creation failed | Overlapping CIDRs or wrong accepter VPC |
| Route not working | Wrong CIDR or wrong route table association |

---

## Part 4b: AWS CLI — VPC Implementation

### Why AWS CLI?
Enables automation, scripting, faster deployments — preferred for enterprise/DevOps workflows over manual console clicks.

### Phase-by-Phase CLI Commands

**Phase 1 – Create VPC**
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=MyVPC}]'

# Verify
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=MyVPC" --output table
```

**Phase 2 – Internet Gateway**
```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=MyIGW}]'

aws ec2 attach-internet-gateway --internet-gateway-id igw-xxxxxxxx --vpc-id vpc-xxxxxxxx
```

**Phase 3 & 4 – Public + Private Subnets**
```bash
# Public Subnet 1
aws ec2 create-subnet --vpc-id vpc-xxxxxxxx --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet1}]'

# Public Subnet 2
aws ec2 create-subnet --vpc-id vpc-xxxxxxxx --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet2}]'

# Private Subnet 1
aws ec2 create-subnet --vpc-id vpc-xxxxxxxx --cidr-block 10.0.3.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet1}]'

# Private Subnet 2
aws ec2 create-subnet --vpc-id vpc-xxxxxxxx --cidr-block 10.0.4.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet2}]'
```

**Phase 5 – Enable Auto Public IP on Public Subnets**
```bash
aws ec2 modify-subnet-attribute --subnet-id subnet-xxxxxxxx --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id subnet-yyyyyyyy --map-public-ip-on-launch
```

**Phase 6 – Public Route Table**
```bash
aws ec2 create-route-table --vpc-id vpc-xxxxxxxx \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PublicRouteTable}]'

aws ec2 create-route --route-table-id rtb-xxxxxxxx \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxxxxxxx

aws ec2 associate-route-table --subnet-id subnet-xxxxxxxx --route-table-id rtb-xxxxxxxx
aws ec2 associate-route-table --subnet-id subnet-yyyyyyyy --route-table-id rtb-xxxxxxxx
```

**Phase 7 – Private Route Table**
```bash
aws ec2 create-route-table --vpc-id vpc-xxxxxxxx \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PrivateRouteTable}]'
```

**Phase 8 – NAT Gateway**
```bash
aws ec2 allocate-address --domain vpc

aws ec2 create-nat-gateway --subnet-id subnet-xxxxxxxx \
  --allocation-id eipalloc-xxxxxxxx \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=MyNATGateway}]'

# Wait for State = available
aws ec2 describe-nat-gateways
```

**Phase 9 – Private Route Table Routing**
```bash
aws ec2 create-route --route-table-id rtb-yyyyyyyy \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-xxxxxxxx

aws ec2 associate-route-table --subnet-id subnet-xxxxxxxx --route-table-id rtb-yyyyyyyy
aws ec2 associate-route-table --subnet-id subnet-yyyyyyyy --route-table-id rtb-yyyyyyyy
```

**Phase 10 & 11 – Security Groups**
```bash
# Bastion SG
aws ec2 create-security-group --group-name BastionSG \
  --description "Security group for Bastion Host" --vpc-id vpc-xxxxxxxx
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

# Private SG (SSH only from Bastion)
aws ec2 create-security-group --group-name PrivateSG \
  --description "Security group for private EC2" --vpc-id vpc-xxxxxxxx
aws ec2 authorize-security-group-ingress --group-id sg-yyyyyyyy \
  --protocol tcp --port 22 --source-group sg-xxxxxxxx
```

**Phase 12 – Key Pair**
```bash
aws ec2 create-key-pair --key-name CloudShellKey \
  --query 'KeyMaterial' --output text > CloudShellKey.pem
chmod 400 CloudShellKey.pem
```

**Phase 13 – Launch Bastion Host**
```bash
aws ec2 run-instances --image-id ami-07a00cf47dbbc844c --instance-type t2.micro \
  --key-name CloudShellKey --security-group-ids sg-xxxxxxxx \
  --subnet-id subnet-xxxxxxxx --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=BastionHost}]' --count 1
```

**Phase 14 – SSH to Bastion**
```bash
ssh -i CloudShellKey.pem ubuntu@<PUBLIC_IP>
```

**Phase 15 – Launch Private EC2**
```bash
aws ec2 run-instances --image-id ami-07a00cf47dbbc844c --instance-type t2.micro \
  --key-name CloudShellKey --security-group-ids sg-yyyyyyyy \
  --subnet-id subnet-yyyyyyyy \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=PrivateEC2}]' --count 1
```

**Phase 16 & 17 – Copy PEM + SSH to Private EC2**
```bash
# Copy PEM to Bastion
scp -i CloudShellKey.pem CloudShellKey.pem ubuntu@<PUBLIC_IP>:/home/ubuntu/

# SSH: Bastion → Private EC2
ssh -i CloudShellKey.pem ubuntu@<PUBLIC_IP>
chmod 400 CloudShellKey.pem
ssh -i CloudShellKey.pem ubuntu@<PRIVATE_IP>

# Validate NAT Gateway
sudo apt update   # Should work even without public IP
```

**Cleanup:**
```bash
aws ec2 terminate-instances --instance-ids i-xxxxxxxx
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxxxxxxx
aws ec2 release-address --allocation-id eipalloc-xxxxxxxx
aws ec2 delete-security-group --group-id sg-xxxxxxxx
aws ec2 delete-subnet --subnet-id subnet-xxxxxxxx
aws ec2 delete-route-table --route-table-id rtb-xxxxxxxx
aws ec2 detach-internet-gateway --internet-gateway-id igw-xxxxxxxx --vpc-id vpc-xxxxxxxx
aws ec2 delete-internet-gateway --internet-gateway-id igw-xxxxxxxx
aws ec2 delete-vpc --vpc-id vpc-xxxxxxxx
```

---

## Part 5: AWS Route 53

### 1. DNS & Route 53 Basics

**DNS (Domain Name System)** = Converts domain names to IP addresses.  
`www.google.com → 142.250.x.x`

**Route 53** = AWS's scalable, highly available DNS service (Port 53 = DNS port).

| Feature | Purpose |
|---|---|
| Domain Registration | Buy/manage domains |
| DNS Routing | Route traffic to endpoints |
| Health Checks | Monitor endpoint health |
| Failover | Auto-redirect on failure |

---

### 2. Key Concepts

**Hosted Zone** = Container for DNS records for a domain.
- **Public Hosted Zone** → Internet-accessible (public websites)
- **Private Hosted Zone** → VPC-only (internal apps, e.g., `internal.mycompany.local`)

**DNS Record Types:**
| Record | Maps | Example |
|---|---|---|
| A | Domain → IPv4 | `www.myapp.com → 54.221.x.x` |
| AAAA | Domain → IPv6 | — |
| CNAME | Domain → Domain | `app.co → myalb.amazonaws.com` |
| Alias | Domain → AWS resource | Domain → ALB/CloudFront/S3 |
| MX | Email routing | — |
| TXT | Domain verification, SPF/DKIM | — |

> **Alias Record** is AWS-specific — maps directly to ALB, CloudFront, S3 without needing a fixed IP (ALBs don't have fixed IPs).

---

### 3. Routing Policies

| Policy | How It Works | Use Case |
|---|---|---|
| Simple | Single resource | Basic apps |
| Weighted | % split between targets | A/B testing, canary deploys |
| Latency | Routes to lowest-latency region | Global performance |
| Failover | Primary → Secondary on failure | Disaster recovery |
| Geolocation | Routes based on user location | Region-specific content |
| Multi-Value | Returns multiple healthy IPs | Basic load balancing |

---

### 4. Health Checks
Route 53 continuously monitors endpoints. If unhealthy → stops routing traffic there.

```
Route53 → Checks Application → Healthy? Route traffic : Stop routing
```

---

### 5. Practical Tasks

#### LEVEL 1 — Beginner

**Task 1 – Create Public Hosted Zone**
1. Route 53 Console → Hosted Zones → Create Hosted Zone
2. Domain Name: `mycompany.com`, Type: Public Hosted Zone
3. Verify NS + SOA records created automatically

**Task 2 – Create A Record**
| Setting | Value |
|---|---|
| Record Name | www |
| Record Type | A |
| Value | EC2 Public IP |

Validate: `http://www.mycompany.com` loads the website.

**Task 3 – Alias Record to ALB**
| Setting | Value |
|---|---|
| Record Type | A |
| Alias | Enabled |
| Target | Application Load Balancer |

Validate: `www.mycompany.com` traffic reaches ALB.

---

#### LEVEL 2 — Intermediate

**Task 4 – Weighted Routing**

| Record | Target | Weight |
|---|---|---|
| app.mycompany.com | Production ALB | 80 |
| app.mycompany.com | Testing ALB | 20 |

Use case: Canary deployments, gradual migrations.

**Task 5 – Failover Routing**
1. Create Health Check → Monitor Primary ALB
2. Create Primary Record: Failover Type = `Primary`, Health Check = Enabled
3. Create Secondary Record: Failover Type = `Secondary`

Validate: Stop primary app → Traffic auto-shifts to secondary.

---

#### LEVEL 3 — Advanced

**Task 6 – Latency-Based Routing**

| Record | Region | Target |
|---|---|---|
| app.mycompany.com | ap-south-1 (Mumbai) | Mumbai ALB |
| app.mycompany.com | us-east-1 (Virginia) | Virginia ALB |

India users → Mumbai region. US users → Virginia region.

**Task 7 – Private Hosted Zone**
1. Create Hosted Zone: `internal.mycompany.local`, Type: Private, Associate: Production-VPC
2. Create A Record: `db.internal.mycompany.local → Private EC2 IP`

Validate: Private EC2 resolves `db.internal.mycompany.local` successfully.

---

### 6. Troubleshooting

| Issue | Likely Cause |
|---|---|
| Domain not resolving | Wrong NS records, propagation delay, incorrect A record |
| Website not loading | ALB unhealthy, wrong target IP, Security Group issue |
| Failover not working | Health check misconfigured, secondary record missing |
| Private DNS not working | Wrong VPC association |

---

### 7. Traffic Flow Summary

**Standard:**
```
User → Route53 → ALB → EC2 Instances
```

**Multi-Region:**
```
User → Route53 (Latency policy) → Closest AWS Region → Application
```

**Failover:**
```
User → Route53 → Primary ALB (healthy)
              → Secondary ALB (if primary fails)
```
