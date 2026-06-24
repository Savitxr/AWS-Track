data "aws_caller_identity" "current" {}

module "vpc" {
  source                = "../../modules/vpc"
  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = "10.1.0.0/16"
  public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
  database_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]
  availability_zones    = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source             = "../../modules/eks"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_capacity   = 3
  max_capacity       = 5
  min_capacity       = 2
  instance_types     = ["t3.medium"]
}

module "dynamodb" {
  source            = "../../modules/dynamodb"
  project_name      = var.project_name
  environment       = var.environment
  billing_mode      = "PAY_PER_REQUEST"
  enable_pitr       = true
  enable_encryption = true
}

module "s3" {
  source       = "../../modules/s3"
  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
}

module "cloudfront" {
  source                         = "../../modules/cloudfront"
  project_name                   = var.project_name
  environment                    = var.environment
  s3_bucket_id                   = module.s3.bucket_name
  s3_bucket_arn                  = module.s3.bucket_arn
  s3_bucket_regional_domain_name = module.s3.bucket_regional_domain_name
}

module "secrets_manager" {
  source       = "../../modules/secrets_manager"
  project_name = var.project_name
  environment  = var.environment
}

module "cloudwatch" {
  source             = "../../modules/cloudwatch"
  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = 90
}

module "cognito" {
  source        = "../../modules/cognito"
  project_name  = var.project_name
  environment   = var.environment
  callback_urls = ["https://fanvault.example.com"]
  logout_urls   = ["https://fanvault.example.com"]
}

module "iam" {
  source                = "../../modules/iam"
  project_name          = var.project_name
  environment           = var.environment
  github_repo           = var.github_repo
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
  enable_irsa           = true

  dynamodb_table_arns = [
    module.dynamodb.profiles_table_arn,
    module.dynamodb.products_table_arn,
    module.dynamodb.orders_table_arn,
    module.dynamodb.audit_logs_table_arn,
    module.dynamodb.metadata_table_arn,
  ]

  dynamodb_table_products_arn   = module.dynamodb.products_table_arn
  dynamodb_table_audit_logs_arn = module.dynamodb.audit_logs_table_arn
  s3_bucket_product_images_arn  = module.s3.bucket_arn

  sns_topic_low_inventory_arn          = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-low-inventory-alerts"
  sns_topic_product_upload_failure_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-product-upload-failures"
  sns_kms_key_arn                      = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${var.project_name}-${var.environment}-sns-key"
}

module "ecr" {
  source           = "../../modules/ecr"
  project_name     = var.project_name
  environment      = var.environment
  repository_names = ["frontend", "user-service", "commerce-service", "ai-service"]
}

module "argocd" {
  source              = "../../modules/argocd"
  argocd_helm_version = "7.1.3"
  depends_on          = [module.eks, aws_eks_access_entry.github_actions]
}

resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-github-actions-role"
  type          = "STANDARD"

  depends_on = [module.eks, module.iam]
}

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-github-actions-role"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_actions]
}

module "notifications" {
  source                = "../../modules/notifications"
  project_name          = var.project_name
  environment           = var.environment
  alert_email           = ""
  sns_feedback_role_arn = module.iam.sns_feedback_role_arn

  depends_on = [module.iam]
}

module "event_processing" {
  source       = "../../modules/event_processing"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  dynamodb_table_audit_logs_arn  = module.dynamodb.audit_logs_table_arn
  dynamodb_table_audit_logs_name = module.dynamodb.audit_logs_table_name
  dynamodb_table_products_arn    = module.dynamodb.products_table_arn
  dynamodb_table_products_name   = module.dynamodb.products_table_name

  s3_bucket_product_images_arn  = module.s3.bucket_arn
  s3_bucket_product_images_name = module.s3.bucket_name

  sns_topic_low_inventory_arn          = module.notifications.sns_topic_low_inventory_arn
  sns_topic_product_upload_failure_arn = module.notifications.sns_topic_product_upload_failure_arn
  sns_key_arn                          = module.notifications.sns_key_arn

  lambda_role_arn = module.iam.lambda_consumers_role_arn

  depends_on = [module.notifications, module.iam, module.dynamodb, module.s3]
}

resource "aws_iam_role_policy" "lambda_consumers_sns_kms" {
  name = "${var.project_name}-${var.environment}-lambda-consumers-sns-kms"
  role = "${var.project_name}-lambda-consumers-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SNSKMSAccess"
      Effect   = "Allow"
      Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
      Resource = [module.notifications.sns_key_arn]
    }]
  })

  depends_on = [module.iam, module.notifications]
}

resource "aws_iam_role_policy" "commerce_irsa_sns_kms" {
  name = "${var.project_name}-${var.environment}-commerce-irsa-sns-kms"
  role = "${var.project_name}-commerce-irsa-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SNSKMSAccess"
      Effect   = "Allow"
      Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
      Resource = [module.notifications.sns_key_arn]
    }]
  })

  depends_on = [module.iam, module.notifications]
}

module "eks_monitoring" {
  source       = "../../modules/eks_monitoring"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  sns_topic_arn = module.notifications.sns_topic_admin_operational_alert_arn

  dynamodb_tables = {
    profiles   = module.dynamodb.profiles_table_name
    products   = module.dynamodb.products_table_name
    orders     = module.dynamodb.orders_table_name
    audit_logs = module.dynamodb.audit_logs_table_name
    metadata   = module.dynamodb.metadata_table_name
  }

  lambda_functions = {
    audit_logging       = "${var.project_name}-${var.environment}-audit-logging-consumer"
    thumbnail_generator = "${var.project_name}-${var.environment}-thumbnail-generator-consumer"
    inventory_monitor   = "${var.project_name}-${var.environment}-inventory-monitor-consumer"
  }

  sns_topics = {
    low_inventory    = "${var.project_name}-${var.environment}-low-inventory-alerts"
    order_failure    = "${var.project_name}-${var.environment}-order-failure-alerts"
    product_upload   = "${var.project_name}-${var.environment}-product-upload-failures"
    admin_operations = "${var.project_name}-${var.environment}-admin-operational-alerts"
  }

  depends_on = [module.notifications, module.event_processing]
}

module "eks_addons" {
  source           = "../../modules/eks_addons"
  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_certificate_authority_data

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  cloudwatch_agent_role_arn = module.iam.cloudwatch_agent_irsa_role_arn
  ebs_csi_role_arn          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-ebs-csi-role"

  enable_metrics_server           = true
  enable_cloudwatch_observability = true
  enable_vpa                      = true

  depends_on = [module.eks, module.iam]
}

module "observability" {
  source       = "../../modules/observability"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  sns_topic_arn              = module.notifications.sns_topic_admin_operational_alert_arn
  sns_key_arn                = module.notifications.sns_key_arn
  alertmanager_irsa_role_arn = module.iam.alertmanager_irsa_role_arn

  prometheus_retention_days = var.prometheus_retention_days
  prometheus_storage_size   = "20Gi"
  grafana_storage_size      = "10Gi"
  alertmanager_storage_size = "5Gi"

  depends_on = [module.eks_addons, module.notifications]
}


module "karpenter" {
  source                = "../../modules/karpenter"
  cluster_name          = module.eks.cluster_name
  cluster_endpoint      = module.eks.cluster_endpoint
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
  node_iam_role_name    = module.eks.node_role_name
  node_iam_role_arn     = module.eks.node_role_arn

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  max_nodes_cpu    = var.karpenter_max_cpu
  max_nodes_memory = var.karpenter_max_memory

  depends_on = [module.eks, module.iam]
}

module "configuration" {
  source       = "../../modules/configuration"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # JWT secrets — SecureString parameters, supplied via tfvars
  jwt_secret         = var.jwt_secret
  jwt_refresh_secret = var.jwt_refresh_secret

  # Cognito — wired from module.cognito outputs
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id

  # DynamoDB table names — wired from module.dynamodb outputs
  dynamodb_table_profiles   = module.dynamodb.profiles_table_name
  dynamodb_table_products   = module.dynamodb.products_table_name
  dynamodb_table_orders     = module.dynamodb.orders_table_name
  dynamodb_table_audit_logs = module.dynamodb.audit_logs_table_name
  dynamodb_table_metadata   = module.dynamodb.metadata_table_name

  # S3 bucket + CloudFront — wired from module outputs
  s3_bucket_name    = module.s3.bucket_name
  s3_cloudfront_url = module.cloudfront.domain_name

  # EventBridge bus name and SNS topic ARNs
  eventbridge_bus_name              = module.event_processing.event_bus_name
  create_sns_ssm_parameters         = true
  sns_topic_low_inventory           = module.notifications.sns_topic_low_inventory_arn
  sns_topic_order_failure           = module.notifications.sns_topic_order_failure_arn
  sns_topic_product_upload_failure  = module.notifications.sns_topic_product_upload_failure_arn
  sns_topic_admin_operational_alert = module.notifications.sns_topic_admin_operational_alert_arn

  depends_on = [module.notifications, module.event_processing]
}
