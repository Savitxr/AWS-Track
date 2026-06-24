#!/bin/bash
# =============================================================================
# FanVault v2 — Backend EC2 Bootstrap Script (MONOLITHIC)
# Tier   : Application (Identity + Commerce on same instance)
# Ports  : 3001 (fanvault-user-auth-service)
#          3002 (fanvault-commerce-service)
# Target : ALB identity-tg → GET :3001/health → HTTP 200
#          ALB commerce-tg → GET :3002/health → HTTP 200
#
# ALB Routing (unchanged):
#   /api/auth/*     → identity-tg (port 3001)
#   /api/users/*    → identity-tg (port 3001)
#   /api/products/* → commerce-tg (port 3002)
#   /api/orders/*   → commerce-tg (port 3002)
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/fanvault-backend-bootstrap.log | logger -t fanvault-backend -s 2>/dev/console) 2>&1

echo "========================================================"
echo " FanVault Backend Bootstrap — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "========================================================"

# ── 1. System packages ────────────────────────────────────────────────────────
echo "[1/7] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git awscli

# ── 2. Install Node.js 20.x ───────────────────────────────────────────────────
echo "[2/7] Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node --version
npm --version

# ── 3. Install PM2 (process manager with systemd integration) ─────────────────
echo "[3/7] Installing PM2..."
npm install -g pm2

# ── 4. Fetch configuration from SSM Parameter Store ──────────────────────────
# Required SSM parameters (create these in AWS Console or via Terraform):
#   /fanvault/git/repo_url            → git clone URL
#   /fanvault/git/branch              → e.g. main
#   /fanvault/app/cors_origin         → e.g. https://fanvault.example.com
#   /fanvault/app/jwt_secret          → 32+ char random string (SecureString)
#   /fanvault/app/jwt_refresh_secret  → 32+ char random string (SecureString)
#   /fanvault/dynamodb/table_users    → fanvault-users
#   /fanvault/dynamodb/table_profiles → fanvault-profiles
#   /fanvault/dynamodb/table_products → fanvault-products
#   /fanvault/dynamodb/table_orders   → fanvault-orders
#   /fanvault/s3/bucket               → fanvault-architecture-<account-id>
#   /fanvault/s3/region               → us-east-1

echo "[4/7] Fetching configuration from SSM Parameter Store..."
AWS_REGION="${aws_region:-us-east-1}"

ssm_get() {
    aws ssm get-parameter \
        --region "$AWS_REGION" \
        --name "$1" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text 2>/dev/null || echo "${2:-}"
}

GIT_REPO=$(ssm_get "/fanvault/git/repo_url"            "https://github.com/Savitxr/Fanvault-v2.git")
GIT_BRANCH=$(ssm_get "/fanvault/git/branch"             "main")
CORS_ORIGIN=$(ssm_get "/fanvault/app/cors_origin"       "http://localhost")
JWT_SECRET=$(ssm_get "/fanvault/app/jwt_secret"         "CHANGE_ME_MIN_32_CHARS")
JWT_REFRESH_SECRET=$(ssm_get "/fanvault/app/jwt_refresh_secret" "CHANGE_ME_REFRESH_MIN_32")
TABLE_USERS=$(ssm_get "/fanvault/dynamodb/table_users"    "fanvault-users")
TABLE_PROFILES=$(ssm_get "/fanvault/dynamodb/table_profiles" "fanvault-profiles")
TABLE_PRODUCTS=$(ssm_get "/fanvault/dynamodb/table_products" "fanvault-products")
TABLE_ORDERS=$(ssm_get "/fanvault/dynamodb/table_orders"        "fanvault-orders")
TABLE_AUDIT_LOGS=$(ssm_get "/fanvault/dynamodb/table_audit_logs" "fanvault-audit-logs")
TABLE_METADATA=$(ssm_get "/fanvault/dynamodb/table_metadata"     "fanvault-metadata")
EB_BUS_NAME=$(ssm_get "/fanvault/eventbridge/bus_name"           "fanvault-event-bus")
S3_BUCKET=$(ssm_get "/fanvault/s3/bucket"                "fanvault-architecture")
S3_REGION=$(ssm_get "/fanvault/s3/region"                "$AWS_REGION")

# SNS Topic ARNs
SNS_LOW_INVENTORY=$(ssm_get "/fanvault/sns/topic_low_inventory" "")
SNS_ORDER_FAILURE=$(ssm_get "/fanvault/sns/topic_order_failure" "")
SNS_PRODUCT_UPLOAD=$(ssm_get "/fanvault/sns/topic_product_upload_failure" "")
SNS_ADMIN_OPERATIONAL=$(ssm_get "/fanvault/sns/topic_admin_operational_alert" "")

echo "  Repo    : $GIT_REPO  (branch: $GIT_BRANCH)"
echo "  DDB     : users=$TABLE_USERS | profiles=$TABLE_PROFILES"
echo "  DDB     : products=$TABLE_PRODUCTS | orders=$TABLE_ORDERS"

# ── 5. Clone repo and install dependencies ────────────────────────────────────
echo "[5/7] Cloning repository..."
APP_BASE="/var/www/fanvault"
rm -rf "$APP_BASE"
mkdir -p "$APP_BASE"
git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO" /tmp/fanvault-repo

# ── Identity Service ──────────────────────────────────────────────────────────
echo "  Installing fanvault-user-auth-service..."
cp -r /tmp/fanvault-repo/fanvault-user-auth-service "$APP_BASE/fanvault-user-auth-service"
cd "$APP_BASE/fanvault-user-auth-service"
npm install --omit=dev

cat > .env << ENV
# Auto-generated by EC2 user_data bootstrap — $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# DO NOT edit manually — re-run bootstrap or update SSM parameters instead.
NODE_ENV=production
PORT=3001

# DynamoDB (replaces MongoDB)
AWS_REGION=${AWS_REGION}
DYNAMODB_TABLE_USERS=${TABLE_USERS}
DYNAMODB_TABLE_PROFILES=${TABLE_PROFILES}

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
JWT_REFRESH_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=${CORS_ORIGIN}
ENV

echo "  ✅ fanvault-user-auth-service configured."

# ── Commerce Service ──────────────────────────────────────────────────────────
echo "  Installing fanvault-commerce-service..."
cp -r /tmp/fanvault-repo/fanvault-commerce-service "$APP_BASE/fanvault-commerce-service"
cd "$APP_BASE/fanvault-commerce-service"
npm install --omit=dev

cat > .env << ENV
# Auto-generated by EC2 user_data bootstrap — $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# DO NOT edit manually — re-run bootstrap or update SSM parameters instead.
NODE_ENV=production
PORT=3002

# DynamoDB (replaces MongoDB)
AWS_REGION=${AWS_REGION}
DYNAMODB_TABLE_PRODUCTS=${TABLE_PRODUCTS}
DYNAMODB_TABLE_ORDERS=${TABLE_ORDERS}
DYNAMODB_TABLE_AUDIT_LOGS=${TABLE_AUDIT_LOGS}
DYNAMODB_TABLE_METADATA=${TABLE_METADATA}
EVENTBRIDGE_BUS_NAME=${EB_BUS_NAME}

# SNS Topic ARNs
SNS_TOPIC_LOW_INVENTORY=${SNS_LOW_INVENTORY}
SNS_TOPIC_ORDER_FAILURE=${SNS_ORDER_FAILURE}
SNS_TOPIC_PRODUCT_UPLOAD_FAILURE=${SNS_PRODUCT_UPLOAD}
SNS_TOPIC_ADMIN_OPERATIONAL_ALERT=${SNS_ADMIN_OPERATIONAL}

# JWT (must match identity service — verification only, no signing here)
JWT_SECRET=${JWT_SECRET}

# S3 (product image proxy)
SSM_S3_BUCKET_PATH=/fanvault/s3/bucket
SSM_S3_REGION_PATH=/fanvault/s3/region

# CORS
CORS_ORIGIN=${CORS_ORIGIN}
ENV

echo "  ✅ fanvault-commerce-service configured."

# ── 6. Start both services via PM2 ───────────────────────────────────────────
echo "[6/7] Starting services via PM2..."
cd "$APP_BASE"

# Start Identity Service
pm2 start src/index.js \
    --name "fanvault-identity" \
    --cwd fanvault-user-auth-service \
    --log /var/log/fanvault-identity.log \
    --time

# Start Commerce Service
pm2 start src/index.js \
    --name "fanvault-commerce" \
    --cwd fanvault-commerce-service \
    --log /var/log/fanvault-commerce.log \
    --time

# Save PM2 process list so it survives reboots
pm2 save

# Generate and install systemd startup script so PM2 starts at boot
env PATH="$PATH:/usr/bin" pm2 startup systemd -u root --hp /root
systemctl enable pm2-root

pm2 status
echo "  ✅ Both services started by PM2."

# ── 7. Health check validation ────────────────────────────────────────────────
echo "[7/7] Running local health checks..."
sleep 8  # Allow Node.js services to initialise before checking

IDENTITY_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)
COMMERCE_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/health)

if [ "$IDENTITY_CODE" = "200" ]; then
    echo "  ✅ Identity service  → HTTP $IDENTITY_CODE  (port 3001)"
else
    echo "  ❌ Identity service  → HTTP $IDENTITY_CODE  (port 3001) — check /var/log/fanvault-identity.log"
fi

if [ "$COMMERCE_CODE" = "200" ]; then
    echo "  ✅ Commerce service  → HTTP $COMMERCE_CODE  (port 3002)"
else
    echo "  ❌ Commerce service  → HTTP $COMMERCE_CODE  (port 3002) — check /var/log/fanvault-commerce.log"
fi

echo "========================================================"
echo " FanVault Backend Bootstrap COMPLETE — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "========================================================"
