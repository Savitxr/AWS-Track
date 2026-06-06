# Implementation: Monolithic FanVault-v2 Architecture

This guide provides step-by-step instructions to recreate the secure monolithic App Server + remote Database Server architecture on AWS from scratch.

---

## Prerequisites
- An active AWS Account.
- A Git repository containing the `monolithic` branch of the codebase.
- A VPC configured with Public Subnets (for ALB/App), Private Subnets (for App/DB), and an Internet Gateway (IGW).

---

## Step 1: AWS KMS Key Creation
1. Open the **AWS KMS Console** (Region: `us-east-1`).
2. Click **Create Key**:
   - **Key Type**: Symmetric.
   - **Key Usage**: Encrypt and Decrypt.
   - **Alias**: `fanvault-s3-key`.
3. Set your administrative user as key administrator.
4. Set key users (you will attach the IAM Role created in Step 5 here later).
5. Complete key creation and copy the **KMS Key ARN**.

---

## Step 2: S3 Bucket Setup
1. Open the **Amazon S3 Console**.
2. Click **Create Bucket**:
   - **Bucket Name**: `fanvault-static-assets-yourname` (must be globally unique).
   - **Region**: `us-east-1`.
   - **Block all public access**: Check ✅ (keep the bucket strictly private).
3. Under **Default Encryption**:
   - Enable **SSE-KMS**.
   - Select **Choose from your AWS KMS keys**.
   - Select the KMS key created in Step 1 (`fanvault-s3-key`).
4. Click **Create Bucket**.
5. Upload the following product images into the **root** of the bucket:
   - `mi-jersey-2024.jpg`
   - `rcb-cap-classic.jpg`
   - `avengers-infinity-hoodie.jpg`
   - `breaking-bad-heisenberg-tee.jpg`
   - `chelsea-fc-sneakers.jpg`

---

## Step 3: Systems Manager Parameter Store Setup
1. Open the **AWS Systems Manager Console** $\rightarrow$ **Parameter Store** (Region: `us-east-1`).
2. Create Parameter 1:
   - **Name**: `/fanvault/s3/bucket`
   - **Type**: `String`
   - **Value**: The name of the S3 bucket created in Step 2.
3. Create Parameter 2:
   - **Name**: `/fanvault/s3/region`
   - **Type**: `String`
   - **Value**: `us-east-1`

---

## Step 4: AWS Secrets Manager Setup
1. Open the **AWS Secrets Manager Console** (Region: `us-east-1`).
2. Click **Store a new secret**:
   - **Secret Type**: Other type of secret.
   - **Key/Value Pairs**: Enter the following keys and values:
     - `username`: `dbuser`
     - `password`: `YOUR_STRONG_DATABASE_PASSWORD` *(Replace with a strong random password)*
     - `host`: `DATABASE_PRIVATE_IP` *(Leave as placeholder; you will update this in Step 7)*
     - `port`: `27017`
     - `database`: `fanvault_db`
     - `authSource`: `fanvault_db`
     - `jwtSecret`: `YOUR_MIN_32_CHAR_JWT_ACCESS_SECRET` *(Enter a random 32+ character key)*
     - `jwtRefreshSecret`: `YOUR_MIN_32_CHAR_JWT_REFRESH_SECRET` *(Enter a different 32+ character key)*
3. Click **Next**.
4. **Secret name**: `production/mongodb`.
5. Complete secret creation.

---

## Step 5: IAM Role & Instance Profile Configuration
1. Open the **AWS IAM Console** $\rightarrow$ **Policies** $\rightarrow$ **Create Policy**.
2. Click **JSON** and paste the following policy (replace `YOUR_ACCOUNT_ID`, `YOUR_S3_BUCKET_NAME`, and `YOUR_KMS_KEY_ID` with your actual values):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:production/mongodb-*"
    },
    {
      "Sid": "AllowParameterStoreAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:us-east-1:YOUR_ACCOUNT_ID:parameter/fanvault/s3/*"
    },
    {
      "Sid": "AllowS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::YOUR_S3_BUCKET_NAME/*"
    },
    {
      "Sid": "AllowKMSDecryptAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:YOUR_ACCOUNT_ID:key/YOUR_KMS_KEY_ID"
    }
  ]
}
```
3. Save the policy as `fanvault-app-policy`.
4. Go to **Roles** $\rightarrow$ **Create Role**:
   - **Trusted Entity**: AWS Service $\rightarrow$ **EC2**.
   - **Permissions**: Attach `fanvault-app-policy`.
   - **Role Name**: `fanvault-app-role`.

---

## Step 6: Launching the Database Server (MongoDB)
1. Go to **EC2 Console** $\rightarrow$ **Launch Instance**:
   - **AMI**: Ubuntu 22.04 LTS (HVM, SSD).
   - **Instance Type**: `t3.medium` (recommended) or `t3.small`.
   - **Network**: Choose your VPC and place it in the **Private Database Subnet**.
   - **Security Group**: Create a new security group (`fanvault-db-sg`) and add a rule allowing:
     * **Port**: `27017` (TCP) from the **App Server Security Group** (or the App Subnet CIDR).
2. Expand **Advanced Details** and paste the contents of [aws-userdata-db.sh](file:///c:/Users/Admin/Desktop/Ust/Capstone%20App/fanvault-v2-mono/deploy/aws-userdata-db.sh) into the **User Data** text box.
   - *Ensure you update `DB_ADMIN_PASSWORD` and `DB_APP_PASSWORD` inside the user data script to match your desired credentials.*
3. Launch the instance.
4. Once running, copy the instance's **Private IP address**.

---

## Step 7: Update AWS Secrets Manager
1. Return to the **AWS Secrets Manager Console**.
2. Edit the secret `production/mongodb` created in Step 4.
3. Update the value of the `"host"` key to the **Private IP address** of the Database EC2 instance copied in Step 6 (e.g. `172.31.25.115`).
4. Update the `"password"` key to match the `DB_APP_PASSWORD` set in the database user data.
5. Save the changes.

---

## Step 8: Launching the Monolithic App Server
1. Go to **EC2 Console** $\rightarrow$ **Launch Instance**:
   - **AMI**: Ubuntu 22.04 LTS (HVM, SSD).
   - **Instance Type**: `t3.small`.
   - **Network**: Place the instance in your VPC subnets.
     * *If using an ALB, place the instance in a Private Subnet.*
     * *If accessing directly via Public IP, place it in a Public Subnet, enable "Auto-assign public IP", and ensure the Route Table routes `0.0.0.0/0` to your Internet Gateway.*
   - **IAM Instance Profile**: Select `fanvault-app-role` (created in Step 5).
   - **Security Group**: Create a security group (`fanvault-app-sg`) allowing:
     * **Port**: `80` (HTTP) from `0.0.0.0/0` (or from your ALB security group).
     * **Port**: `22` (SSH) from your Bastion host or Admin IP.
2. Open the file [aws-userdata-app.sh](file:///c:/Users/Admin/Desktop/Ust/Capstone%20App/fanvault-v2-mono/deploy/aws-userdata-app.sh).
3. Edit the following variables at the top of the script:
   - `DB_HOST`: Set to the Private IP of the Database EC2 instance.
   - `DB_APP_PASSWORD`: Set to the app password.
   - `JWT_SECRET`, `JWT_REFRESH_SECRET`: Set matching fallback credentials.
   - `USE_SECRETS_MANAGER`: Set to `"true"`.
   - `AWS_REGION`: Set to `"us-east-1"`.
   - `SECRET_ID`: Set to `"production/mongodb"`.
4. Paste the updated script into the **User Data** text box under **Advanced Details**.
5. Launch the instance.

---

## Step 9: Post-Deployment Verification
You can monitor the deployment progress:
1. SSH into the App Instance and stream the logs:
   ```bash
   tail -f /var/log/user-data.log
   ```
2. Verify Nginx, Auth, and Commerce services are healthy:
   ```bash
   sudo systemctl status nginx
   sudo systemctl status fanvault-auth
   sudo systemctl status fanvault-commerce
   ```
3. Test loading the website in the browser via the **App Server's Public IP** or your **ALB DNS Name**.
