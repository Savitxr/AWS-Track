
data "aws_caller_identity" "current" {}

locals {
  cf_to_alb_header = var.cloudfront_to_alb_custom_header
}

module "networking" {
  source              = "./modules/networking"
  project_name        = var.project_name
  environment         = var.environment
  vpc_endpoints_sg_id = module.security_groups.vpc_endpoints_sg_id
  aws_region          = var.aws_region
}

module "security_groups" {
  source       = "./modules/security_groups"
  vpc_id       = module.networking.vpc_id
  admin_ssh_ip = var.admin_ssh_ip
  project_name = var.project_name
  environment  = var.environment
}

module "notifications" {
  source                = "./modules/notifications"
  project_name          = var.project_name
  environment           = var.environment
  alert_email           = var.alert_email
  sns_feedback_role_arn = module.iam.sns_feedback_role_arn
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  github_repo  = var.github_repo

  dynamodb_table_arns = [
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-users",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-profiles",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-orders",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-metadata",
  ]

  sns_topic_arns = [
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-order-failure-alerts",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-admin-operational-alerts",
  ]

  sns_kms_key_arn = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"

  ssm_parameter_prefix = var.ssm_parameter_prefix

  s3_bucket_name_prefix = var.project_name

  dynamodb_table_audit_logs_arn        = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs"
  dynamodb_table_products_arn          = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products"
  s3_bucket_product_images_arn         = "arn:aws:s3:::${var.project_name}-product-images-*"
  sns_topic_low_inventory_arn          = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts"
  sns_topic_product_upload_failure_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures"
}

module "storage" {
  source                          = "./modules/storage"
  project_name                    = var.project_name
  environment                     = var.environment
  billing_mode                    = var.dynamodb_billing_mode
  enable_pitr                     = var.dynamodb_enable_pitr
  enable_encryption               = var.dynamodb_enable_encryption
  lambda_role_arn                 = module.iam.lambda_role_arn
  cors_origin                     = var.cors_origin
  waf_web_acl_arn                 = module.governance.waf_web_acl_arn
  alb_dns_name                    = module.backend.alb_dns_name
  cloudfront_to_alb_custom_header = local.cf_to_alb_header
}

module "configuration" {
  source       = "./modules/configuration"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  git_repo_url = var.git_repo_url
  git_branch   = var.git_branch

  cors_origin        = var.cors_origin
  jwt_secret         = var.jwt_secret
  jwt_refresh_secret = var.jwt_refresh_secret

  dynamodb_table_users      = module.storage.table_users_name
  dynamodb_table_profiles   = module.storage.table_profiles_name
  dynamodb_table_products   = module.storage.table_products_name
  dynamodb_table_orders     = module.storage.table_orders_name
  dynamodb_table_audit_logs = module.storage.table_audit_logs_name
  dynamodb_table_metadata   = module.storage.table_metadata_name

  s3_bucket_name    = module.storage.s3_bucket_name
  s3_cloudfront_url = module.storage.cloudfront_domain_name

  eventbridge_bus_name = module.event_processing.event_bus_name

  sns_topic_low_inventory           = module.notifications.sns_topic_low_inventory_arn
  sns_topic_order_failure           = module.notifications.sns_topic_order_failure_arn
  sns_topic_product_upload_failure  = module.notifications.sns_topic_product_upload_failure_arn
  sns_topic_admin_operational_alert = module.notifications.sns_topic_admin_operational_alert_arn

  depends_on = [module.storage, module.event_processing, module.notifications]
}

module "event_processing" {
  source                         = "./modules/event_processing"
  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  dynamodb_table_audit_logs_arn  = module.storage.table_audit_logs_arn
  dynamodb_table_audit_logs_name = module.storage.table_audit_logs_name
  dynamodb_table_products_arn    = module.storage.table_products_arn
  dynamodb_table_products_name   = module.storage.table_products_name
  s3_bucket_product_images_arn   = module.storage.s3_product_images_bucket_arn
  s3_bucket_product_images_name  = module.storage.s3_bucket_name

  lambda_role_arn = module.iam.lambda_consumers_role_arn

  sns_topic_low_inventory_arn          = module.notifications.sns_topic_low_inventory_arn
  sns_topic_product_upload_failure_arn = module.notifications.sns_topic_product_upload_failure_arn
  sns_key_arn                          = module.notifications.sns_key_arn
}

module "backend" {
  source                          = "./modules/backend"
  vpc_id                          = module.networking.vpc_id
  public_subnets                  = module.networking.public_subnets
  frontend_private_subnets        = module.networking.frontend_private_subnets
  backend_private_subnets         = module.networking.backend_private_subnets
  database_private_subnets        = module.networking.database_private_subnets
  alb_sg_id                       = module.security_groups.alb_sg_id
  frontend_sg_id                  = module.security_groups.frontend_sg_id
  backend_sg_id                   = module.security_groups.backend_sg_id
  bastion_sg_id                   = module.security_groups.bastion_sg_id
  lambda_function_arn             = module.storage.lambda_function_arn
  lambda_function_name            = module.storage.lambda_function_name
  key_name                        = var.key_name
  project_name                    = var.project_name
  environment                     = var.environment
  cloudfront_to_alb_custom_header = local.cf_to_alb_header

  ec2_backend_instance_profile_name  = module.iam.ec2_backend_instance_profile_name
  ec2_frontend_instance_profile_name = module.iam.ec2_frontend_instance_profile_name

  depends_on = [module.iam]
}

module "monitoring" {
  source              = "./modules/monitoring"
  project_name        = var.project_name
  environment         = var.environment
  sns_topic_arn       = module.notifications.sns_topic_admin_operational_alert_arn
  alb_arn_suffix      = module.backend.alb_arn_suffix
  bastion_instance_id = module.backend.bastion_instance_id

  target_groups = {
    frontend = module.backend.frontend_tg_arn_suffix
    identity = module.backend.identity_tg_arn_suffix
    commerce = module.backend.commerce_tg_arn_suffix
    lambda   = module.backend.lambda_tg_arn_suffix
  }

  asgs = {
    frontend = module.backend.frontend_asg_name
    backend  = module.backend.backend_asg_name
  }

  dynamodb_tables = module.storage.dynamodb_tables

  lambdas = {
    audit_logging       = "${var.project_name}-audit-logging-consumer"
    thumbnail_generator = "${var.project_name}-thumbnail-generator-consumer"
    inventory_monitor   = "${var.project_name}-inventory-monitor-consumer"
    arch_page           = module.storage.lambda_function_name
  }

  sns_topics = {
    low_inventory           = "${var.project_name}-low-inventory-alerts"
    order_failure           = "${var.project_name}-order-failure-alerts"
    product_upload_failure  = "${var.project_name}-product-upload-failures"
    admin_operational_alert = "${var.project_name}-admin-operational-alerts"
  }
}


module "governance" {
  source                = "./modules/governance"
  project_name          = var.project_name
  environment           = var.environment
  geo_blocked_countries = var.geo_blocked_countries
}
