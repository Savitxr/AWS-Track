const { PutCommand } = require('@aws-sdk/lib-dynamodb');
const { getDocClient } = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const TABLE = () => process.env.DYNAMODB_TABLE_AUDIT_LOGS || 'fanvault-audit-logs';

/**
 * Fire-and-forget audit log writer.
 * Failures are logged to console but NEVER thrown — audit must never block the request.
 *
 * @param {object} opts
 * @param {string} opts.adminId     - JWT user ID of the acting admin
 * @param {string} opts.adminEmail  - JWT email of the acting admin
 * @param {string} opts.action      - e.g. PRODUCT_CREATED, STOCK_UPDATED
 * @param {string} opts.entityType  - e.g. product, inventory, category
 * @param {string} opts.entityId    - ID of the affected entity
 * @param {object} [opts.changes]   - Before/after snapshot (optional)
 */
async function logAuditEvent({ adminId, adminEmail, action, entityType, entityId, changes }) {
  const now = new Date();
  const ttlExpiry = Math.floor(now.getTime() / 1000) + 86400; // 1-day TTL

  const item = {
    logId:      uuidv4(),
    adminId:    adminId || 'unknown',
    adminEmail: adminEmail || 'unknown',
    action,
    entityType,
    entityId:   entityId || 'unknown',
    changes:    changes ? JSON.stringify(changes) : null,
    timestamp:  now.toISOString(),
    ttlExpiry,
  };

  try {
    await getDocClient().send(
      new PutCommand({ TableName: TABLE(), Item: item })
    );
    console.log(`[audit] ${action} | entity=${entityType}:${entityId} | admin=${adminEmail}`);
  } catch (err) {
    console.error('[audit] Failed to write audit log:', err.message);
  }
}

module.exports = { logAuditEvent };
