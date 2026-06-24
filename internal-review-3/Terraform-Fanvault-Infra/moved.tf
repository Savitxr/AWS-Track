

moved {
  from = module.vpc
  to   = module.networking
}

moved {
  from = module.security
  to   = module.security_groups
}

moved {
  from = module.compute
  to   = module.backend
}

moved {
  from = module.dynamodb
  to   = module.storage
}

moved {
  from = module.ssm
  to   = module.configuration
}

moved {
  from = module.sns
  to   = module.notifications
}

moved {
  from = module.event_driven
  to   = module.event_processing
}


moved {
  from = module.s3_lambda.aws_s3_bucket.architecture
  to   = module.storage.aws_s3_bucket.architecture
}

moved {
  from = module.s3_lambda.aws_s3_bucket.product_images
  to   = module.storage.aws_s3_bucket.product_images
}

moved {
  from = module.s3_lambda.aws_s3_bucket_cors_configuration.product_images_cors
  to   = module.storage.aws_s3_bucket_cors_configuration.product_images_cors
}

moved {
  from = module.s3_lambda.aws_s3_bucket_lifecycle_configuration.product_images_lifecycle
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.product_images_lifecycle
}

moved {
  from = module.s3_lambda.aws_s3_bucket_policy.allow_cloudfront
  to   = module.storage.aws_s3_bucket_policy.allow_cloudfront
}

moved {
  from = module.s3_lambda.aws_s3_bucket_public_access_block.block_public
  to   = module.storage.aws_s3_bucket_public_access_block.block_public
}

moved {
  from = module.s3_lambda.aws_s3_bucket_public_access_block.product_images_public_block
  to   = module.storage.aws_s3_bucket_public_access_block.product_images_public_block
}

moved {
  from = module.s3_lambda.aws_s3_bucket_server_side_encryption_configuration.product_images_sse
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.product_images_sse
}

moved {
  from = module.s3_lambda.aws_s3_bucket_versioning.product_images_versioning
  to   = module.storage.aws_s3_bucket_versioning.product_images_versioning
}

moved {
  from = module.s3_lambda.aws_s3_object.folder_categories
  to   = module.storage.aws_s3_object.folder_categories
}

moved {
  from = module.s3_lambda.aws_s3_object.folder_products
  to   = module.storage.aws_s3_object.folder_products
}

moved {
  from = module.s3_lambda.aws_s3_object.folder_thumbnails
  to   = module.storage.aws_s3_object.folder_thumbnails
}

moved {
  from = module.s3_lambda.aws_cloudfront_distribution.product_images_distribution
  to   = module.storage.aws_cloudfront_distribution.product_images_distribution
}

moved {
  from = module.s3_lambda.aws_cloudfront_origin_access_control.product_images_oac
  to   = module.storage.aws_cloudfront_origin_access_control.product_images_oac
}

moved {
  from = module.s3_lambda.aws_lambda_function.arch_page
  to   = module.storage.aws_lambda_function.arch_page
}


moved {
  from = module.event_driven.aws_iam_role.lambda_consumers
  to   = module.iam.aws_iam_role.lambda_consumers
}

moved {
  from = module.event_driven.aws_iam_role_policy.lambda_resources
  to   = module.iam.aws_iam_role_policy.lambda_resources
}

moved {
  from = module.event_driven.aws_iam_role_policy_attachment.lambda_logs
  to   = module.iam.aws_iam_role_policy_attachment.lambda_logs
}

moved {
  from = module.sns.aws_iam_role.sns_feedback_role
  to   = module.iam.aws_iam_role.sns_feedback_role
}

moved {
  from = module.sns.aws_iam_role_policy.sns_feedback_policy
  to   = module.iam.aws_iam_role_policy.sns_feedback_policy
}
