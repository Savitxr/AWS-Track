# S3 Private Bucket for Architectural Diagram
resource "aws_s3_bucket" "architecture" {
  bucket_prefix = "${var.project_name}-architecture-"

  tags = {
    Name        = "${var.project_name}-architecture-bucket"
    Environment = var.environment
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket                  = aws_s3_bucket.architecture.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Archive provider to zip Lambda code dynamically
data "archive_file" "lambda_code" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source {
    filename = "index.js"
    content  = <<EOF
const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const s3 = new S3Client({});

exports.handler = async (event) => {
    try {
        const command = new GetObjectCommand({
            Bucket: "${aws_s3_bucket.architecture.id}",
            Key: "architecture.png"
        });
        const response = await s3.send(command);
        const body = await response.Body.transformToByteArray();
        const base64String = Buffer.from(body).toString("base64");

        return {
            statusCode: 200,
            statusDescription: "200 OK",
            isBase64Encoded: true,
            headers: {
                "Content-Type": "image/png",
                "Cache-Control": "public, max-age=86400"
            },
            body: base64String
        };
    } catch (err) {
        return {
            statusCode: 500,
            headers: { "Content-Type": "text/plain" },
            body: "Internal Server Error: " + err.message
        };
    }
};
EOF
  }
}

# Lambda Function Provisioning
resource "aws_lambda_function" "arch_page" {
  filename         = data.archive_file.lambda_code.output_path
  function_name    = "${var.project_name}-arch-page-lambda"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  timeout          = 15

  tags = {
    Name        = "${var.project_name}-lambda"
    Environment = var.environment
  }

  depends_on = [aws_s3_bucket_public_access_block.block_public]
}
