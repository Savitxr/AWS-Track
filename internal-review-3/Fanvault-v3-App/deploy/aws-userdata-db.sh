#!/usr/bin/env bash
# =============================================================================
# AWS EC2 User Data — FanVault v2 Database Instance (MongoDB)
# Target OS: Ubuntu 22.04 LTS (Jammy)
#
# This script is designed to run automatically on instance boot to provision 
# the database server.
#
# IMPORTANT CONFIGURATION:
# 1. Update the credentials below before running, or inject them dynamically.
# 2. Place this EC2 instance in a Private Subnet.
# 3. Ensure the Security Group allows Inbound TCP on port 27017 ONLY from
#    the Monolithic App Server Security Group.
# =============================================================================

set -euo pipefail

# ── 1. Configuration Variables ────────────────────────────────────────────────
DB_ADMIN_USER="dbadmin"
DB_ADMIN_PASSWORD="CHANGE_ME_STRONG_ADMIN_PASSWORD"

DB_APP_USER="dbuser"
DB_APP_PASSWORD="CHANGE_ME_STRONG_APP_PASSWORD"
DB_NAME="fanvault_db"

echo "=================================================="
echo " Starting MongoDB Server Provisioning"
echo "=================================================="

# ── 2. Add MongoDB 7.0 Repository Keys & Repo ────────────────────────────────
echo "[INFO] Importing MongoDB public GPG key..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

echo "[INFO] Adding MongoDB repository to sources list..."
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# ── 3. Install MongoDB Packages ──────────────────────────────────────────────
echo "[INFO] Updating repositories and installing MongoDB..."
apt-get update -y
# Run with non-interactive frontend to prevent prompts hanging
DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org

# ── 4. Configure Networking and Security in mongod.conf ───────────────────────
echo "[INFO] Configuring MongoDB networking and security..."

# Bind MongoDB to listen on all interfaces so that the app server can connect
# (Network security is enforced by AWS Security Groups)
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# Enable authentication in the configuration file
# Note: Security authorization block is appended to the configuration
if ! grep -q "authorization: enabled" /etc/mongod.conf; then
  cat >> /etc/mongod.conf << 'EOF'
security:
  authorization: enabled
EOF
fi

# ── 5. Start and Enable MongoDB Service ───────────────────────────────────────
echo "[INFO] Starting and enabling mongod system service..."
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

# ── 6. Wait for MongoDB to become healthy and reachable ───────────────────────
echo "[INFO] Waiting for MongoDB to start..."
timeout=30
while ! mongosh --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 2
  timeout=$((timeout - 2))
  if [ "$timeout" -le 0 ]; then
    echo "[ERROR] MongoDB failed to start in a timely manner."
    exit 1
  fi
done
echo "[INFO] MongoDB is running."

# ── 7. Create Users (Admin & Application) ─────────────────────────────────────
echo "[INFO] Creating database admin and application users..."

# First, create the root admin user (without auth since it is the first connection)
mongosh --eval "
  db = db.getSiblingDB('admin');
  db.createUser({
    user: '${DB_ADMIN_USER}',
    pwd: '${DB_ADMIN_PASSWORD}',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      'readWriteAnyDatabase'
    ]
  });
"

# Next, use the admin user to create the application user for fanvault_db
mongosh -u "${DB_ADMIN_USER}" -p "${DB_ADMIN_PASSWORD}" --authenticationDatabase admin --eval "
  db = db.getSiblingDB('${DB_NAME}');
  db.createUser({
    user: '${DB_APP_USER}',
    pwd: '${DB_APP_PASSWORD}',
    roles: [
      { role: 'readWrite', db: '${DB_NAME}' }
    ]
  });
"

echo "=================================================="
echo " MongoDB Server Provisioning Completed Successfully!"
echo " Admin User: ${DB_ADMIN_USER}"
echo " App User  : ${DB_APP_USER}"
echo " Database  : ${DB_NAME}"
echo "=================================================="
