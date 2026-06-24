const express = require('express');
const { body } = require('express-validator');
const { authenticate, adminOnly } = require('../middleware/auth.middleware');
const {
  getAuditLogs,
  getInventory,
  updateStock,
  getMetadata,
  upsertMetadata,
  deactivateMetadata,
} = require('../controllers/admin.controller');

const router = express.Router();

// All admin routes require authentication + admin role
router.use(authenticate, adminOnly);

// ── Audit Logs ────────────────────────────────────────────────────────────────
router.get('/audit-logs', getAuditLogs);

// ── Inventory Management ─────────────────────────────────────────────────────
router.get('/inventory', getInventory);
router.patch('/inventory/:productId', [
  body('stock').isInt({ min: 0 }).withMessage('Stock must be a non-negative integer'),
], updateStock);

// ── Metadata (Categories & Franchises) ───────────────────────────────────────
router.get('/metadata/:metaType', getMetadata);
router.post('/metadata/:metaType', [
  body('metaId').notEmpty().withMessage('metaId is required'),
  body('displayName').notEmpty().withMessage('displayName is required'),
], upsertMetadata);
router.delete('/metadata/:metaType/:metaId', deactivateMetadata);

module.exports = router;
