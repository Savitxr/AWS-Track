import { useState, useEffect } from 'react';
import { adminAPI } from '../../api/client';
import toast from 'react-hot-toast';

const ENTITY_TYPES = ['product', 'inventory', 'category'];

const ACTION_COLORS = {
  PRODUCT_CREATED:             { bg: '#f0fdf4', color: '#16a34a' },
  PRODUCT_UPDATED:             { bg: '#eff6ff', color: '#2563eb' },
  PRODUCT_DELETED:             { bg: '#fef2f2', color: '#dc2626' },
  STOCK_UPDATED:               { bg: '#fff7ed', color: '#c2410c' },
  METADATA_UPSERTED:           { bg: '#f5f3ff', color: '#7c3aed' },
  METADATA_DEACTIVATED:        { bg: '#fef2f2', color: '#dc2626' },
  IMAGE_UPLOAD_URL_GENERATED:  { bg: '#ecfeff', color: '#0891b2' },
};

export default function AdminAudit() {
  const [logs,       setLogs]       = useState([]);
  const [entityType, setEntityType] = useState('');
  const [loading,    setLoading]    = useState(true);

  useEffect(() => {
    setLoading(true);
    adminAPI.getAuditLogs({ entityType: entityType || undefined, limit: 100 })
      .then(({ data }) => setLogs(data.logs || []))
      .catch(() => toast.error('Failed to load audit logs'))
      .finally(() => setLoading(false));
  }, [entityType]);

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div>
          <h1>Audit Log</h1>
          <p>All admin actions — 1-day retention (DynamoDB TTL)</p>
        </div>
        <select
          value={entityType}
          onChange={e => setEntityType(e.target.value)}
          style={{ padding: '8px 12px', borderRadius: 8, border: '1px solid var(--border)', fontFamily: 'inherit', fontSize: 13 }}
        >
          <option value="">All Types</option>
          {ENTITY_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
        </select>
      </div>

      <div className="admin-card">
        {loading ? (
          <div className="loading-screen" style={{ minHeight: 200 }}><div className="spinner" /></div>
        ) : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Action</th><th>Entity Type</th><th>Entity ID</th>
                  <th>Admin</th><th>Changes</th><th>Timestamp</th>
                </tr>
              </thead>
              <tbody>
                {logs.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>
                      No audit events found
                    </td>
                  </tr>
                ) : logs.map(l => {
                  const style = ACTION_COLORS[l.action] || { bg: '#f9fafb', color: '#6b7280' };
                  return (
                    <tr key={l.logId}>
                      <td>
                        <span style={{
                          display: 'inline-flex', alignItems: 'center',
                          padding: '3px 8px', borderRadius: 9999,
                          fontSize: 11, fontWeight: 600, fontFamily: 'monospace',
                          background: style.bg, color: style.color,
                          whiteSpace: 'nowrap',
                        }}>
                          {l.action}
                        </span>
                      </td>
                      <td>
                        <span className="status-badge status-placed">{l.entityType}</span>
                      </td>
                      <td style={{ fontSize: 12, maxWidth: 140, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {l.entityId}
                      </td>
                      <td style={{ fontSize: 12 }}>{l.adminEmail}</td>
                      <td style={{ fontSize: 11.5, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--gray-400)', fontFamily: 'monospace' }}>
                        {l.changes || '—'}
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--gray-400)', whiteSpace: 'nowrap' }}>
                        {new Date(l.timestamp).toLocaleString('en-IN')}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
