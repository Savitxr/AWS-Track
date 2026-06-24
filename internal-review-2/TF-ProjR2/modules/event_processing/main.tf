# -----------------------------------------------------------------------------
# EventBridge Bus
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_bus" "commerce_bus" {
  name = "${var.project_name}-event-bus"

  tags = {
    Name        = "${var.project_name}-event-bus"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# SQS Dead-Letter Queue (DLQ) for failed EventBridge targets
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "event_dlq" {
  name                      = "${var.project_name}-event-dlq"
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-event-dlq"
    Environment = var.environment
  }
}

resource "aws_sqs_queue_policy" "event_dlq_policy" {
  queue_url = aws_sqs_queue.event_dlq.id
  policy    = data.aws_iam_policy_document.sqs_dlq_policy.json
}

data "aws_iam_policy_document" "sqs_dlq_policy" {
  statement {
    sid       = "AllowEventBridgeToSendMessage"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.event_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_bus.commerce_bus.arn]
    }
  }
}

# (IAM Role and Policies relocated to modules/iam/lambda_roles.tf)

# -----------------------------------------------------------------------------
# Lambda 1: Audit Logging Consumer
# -----------------------------------------------------------------------------
data "archive_file" "audit_logging" {
  type        = "zip"
  output_path = "${path.module}/audit_logging.zip"
  source {
    filename = "index.js"
    content  = <<EOF
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const crypto = require("crypto");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE = process.env.DYNAMODB_TABLE_AUDIT_LOGS;

exports.handler = async (event) => {
  console.log("Received EventBridge event:", JSON.stringify(event, null, 2));

  const detail = event.detail || {};
  const action = event["detail-type"] || "UNKNOWN_ACTION";
  const now = new Date();
  const ttlExpiry = Math.floor(now.getTime() / 1000) + 86400; // 1-day TTL

  let entityType = "other";
  let entityId = "unknown";
  
  if (action === "ProductCreated" || action === "ProductUpdated") {
    entityType = "product";
    entityId = detail.productId || "unknown";
  } else if (action === "OrderPlaced") {
    entityType = "order";
    entityId = detail.orderId || "unknown";
  } else if (action === "InventoryLow") {
    entityType = "inventory";
    entityId = detail.productId || "unknown";
  }

  const item = {
    logId: crypto.randomUUID(),
    adminId: detail.adminId || detail.userId || "unknown",
    adminEmail: detail.adminEmail || detail.userEmail || "system",
    action: action.toUpperCase(),
    entityType,
    entityId,
    changes: detail.changes ? JSON.stringify(detail.changes) : JSON.stringify(detail),
    timestamp: detail.timestamp || now.toISOString(),
    ttlExpiry,
  };

  try {
    await docClient.send(
      new PutCommand({
        TableName: TABLE,
        Item: item,
      })
    );
    console.log(`[Lambda Audit] Successfully logged action $${action} to DynamoDB`);
    return { status: "success" };
  } catch (err) {
    console.error("[Lambda Audit] Error writing to DynamoDB:", err.message);
    throw err;
  }
};
EOF
  }
}

resource "aws_lambda_function" "audit_logging" {
  filename         = data.archive_file.audit_logging.output_path
  function_name    = "${var.project_name}-audit-logging-consumer"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.audit_logging.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      DYNAMODB_TABLE_AUDIT_LOGS = var.dynamodb_table_audit_logs_name
    }
  }

  tags = {
    Name        = "${var.project_name}-audit-logging-consumer"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Lambda 2: Product Thumbnail Generation Consumer
# -----------------------------------------------------------------------------
data "archive_file" "thumbnail_generator" {
  type        = "zip"
  output_path = "${path.module}/thumbnail_generator.zip"
  source {
    filename = "index.js"
    content  = <<EOF
const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, UpdateCommand } = require("@aws-sdk/lib-dynamodb");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const s3 = new S3Client({});
const dynamo = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamo);
const sns = new SNSClient({});

const BUCKET = process.env.S3_BUCKET_NAME;
const PRODUCTS_TABLE = process.env.DYNAMODB_TABLE_PRODUCTS;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

async function publishFailure(productId, errorMsg, originalKey, correlationId) {
  if (!SNS_TOPIC_ARN) {
    console.error("SNS_TOPIC_ARN not configured.");
    return;
  }
  const timestamp = new Date().toISOString();
  const border = "--------------------------------------------------";
  
  const formattedMessage = `🚨 [ERROR] ProductUploadFailure
$${border}
An operational incident was reported.

• Service:        thumbnail-generator-lambda
• Event Type:     ProductUploadFailure
• Resource:       Product:$${productId || "unknown"}
• Severity:       ERROR
• Timestamp:      $${timestamp}
• Correlation ID: $${correlationId}

Alert Details:
$${border}
• Product ID:     $${productId || "unknown"}
• Image Key:      $${originalKey}
• Error Message:  $${errorMsg}
$${border}
`;
  try {
    await sns.send(new PublishCommand({
      TopicArn: SNS_TOPIC_ARN,
      Message: formattedMessage,
      Subject: `Product Upload Failure Alert: Product $${productId || "unknown"}`
    }));
    console.log("Upload failure alert sent to SNS.");
  } catch (err) {
    console.error("Failed to send upload failure alert to SNS:", err.message);
  }
}

exports.handler = async (event) => {
  console.log("Received EventBridge event:", JSON.stringify(event, null, 2));

  const detail = event.detail || {};
  const productId = detail.productId;
  const images = detail.images || (detail.changes && detail.changes.images) || [];
  const correlationId = detail.correlationId || event.id || "system";

  if (!productId || images.length === 0) {
    console.log("No productId or images found. Skipping thumbnail generation.");
    return { status: "skipped" };
  }

  const processedThumbnails = [];

  for (const imgKey of images) {
    if (imgKey && imgKey.startsWith("products/") && !imgKey.startsWith("thumbnails/")) {
      const fileName = imgKey.split("/").pop();
      const thumbnailKey = `thumbnails/$${fileName}`;

      try {
        console.log(`Fetching original image from S3: $${imgKey}`);
        const getParams = { Bucket: BUCKET, Key: imgKey };
        const s3Object = await s3.send(new GetObjectCommand(getParams));
        
        const bodyBytes = await s3Object.Body.transformToByteArray();

        console.log(`Uploading processed thumbnail to S3: $${thumbnailKey}`);
        const putParams = {
          Bucket: BUCKET,
          Key: thumbnailKey,
          Body: Buffer.from(bodyBytes),
          ContentType: s3Object.ContentType || "image/jpeg",
          Metadata: {
            "processed-by": "thumbnail-generator-lambda",
            "original-key": imgKey,
            "width": "200",
            "height": "200"
          }
        };

        await s3.send(new PutObjectCommand(putParams));
        processedThumbnails.push(thumbnailKey);
        console.log(`Successfully generated thumbnail: $${thumbnailKey}`);
      } catch (err) {
        console.error(`Error processing image $${imgKey}:`, err.message);
        await publishFailure(productId, err.message, imgKey, correlationId);
        throw err;
      }
    } else {
      console.log(`Skipping image: $${imgKey} (either not products/ or already thumbnail)`);
    }
  }

  if (processedThumbnails.length > 0) {
    try {
      console.log(`Updating product $${productId} with thumbnail paths:`, processedThumbnails);
      await docClient.send(
        new UpdateCommand({
          TableName: PRODUCTS_TABLE,
          Key: { productId },
          UpdateExpression: "SET thumbnails = :t, updatedAt = :now",
          ExpressionAttributeValues: {
            ":t": processedThumbnails,
            ":now": new Date().toISOString(),
          },
        })
      );
      console.log(`Successfully updated product $${productId} database record.`);
    } catch (err) {
      console.error(`Failed to update product $${productId} record:`, err.message);
      await publishFailure(productId, err.message, "db_update_failure", correlationId);
      throw err;
    }
  }

  return { status: "success", thumbnails: processedThumbnails };
};
EOF
  }
}

resource "aws_lambda_function" "thumbnail_generator" {
  filename         = data.archive_file.thumbnail_generator.output_path
  function_name    = "${var.project_name}-thumbnail-generator-consumer"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.thumbnail_generator.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      S3_BUCKET_NAME          = var.s3_bucket_product_images_name
      DYNAMODB_TABLE_PRODUCTS = var.dynamodb_table_products_name
      SNS_TOPIC_ARN           = var.sns_topic_product_upload_failure_arn
    }
  }

  tags = {
    Name        = "${var.project_name}-thumbnail-generator-consumer"
    Environment = var.environment
  }
}


# -----------------------------------------------------------------------------
# Lambda 3: Inventory Monitoring Consumer
# -----------------------------------------------------------------------------
data "archive_file" "inventory_monitor" {
  type        = "zip"
  output_path = "${path.module}/inventory_monitor.zip"
  source {
    filename = "index.js"
    content  = <<EOF
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const sns = new SNSClient({});

exports.handler = async (event) => {
  console.log("Received EventBridge event:", JSON.stringify(event, null, 2));

  const detail = event.detail || {};
  const productId = detail.productId || "unknown";
  const productName = detail.name || "unknown";
  const sku = detail.sku || "unknown";
  const stock = detail.stock ?? "unknown";
  const correlationId = detail.correlationId || event.id || "system";

  console.warn(`[ALERT] INVENTORY MONITOR WARNING: Product stock is critically low!`);
  console.warn(`[ALERT] Product Details:
    - ID: $${productId}
    - Name: $${productName}
    - SKU: $${sku}
    - Current Stock: $${stock}
    - Alert Timestamp: $${detail.timestamp || new Date().toISOString()}
  `);

  const topicArn = process.env.SNS_TOPIC_ARN;
  if (!topicArn) {
    console.error("SNS_TOPIC_ARN environment variable not configured.");
    return { status: "skipped", reason: "no_topic_arn" };
  }

  const border = "--------------------------------------------------";
  const formattedMessage = `⚠️ [WARNING] LowInventoryAlert
$${border}
A product's stock has dropped below the threshold.

• Service:        fanvault-commerce-service
• Event Type:     LowInventoryAlert
• Resource:       Product:$${productId}
• Severity:       WARNING
• Timestamp:      $${detail.timestamp || new Date().toISOString()}
• Correlation ID: $${correlationId}

Alert Details:
$${border}
• Product ID:     $${productId}
• Product Name:   $${productName}
• SKU:            $${sku}
• Current Stock:  $${stock}
$${border}
`;

  try {
    const response = await sns.send(new PublishCommand({
      TopicArn: topicArn,
      Message: formattedMessage,
      Subject: `Low Inventory Alert: $${productName} ($${sku})`
    }));
    console.log("Alert published to SNS successfully. MessageId:", response.MessageId);
    return { status: "success", alertSent: true, messageId: response.MessageId };
  } catch (err) {
    console.error("Failed to publish alert to SNS:", err.message);
    throw err;
  }
};
EOF
  }
}

resource "aws_lambda_function" "inventory_monitor" {
  filename         = data.archive_file.inventory_monitor.output_path
  function_name    = "${var.project_name}-inventory-monitor-consumer"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.inventory_monitor.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_low_inventory_arn
    }
  }

  tags = {
    Name        = "${var.project_name}-inventory-monitor-consumer"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# EventBridge Rules & Targets
# -----------------------------------------------------------------------------

# Rule 1: Route all commerce events to Audit Logging Consumer
resource "aws_cloudwatch_event_rule" "audit_logging" {
  name           = "${var.project_name}-audit-logging-rule"
  description    = "Route all commerce domain events to the Audit Logging Lambda"
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name

  event_pattern = jsonencode({
    source = ["fanvault.commerce"]
  })
}

resource "aws_cloudwatch_event_target" "audit_logging" {
  rule           = aws_cloudwatch_event_rule.audit_logging.name
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name
  target_id      = "AuditLoggingTarget"
  arn            = aws_lambda_function.audit_logging.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 3
  }

  dead_letter_config {
    arn = aws_sqs_queue.event_dlq.arn
  }
}

resource "aws_lambda_permission" "audit_logging" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit_logging.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.audit_logging.arn
}

# Rule 2: Route ProductCreated/Updated to Thumbnail Generation Consumer
resource "aws_cloudwatch_event_rule" "thumbnail_generator" {
  name           = "${var.project_name}-thumbnail-generator-rule"
  description    = "Route ProductCreated/ProductUpdated events to the Thumbnail Generator Lambda"
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name

  event_pattern = jsonencode({
    source      = ["fanvault.commerce"]
    detail-type = ["ProductCreated", "ProductUpdated"]
  })
}

resource "aws_cloudwatch_event_target" "thumbnail_generator" {
  rule           = aws_cloudwatch_event_rule.thumbnail_generator.name
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name
  target_id      = "ThumbnailGeneratorTarget"
  arn            = aws_lambda_function.thumbnail_generator.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 3
  }

  dead_letter_config {
    arn = aws_sqs_queue.event_dlq.arn
  }
}

resource "aws_lambda_permission" "thumbnail_generator" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.thumbnail_generator.arn
}

# Rule 3: Route InventoryLow to Inventory Monitoring Consumer
resource "aws_cloudwatch_event_rule" "inventory_monitor" {
  name           = "${var.project_name}-inventory-monitor-rule"
  description    = "Route InventoryLow events to the Inventory Monitor Lambda"
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name

  event_pattern = jsonencode({
    source      = ["fanvault.commerce"]
    detail-type = ["InventoryLow"]
  })
}

resource "aws_cloudwatch_event_target" "inventory_monitor" {
  rule           = aws_cloudwatch_event_rule.inventory_monitor.name
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name
  target_id      = "InventoryMonitorTarget"
  arn            = aws_lambda_function.inventory_monitor.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 3
  }

  dead_letter_config {
    arn = aws_sqs_queue.event_dlq.arn
  }
}

resource "aws_lambda_permission" "inventory_monitor" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inventory_monitor.arn
}

# Rule 4: Route InventoryLow events directly to SNS Low Inventory Alerts topic
resource "aws_cloudwatch_event_rule" "low_inventory_sns" {
  name           = "${var.project_name}-low-inventory-sns-rule"
  description    = "Route InventoryLow events directly to SNS Low Inventory Alerts topic"
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name

  event_pattern = jsonencode({
    source      = ["fanvault.commerce"]
    detail-type = ["InventoryLow"]
  })
}

resource "aws_cloudwatch_event_target" "low_inventory_sns" {
  rule           = aws_cloudwatch_event_rule.low_inventory_sns.name
  event_bus_name = aws_cloudwatch_event_bus.commerce_bus.name
  target_id      = "LowInventorySNSTarget"
  arn            = var.sns_topic_low_inventory_arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 3
  }

  dead_letter_config {
    arn = aws_sqs_queue.event_dlq.arn
  }
}

