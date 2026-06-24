const { QueryCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { getDocClient } = require('../config/db');

const TABLE = () => process.env.DYNAMODB_TABLE_AUDIT_LOGS || 'fanvault-audit-logs';

const AuditLogRepository = {
  // List logs by entityType using GSI
  async listByEntityType(entityType, { limit = 50, lastKey } = {}) {
    const result = await getDocClient().send(
      new QueryCommand({
        TableName:                 TABLE(),
        IndexName:                 'entityType-timestamp-index',
        KeyConditionExpression:    'entityType = :et',
        ExpressionAttributeValues: { ':et': entityType },
        Limit:                     Number(limit),
        ExclusiveStartKey:         lastKey,
        ScanIndexForward:          false,
      })
    );
    return {
      logs:    result.Items || [],
      lastKey: result.LastEvaluatedKey || null,
      hasMore: !!result.LastEvaluatedKey,
    };
  },

  // List logs by adminId using GSI
  async listByAdmin(adminId, { limit = 50, lastKey } = {}) {
    const result = await getDocClient().send(
      new QueryCommand({
        TableName:                 TABLE(),
        IndexName:                 'adminId-timestamp-index',
        KeyConditionExpression:    'adminId = :aid',
        ExpressionAttributeValues: { ':aid': adminId },
        Limit:                     Number(limit),
        ExclusiveStartKey:         lastKey,
        ScanIndexForward:          false,
      })
    );
    return {
      logs:    result.Items || [],
      lastKey: result.LastEvaluatedKey || null,
      hasMore: !!result.LastEvaluatedKey,
    };
  },

  // Scan all logs (admin overview, no filter)
  async listAll({ limit = 50, lastKey } = {}) {
    const now = Math.floor(Date.now() / 1000);
    const result = await getDocClient().send(
      new ScanCommand({
        TableName:                 TABLE(),
        FilterExpression:          'attribute_not_exists(ttlExpiry) OR ttlExpiry > :now',
        ExpressionAttributeValues: { ':now': now },
        Limit:                     Number(limit),
        ExclusiveStartKey:         lastKey,
      })
    );
    return {
      logs:    result.Items || [],
      lastKey: result.LastEvaluatedKey || null,
      hasMore: !!result.LastEvaluatedKey,
    };
  },
};

module.exports = AuditLogRepository;
