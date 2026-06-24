# -----------------------------------------------------------------------------
# Dedicated S3 Bucket for Product Images, Categories, and Thumbnails
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "product_images" {
  bucket_prefix = "${var.project_name}-product-images-"

  tags = {
    Name        = "${var.project_name}-product-images-bucket"
    Environment = var.environment
  }
}

# 1. Versioning
resource "aws_s3_bucket_versioning" "product_images_versioning" {
  bucket = aws_s3_bucket.product_images.id
  versioning_configuration {
    status = "Enabled"
  }
}



resource "aws_s3_bucket_server_side_encryption_configuration" "product_images_sse" {
  bucket = aws_s3_bucket.product_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "product_images_lifecycle" {
  bucket = aws_s3_bucket.product_images.id

  rule {
    id     = "archive-old-versions-and-clean-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# 4. Public Access Block
resource "aws_s3_bucket_public_access_block" "product_images_public_block" {
  bucket                  = aws_s3_bucket.product_images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. CORS Configuration (Allows direct browser/frontend uploads via presigned URLs)
resource "aws_s3_bucket_cors_configuration" "product_images_cors" {
  bucket = aws_s3_bucket.product_images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 6. S3 Directory Structure (Virtual Folders)
resource "aws_s3_object" "folder_products" {
  bucket       = aws_s3_bucket.product_images.id
  key          = "products/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "folder_categories" {
  bucket       = aws_s3_bucket.product_images.id
  key          = "categories/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "folder_thumbnails" {
  bucket       = aws_s3_bucket.product_images.id
  key          = "thumbnails/"
  content_type = "application/x-directory"
}

# -----------------------------------------------------------------------------
# CloudFront Distribution & Origin Access Control (OAC)
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "product_images_oac" {
  name                              = "${var.project_name}-product-images-oac"
  description                       = "Origin Access Control for secure product images S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "product_images_distribution" {
  # 1. S3 Origin
  origin {
    domain_name              = aws_s3_bucket.product_images.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.product_images.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.product_images_oac.id
  }

  # 2. ALB Origin
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "ALB-${var.project_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Custom-Header"
      value = var.cloudfront_to_alb_custom_header
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront CDN for FanVault (S3 + ALB Single Entry Point)"
  default_root_object = ""
  web_acl_id          = var.waf_web_acl_arn

  # Default behavior targets ALB (Frontend)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.project_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  # Ordered Cache Behaviors for S3 Origin (Product images / folders)
  ordered_cache_behavior {
    path_pattern     = "/products/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.product_images.id}"

    # CachingOptimized
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/thumbnails/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.product_images.id}"

    # CachingOptimized
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/categories/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.product_images.id}"

    # CachingOptimized
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/images/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.product_images.id}"

    # CachingOptimized
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Ordered Cache Behavior for API requests to ALB Origin
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-${var.project_name}"

    # CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-product-images-cf"
    Environment = var.environment
  }
}

# S3 Bucket Policy to restrict access exclusively to the CloudFront distribution OAC
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.product_images.id
  policy = data.aws_iam_policy_document.allow_cloudfront_oac.json
}

data "aws_iam_policy_document" "allow_cloudfront_oac" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.product_images.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.product_images_distribution.arn]
    }
  }
}

