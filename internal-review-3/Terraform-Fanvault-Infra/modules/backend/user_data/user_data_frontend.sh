#!/bin/bash
# =============================================================================
# FanVault v2 — Frontend EC2 Bootstrap Script
# Tier   : Presentation (Nginx serving compiled React/Vite SPA)
# Port   : 80 (Nginx)
# Target : ALB frontend-tg health check → GET /index.html → HTTP 200
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/fanvault-frontend-bootstrap.log | logger -t fanvault-frontend -s 2>/dev/console) 2>&1

echo "========================================================"
echo " FanVault Frontend Bootstrap — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "========================================================"

# ── 1. System packages ────────────────────────────────────────────────────────
echo "[1/6] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git nginx unzip awscli

# ── 2. Fetch configuration from SSM Parameter Store ──────────────────────────
# The EC2 Instance Profile must have ssm:GetParameter on /fanvault/* paths.
echo "[2/6] Fetching deployment configuration from SSM..."
AWS_REGION="${aws_region:-us-east-1}"
GIT_REPO=$(aws ssm get-parameter --region "$AWS_REGION" --name "/fanvault/git/repo_url" --query "Parameter.Value" --output text 2>/dev/null || echo "https://github.com/Fanvault-CloudOps/Fanvault-v3-App.git")
GIT_BRANCH=$(aws ssm get-parameter --region "$AWS_REGION" --name "/fanvault/git/branch" --query "Parameter.Value" --output text 2>/dev/null || echo "main")

echo "  Repo   : $GIT_REPO"
echo "  Branch : $GIT_BRANCH"

# ── 3. Install Node.js 20.x (needed to build the SPA) ────────────────────────
echo "[3/6] Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node --version
npm --version

# ── 4. Clone repo and build the React SPA ────────────────────────────────────
echo "[4/6] Cloning repository and building SPA..."
APP_DIR="/var/www/fanvault-frontend"
rm -rf "$APP_DIR"
git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO" /tmp/fanvault-repo

# Navigate to the frontend workspace and install + build
cd /tmp/fanvault-repo/fanvault-frontend
npm ci --prefer-offline

# Write the frontend .env.production so Vite injects the correct API base URL
# VITE_API_BASE_URL is intentionally left as a relative path (/api) so the
# React bundle works regardless of which ALB DNS name is used.
cat > .env.production << 'VENV'
VITE_API_BASE_URL=/api
VENV

npm run build  # Outputs to /tmp/fanvault-repo/.../dist

# Copy compiled dist to webroot
mkdir -p "$APP_DIR"
cp -r dist/* "$APP_DIR/"
chown -R www-data:www-data "$APP_DIR"

echo "  SPA build complete. Files deployed to: $APP_DIR"

# ── 5. Configure Nginx ────────────────────────────────────────────────────────
echo "[5/6] Configuring Nginx..."
cat > /etc/nginx/sites-available/fanvault << NGINX
server {
    listen 80 default_server;
    server_name _;

    root /var/www/fanvault-frontend;
    index index.html;

    # ALB health check — must return 200 on /index.html
    location = /index.html {
        add_header Cache-Control "no-cache";
    }

    # Serve static assets with long-lived cache
    location ^~ /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # All other routes → SPA index.html (React Router handles routing client-side)
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Do NOT proxy /api/* — the ALB handles all API routing before
    # requests reach Nginx. This block prevents accidental proxy leaks.
    location /api/ {
        return 502 '{"error":"API requests must not reach the frontend server"}';
        add_header Content-Type application/json;
    }
}
NGINX

# Enable site and remove default
ln -sf /etc/nginx/sites-available/fanvault /etc/nginx/sites-enabled/fanvault
rm -f /etc/nginx/sites-enabled/default

# Test config before reloading
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "  Nginx configured and running on port 80."

# ── 6. Health check validation ────────────────────────────────────────────────
echo "[6/6] Running local health check..."
sleep 3
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/index.html)
if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ Health check passed — HTTP $HTTP_CODE"
else
    echo "  ❌ Health check FAILED — HTTP $HTTP_CODE (Nginx may still be starting)"
fi

echo "========================================================"
echo " FanVault Frontend Bootstrap COMPLETE — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "========================================================"
