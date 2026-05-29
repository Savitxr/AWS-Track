# AWS ALB & NLB — Advanced Load Balancer Routing

---

## 1. ALB vs NLB — Concept Overview

### Application Load Balancer (ALB)
- Operates at **Layer 7** (HTTP/HTTPS — Application Layer)
- Can inspect request content: **host headers, URL paths, HTTP methods, source IPs, query strings, headers**
- Supports: host-based routing, path-based routing, HTTP method routing, source IP routing
- Supports **SSL/TLS termination** (decrypts HTTPS at the ALB)
- Targets: EC2, ECS, Lambda, IP addresses

### Network Load Balancer (NLB)
- Operates at **Layer 4** (TCP/UDP — Transport Layer)
- Routes based on **IP + Port** only — does NOT inspect HTTP content
- Extremely **high performance** — millions of requests per second, ultra-low latency
- Supports **static Elastic IPs** (useful for whitelisting)
- Supports **TLS termination** at Layer 4
- Targets: EC2, IP addresses, ALB (NLB in front of ALB pattern)

### When to Use Which

| Scenario | Use |
|---|---|
| HTTP/HTTPS apps needing content-based routing | ALB |
| High-performance TCP/UDP (gaming, IoT, financial) | NLB |
| Need static IP for firewall whitelisting | NLB |
| WebSockets, HTTP/2 | ALB |
| NFS file server (TCP 2049) | NLB |
| SSL termination + smart routing | ALB |

---

## 2. ALB Listener Rules — How They Work

An ALB **Listener** listens on a port (80 or 443).  
Each listener has **rules** evaluated top-to-bottom by priority number.  
Each rule has:
- **Conditions** → what to match (host, path, method, source IP, header, query string)
- **Actions** → what to do (forward to target group, redirect, return fixed response)

```
ALB Listener (port 80/443)
  │
  ├── Rule Priority 1: IF host = api.myapp.com → Forward to API-TG
  ├── Rule Priority 2: IF path = /images/*     → Forward to Static-TG
  ├── Rule Priority 3: IF method = DELETE       → Return 403
  ├── Rule Priority 4: IF source IP in 10.0.0.0/8 → Forward to Premium-TG
  └── Default Rule:    Forward to Standard-TG
```

---

## 3. Task 1 — Host-Based Routing with Route 53 (ALB)

### Concept
Host-based routing routes traffic based on the **hostname** in the HTTP Host header.  
Different subdomains pointing to the **same ALB** get routed to different backend target groups.

Example:
- `app.mycompany.com` → App-TG (application servers)
- `admin.mycompany.com` → Admin-TG (admin servers)
- `api.mycompany.com` → API-TG (API servers)

> Route 53 points **all subdomains** to the **same ALB DNS name** via Alias records.  
> The ALB differentiates them using the Host header in listener rules.

---

### Architecture

```
Route 53
  ├── app.mycompany.com   → Alias → ALB DNS name
  ├── admin.mycompany.com → Alias → ALB DNS name
  └── api.mycompany.com   → Alias → ALB DNS name

ALB Listener :80
  ├── Rule P10: Host = api.mycompany.com   → API-TG
  ├── Rule P20: Host = admin.mycompany.com → Admin-TG
  ├── Rule P30: Host = app.mycompany.com   → App-TG
  └── Default Rule                         → Default-TG (or 404)
```

---

### Implementation Steps

#### Step 1 — Launch EC2 Instances

| Instance | Purpose | Subnet |
|---|---|---|
| App-Server-1 | Main web application | Private-Subnet-A |
| App-Server-2 | Main web application | Private-Subnet-B |
| Admin-Server | Admin panel | Private-Subnet-A |
| API-Server | REST API | Private-Subnet-B |

**App Servers:**
```bash
sudo apt update -y && sudo apt install apache2 -y
sudo systemctl enable apache2 && sudo systemctl start apache2
echo "<h1>App Server: $(hostname)</h1>" | sudo tee /var/www/html/index.html
```

**Admin Server:**
```bash
sudo apt install apache2 -y && sudo systemctl start apache2
sudo mkdir -p /var/www/html
echo "<h1>Admin Panel — $(hostname)</h1>" | sudo tee /var/www/html/index.html
```

**API Server:**
```bash
sudo apt install nodejs npm -y
cat <<'EOF' > /home/ubuntu/api.js
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({ service: 'API', host: req.headers.host, path: req.url }));
}).listen(3000, () => console.log('API on :3000'));
EOF
node /home/ubuntu/api.js &
```

---

#### Step 2 — Create Target Groups

| Target Group | Protocol | Port | Health Check | Registered Instances |
|---|---|---|---|---|
| App-TG | HTTP | 80 | / | App-Server-1, App-Server-2 |
| Admin-TG | HTTP | 80 | / | Admin-Server |
| API-TG | HTTP | 3000 | / | API-Server |

---

#### Step 3 — Create the ALB

| Setting | Value |
|---|---|
| Name | Host-ALB |
| Scheme | Internet-facing |
| VPC / Subnets | Your VPC / Public-Subnet-A + B |
| Security Group | ALB-SG (HTTP:80 from 0.0.0.0/0) |

---

#### Step 4 — Add Listener Rules (Host-Based)

Navigate to: **EC2 → Load Balancers → Host-ALB → Listeners → View/Edit Rules**

**Rule 1 — API subdomain (Priority 10):**
| Field | Value |
|---|---|
| Condition | Host header = `api.mycompany.com` |
| Action | Forward → API-TG |

**Rule 2 — Admin subdomain (Priority 20):**
| Field | Value |
|---|---|
| Condition | Host header = `admin.mycompany.com` |
| Action | Forward → Admin-TG |

**Rule 3 — App subdomain (Priority 30):**
| Field | Value |
|---|---|
| Condition | Host header = `app.mycompany.com` |
| Action | Forward → App-TG |

**Default Rule:**
| Action |
|---|
| Return fixed response: 404, `Not Found` |

---

#### Step 5 — Configure Route 53

In your hosted zone (`mycompany.com`), create Alias records pointing all subdomains to the **same ALB**:

| Record Name | Type | Target |
|---|---|---|
| `app.mycompany.com` | A (Alias) | Host-ALB DNS name |
| `admin.mycompany.com` | A (Alias) | Host-ALB DNS name |
| `api.mycompany.com` | A (Alias) | Host-ALB DNS name |

---

#### Step 6 — Validate

```bash
# App subdomain
curl http://app.mycompany.com
# Expected: <h1>App Server: ip-10-0-x-x</h1>

# Admin subdomain
curl http://admin.mycompany.com
# Expected: <h1>Admin Panel — ip-10-0-x-x</h1>

# API subdomain
curl http://api.mycompany.com/
# Expected: {"service":"API","host":"api.mycompany.com","path":"/"}

# Unknown host → default rule
curl http://unknown.mycompany.com --header "Host: unknown.mycompany.com"
# Expected: 404
```

---

## 4. Task 2 — Path-Based & HTTP Method-Based Routing

### Concept

**Path-based routing** = Route based on the URL path.  
**Method-based routing** = Route or block/redirect based on the HTTP verb (GET, PUT, POST, DELETE, etc.).

Both are ALB **listener rule conditions** that can be combined within a single rule (AND logic).

---

### What Was Practised

| Route | Method | Behaviour |
|---|---|---|
| `/fruit` | GET | Fruit server response |
| `/cart` | GET | Cart server response |
| `/fruit` | PUT | Blocked — 403 Fixed Response |

---

### Architecture

```
ALB Listener :80
  ├── Rule 1 [Priority 10]: Method=PUT AND Path=/fruit → Fixed Response 403
  ├── Rule 2 [Priority 20]: Path=/fruit               → Fruit-TG
  ├── Rule 3 [Priority 30]: Path=/cart                → Cart-TG
  └── Default Rule                                    → Default-TG
```

> Rule 1 must have higher priority than Rule 2.  
> If PUT /fruit hit Rule 2 first, it would forward instead of blocking.

---

### Implementation Steps

#### Step 1 — Launch EC2 Instances and Set Up Servers

**Fruit Server:**
```bash
sudo apt update -y && sudo apt install apache2 -y
sudo systemctl start apache2 && sudo systemctl enable apache2
sudo mkdir -p /var/www/html/fruit
echo "<h1>Fruit Page 🍎 — $(hostname)</h1>" | sudo tee /var/www/html/fruit/index.html
```

Configure Apache to serve `/fruit`:
```bash
# Apache serves /var/www/html by default; /fruit path is a subdirectory
# Ensure AllowOverride is set if using .htaccess, otherwise default config works
sudo systemctl restart apache2
```

**Cart Server:**
```bash
sudo apt update -y && sudo apt install apache2 -y
sudo systemctl start apache2 && sudo systemctl enable apache2
sudo mkdir -p /var/www/html/cart
echo "<h1>Cart Page 🛒 — $(hostname)</h1>" | sudo tee /var/www/html/cart/index.html
sudo systemctl restart apache2
```

**Default Server (fallback):**
```bash
sudo apt install apache2 -y && sudo systemctl start apache2
echo "<h1>Default Page — $(hostname)</h1>" | sudo tee /var/www/html/index.html
```

---

#### Step 2 — Create Target Groups

| Target Group | Protocol | Port | Health Check Path | Registered Instance |
|---|---|---|---|---|
| Fruit-TG | HTTP | 80 | /fruit/ | Fruit-Server |
| Cart-TG | HTTP | 80 | /cart/ | Cart-Server |
| Default-TG | HTTP | 80 | / | Default-Server |

---

#### Step 3 — Create ALB

| Setting | Value |
|---|---|
| Name | Path-ALB |
| Scheme | Internet-facing |
| VPC / Subnets | Your VPC / Public-Subnet-A + B |
| Security Group | ALB-SG (HTTP:80 from 0.0.0.0/0) |

Attach `Default-TG` as the default action.

---

#### Step 4 — Add Listener Rules

Navigate to: **EC2 → Load Balancers → Path-ALB → Listeners → View/Edit Rules**

**Rule 1 — Block PUT /fruit (Priority 10):**
| Field | Value |
|---|---|
| Condition 1 | HTTP request method = `PUT` |
| Condition 2 | Path pattern = `/fruit` |
| Action | Return fixed response: Status `403`, Body `PUT not allowed on /fruit` |

> Both conditions in the same rule = **AND logic** — both must be true to trigger.

**Rule 2 — /fruit path (Priority 20):**
| Field | Value |
|---|---|
| Condition | Path pattern = `/fruit` |
| Action | Forward → Fruit-TG |

**Rule 3 — /cart path (Priority 30):**
| Field | Value |
|---|---|
| Condition | Path pattern = `/cart` |
| Action | Forward → Cart-TG |

**Default Rule:**
| Action |
|---|
| Forward → Default-TG |

---

#### Step 5 — Validate

```bash
ALB_DNS="your-alb-dns.ap-south-1.elb.amazonaws.com"

# /fruit path — GET (should reach Fruit server)
curl http://$ALB_DNS/fruit
# → <h1>Fruit Page 🍎 — ip-10-0-x-x</h1>

# /cart path — GET (should reach Cart server)
curl http://$ALB_DNS/cart
# → <h1>Cart Page 🛒 — ip-10-0-x-x</h1>

# /fruit path — PUT (should be blocked)
curl -X PUT http://$ALB_DNS/fruit
# → 403 PUT not allowed on /fruit

# Default path
curl http://$ALB_DNS/
# → <h1>Default Page — ip-10-0-x-x</h1>
```

---



## 5. Task 3 — Source IP-Based Routing (Premium vs Standard)

### Concept

Source IP routing uses the **client's IP address** as the routing condition.  
A defined CIDR range (e.g., corporate network, VIP users) gets routed to a **premium page/server**.  
All other IPs get the standard page.

> **Important:** ALB sees the real client IP via the `X-Forwarded-For` header.  
> The **Source IP** condition in ALB rules matches against the actual client IP.

---

### Architecture

```
Internet Users
  │
  ├── IP in 203.0.113.0/24 (Corporate / VIP CIDR)
  │     → ALB Rule: Source IP matches → Premium-TG
  │
  └── All other IPs
        → ALB Default Rule → Standard-TG
```

---

### Implementation Steps

#### Step 1 — Launch EC2 Instances

**Premium Web Server:**
```bash
sudo apt install apache2 -y && sudo systemctl start apache2
sudo mkdir -p /var/www/html
cat <<'EOF' | sudo tee /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>Premium Access</title>
<style>
  body { background: linear-gradient(135deg, #1a1a2e, #16213e);
         color: #FFD700; font-family: Arial, sans-serif;
         display: flex; align-items: center; justify-content: center;
         height: 100vh; margin: 0; }
  .card { text-align: center; padding: 40px; border: 2px solid #FFD700;
          border-radius: 12px; }
  h1 { font-size: 2.5rem; margin-bottom: 10px; }
  p  { color: #ccc; }
</style></head>
<body>
  <div class="card">
    <h1>⭐ Premium Access</h1>
    <p>Welcome, VIP user. You have access to premium content.</p>
    <p>Server: <strong>Premium-Server</strong></p>
  </div>
</body></html>
EOF
```

**Standard Web Server:**
```bash
sudo apt install apache2 -y && sudo systemctl start apache2
cat <<'EOF' | sudo tee /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>Standard Access</title>
<style>
  body { background-color: #f4f4f4; font-family: Arial, sans-serif;
         display: flex; align-items: center; justify-content: center;
         height: 100vh; margin: 0; }
  .card { text-align: center; padding: 40px; background: white;
          border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
</style></head>
<body>
  <div class="card">
    <h1>Standard Access</h1>
    <p>Welcome! You are viewing the standard page.</p>
    <p>Upgrade your plan for premium content.</p>
  </div>
</body></html>
EOF
```

---

#### Step 2 — Create Target Groups

| Target Group | Port | Registered Instance |
|---|---|---|
| Premium-TG | 80 | Premium-Server |
| Standard-TG | 80 | Standard-Server |

Health check path: `/` for both.

---

#### Step 3 — Configure Security Groups

**ALB-SG:**
| Type | Port | Source |
|---|---|---|
| HTTP | 80 | 0.0.0.0/0 |

**WebServer-SG:**
| Type | Port | Source |
|---|---|---|
| HTTP | 80 | ALB-SG |
| SSH | 22 | Bastion-SG |

---

#### Step 4 — Create ALB Listener Rules

**Rule 1 — Premium CIDR (Priority 10):**
| Field | Value |
|---|---|
| Condition | Source IP = `203.0.113.0/24` |
| Action | Forward → Premium-TG |

> Replace `203.0.113.0/24` with your actual VIP/corporate CIDR.  
> You can add multiple CIDRs by adding more values to the same condition.

**Default Rule:**
| Action |
|---|
| Forward → Standard-TG |

---

#### Step 5 — Validate

```bash
ALB_DNS="your-alb-dns.ap-south-1.elb.amazonaws.com"

# From a VIP IP (simulate with EC2 in the CIDR range or VPN):
curl http://$ALB_DNS/
# → Premium Access page (gold theme)

# From any other IP:
curl http://$ALB_DNS/
# → Standard Access page (white theme)

# Check which server responded (add to server response header):
curl -I http://$ALB_DNS/
# Look at: X-Served-By or Server header
```

**Multi-CIDR Example (add both corporate and partner CIDRs to premium):**
| Condition | Values |
|---|---|
| Source IP | `203.0.113.0/24`, `198.51.100.0/24`, `10.100.0.0/16` |

> All three CIDRs in a single Source IP condition are evaluated as **OR** (any match = premium).

---

## 6. Task 4 — SSL Termination at ALB (Conceptual — ACM + Route 53)

### Concept

**SSL Termination** = The ALB decrypts HTTPS traffic from clients, then forwards plain HTTP to backend EC2 instances.

Benefits:
- Backend servers are offloaded from TLS processing
- Simpler certificate management (one cert on ALB, not on every server)
- ALB can then inspect/route decrypted HTTP content

```
Client (HTTPS)  →  ALB (decrypts TLS)  →  EC2 (plain HTTP)
       ↑
   SSL cert from ACM
```

---

### Components Involved

| Component | Role |
|---|---|
| **ACM (AWS Certificate Manager)** | Issues and manages free SSL/TLS certificates |
| **Route 53** | DNS — points your domain to the ALB |
| **ALB Listener (port 443)** | Terminates SSL using the ACM certificate |
| **ALB Listener (port 80)** | Redirects HTTP → HTTPS |
| **EC2 Instances** | Receive plain HTTP from ALB (no TLS setup needed) |

---

### How It Works — Step by Step

```
1. User types: https://www.mycompany.com

2. Route 53:
   www.mycompany.com → Alias → ALB DNS name

3. ALB Listener (port 443):
   - Presents ACM SSL certificate to the client
   - TLS handshake completes
   - Traffic is decrypted

4. ALB forwards decrypted HTTP to backend EC2 on port 80

5. EC2 responds with HTTP → ALB → re-encrypts (optional) → Client
```

---

### Conceptual Implementation Steps

#### Step 1 — Request a Certificate in ACM

Navigate to: **AWS Console → Certificate Manager → Request a Certificate**

| Setting | Value |
|---|---|
| Certificate Type | Public certificate |
| Domain Name | `mycompany.com` |
| Additional Names | `*.mycompany.com` (wildcard — covers all subdomains) |
| Validation Method | DNS Validation (recommended) |

> ACM will provide a **CNAME record** to add to Route 53 for domain ownership proof.

---

#### Step 2 — Validate Certificate via Route 53

After requesting:
1. ACM shows a CNAME record to add (e.g., `_abc123.mycompany.com → _xyz.acm-validations.aws.`)
2. In Route 53 → add this CNAME record to your hosted zone
3. ACM automatically detects it → Status changes to **Issued** (takes ~5 minutes)

> If your domain is in Route 53, ACM can auto-add the CNAME via the **"Create records in Route 53"** button.

---

#### Step 3 — Add HTTPS Listener to ALB

In **ALB → Listeners → Add Listener:**

| Setting | Value |
|---|---|
| Protocol | HTTPS |
| Port | 443 |
| Default Action | Forward → your Target Group |
| SSL Certificate | Select ACM certificate (mycompany.com) |
| Security Policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` (recommended) |

---

#### Step 4 — Redirect HTTP → HTTPS (Best Practice)

Edit the existing port 80 listener:

| Setting | Value |
|---|---|
| Default Action | **Redirect** to HTTPS |
| Redirect URL | HTTPS, port 443, status 301 (Permanent) |

This ensures all `http://` requests are automatically upgraded to `https://`.

---

#### Step 5 — Update Route 53

Ensure your domain has an Alias record pointing to the ALB:

| Record | Type | Target |
|---|---|---|
| `mycompany.com` | A (Alias) | ALB DNS name |
| `www.mycompany.com` | A (Alias) | ALB DNS name |

---

### End-to-End SSL Flow Diagram

```
Client Browser
    │
    │ HTTPS (TLS 1.3)
    ▼
Route 53: www.mycompany.com → ALB DNS
    │
    ▼
ALB Listener :443
    ├── Presents ACM Certificate (mycompany.com)
    ├── TLS Handshake with browser
    ├── Decrypts HTTPS traffic
    │
    ▼ Plain HTTP
EC2 Instance (Apache/Nginx on :80)
    │
    ▼ HTTP Response
ALB (forwards response back to client over TLS)
    │
    ▼
Client Browser (sees HTTPS, green padlock)
```

---

### Security Policy Selection

| Policy | TLS Versions | Use Case |
|---|---|---|
| `ELBSecurityPolicy-TLS13-1-2-2021-06` | TLS 1.2 + 1.3 | Recommended (modern, secure) |
| `ELBSecurityPolicy-2016-08` | TLS 1.0 + 1.2 | Legacy compatibility only |
| `ELBSecurityPolicy-FS-1-2-Res-2020-10` | TLS 1.2 + Forward Secrecy | High security requirement |

---

### What ACM Does NOT Do

| NOT covered by ACM | Why |
|---|---|
| Certificate on EC2 instances | ACM only installs on AWS managed services (ALB, CloudFront, API GW) |
| On-premise certificate management | Use your own CA or Let's Encrypt |
| Self-signed certificates | ACM issues publicly trusted certificates |

---

## 7. Combined Architecture — All Routing Types Together

```
Route 53
  ├── app.mycompany.com   → Alias → ALB (HTTPS:443 with ACM cert)
  ├── admin.mycompany.com → Alias → ALB (same DNS)
  └── api.mycompany.com   → Alias → ALB (same DNS)

ALB Listener :80  →  301 Redirect to HTTPS
ALB Listener :443 (ACM SSL Terminated)
  │
  ├── Rule P10: Source IP = 203.0.113.0/24            → Premium-TG
  ├── Rule P20: Method = DELETE                        → 403 Fixed Response
  ├── Rule P30: Method = POST + Path = /api/upload     → Upload-TG
  ├── Rule P40: Host = api.mycompany.com               → API-TG
  ├── Rule P50: Host = admin.mycompany.com             → Admin-TG
  ├── Rule P60: Path = /images/*                       → Static-TG
  └── Default:                                         → Standard-TG (Web-TG)
```

---

## 8. Troubleshooting Reference

| Issue | Likely Cause | Fix |
|---|---|---|
| ALB rule not matching | Priority order wrong | Check rule priorities; lower number = higher priority |
| Host-based rule not working | Wrong Host header value | Verify exact subdomain matches the rule condition (case-insensitive) |
| Source IP rule not working | Traffic behind NAT/proxy | Check `X-Forwarded-For` header; ensure client IP is preserved |
| 502 Bad Gateway | Target unhealthy | Check target group health; verify app is running on the correct port |
| HTTPS cert not showing | ACM cert not validated | Verify CNAME record added in Route 53; wait for Issued status |
| HTTP not redirecting to HTTPS | Listener action not set | Ensure port 80 listener default action = Redirect to HTTPS 443 |
| DELETE method not blocked | Rule priority too low | Set the DELETE block rule to the lowest priority number (evaluated first) |
| POST /api/upload going to wrong TG | Rule priority conflict | Ensure combined method+path rule has higher priority than the path-only rule |
