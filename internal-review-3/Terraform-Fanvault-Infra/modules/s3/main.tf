resource "aws_s3_bucket" "bucket" {
  bucket = "${var.project_name}-${var.environment}-product-images-${var.account_id}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-product-images"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Allow browsers to preflight (OPTIONS) and PUT presigned upload requests directly to S3.
# AllowedOrigins defaults to ["*"] because presigned-URL uploads are authenticated via
# the signed URL parameters themselves, not via cookies — credentials: false is implied.
resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
