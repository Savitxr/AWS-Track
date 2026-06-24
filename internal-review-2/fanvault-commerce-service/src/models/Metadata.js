const {
  PutCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
} = require('@aws-sdk/lib-dynamodb');
const { getDocClient } = require('../config/db');

const TABLE = () => process.env.DYNAMODB_TABLE_METADATA || 'fanvault-metadata';

const MetadataRepository = {
  // List all entries of a given metaType (e.g. 'category' or 'franchise')
  async list(metaType) {
    const result = await getDocClient().send(
      new QueryCommand({
        TableName:                 TABLE(),
        KeyConditionExpression:    'metaType = :mt',
        ExpressionAttributeValues: { ':mt': metaType },
      })
    );
    return result.Items || [];
  },

  // Create or fully overwrite a metadata entry
  async upsert(metaType, metaId, data) {
    const now  = new Date().toISOString();
    const item = {
      metaType,
      metaId,
      displayName:  data.displayName  || metaId,
      description:  data.description  || null,
      iconKey:      data.iconKey       || null,
      franchiseType: data.franchiseType || null, // for franchise entries: 'sports'|'movie'|'show'
      isActive:     data.isActive !== false,
      sortOrder:    data.sortOrder    || 0,
      createdAt:    data.createdAt    || now,
      updatedAt:    now,
    };
    await getDocClient().send(
      new PutCommand({ TableName: TABLE(), Item: item })
    );
    return item;
  },

  // Soft-delete: set isActive = false
  async deactivate(metaType, metaId) {
    const result = await getDocClient().send(
      new UpdateCommand({
        TableName:                 TABLE(),
        Key:                       { metaType, metaId },
        UpdateExpression:          'SET isActive = :f, updatedAt = :now',
        ExpressionAttributeValues: { ':f': false, ':now': new Date().toISOString() },
        ConditionExpression:       'attribute_exists(metaType)',
        ReturnValues:              'ALL_NEW',
      })
    );
    return result.Attributes;
  },
};

module.exports = MetadataRepository;
