import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Package, ShoppingBag, AlertTriangle, ClipboardList, ArrowRight } from 'lucide-react';
import { adminAPI } from '../../api/client';

export default function AdminDashboard() {
  const [stats, setStats]   = useState({ products: 0, orders: 0, lowStock: 0, outStock: 0 });
  const [logs,  setLogs]    = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const [invRes, logRes, ordRes] = await Promise.all([
          adminAPI.getInventory({ limit: 200 }),
          adminAPI.getAuditLogs({ limit: 8 }),
          adminAPI.getAllOrders({ limit: 1 }),
        ]);
        const inv = invRes.data.inventory || [];
        setStats({
          products: inv.length,
          orders:   ordRes.data.pagination?.count ?? 0,
          lowStock: inv.filter(p => p.stock > 0 && p.stock <= 5).length,
          outStock: inv.filter(p => p.stock === 0).length,
        });
        setLogs(logRes.data.logs || []);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const STATS = [
    { label: 'Total Products', value: stats.products, icon: Package,       cls: 'brand' },
    { label: 'Low Stock',      value: stats.lowStock,  icon: AlertTriangle,  cls: 'warn'  },
    { label: 'Out of Stock',   value: stats.outStock,  icon: AlertTriangle,  cls: 'danger' },
    { label: 'Recent Logs',    value: logs.length,     icon: ClipboardList,  cls: '' },
  ];

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div><h1>Dashboard</h1><p>Overview of your FanVault store</p></div>
      </div>

      {loading ? <div className="loading-screen"><div className="spinner" /></div> : (
        <>
          <div className="admin-stat-grid">
            {STATS.map(s => (
              <div key={s.label} className={`admin-stat-card ${s.cls}`}>
                <p className="admin-stat-label">{s.label}</p>
                <p className="admin-stat-value">{s.value}</p>
              </div>
            ))}
          </div>

          <div className="admin-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <h3 style={{ margin: 0, fontSize: '1rem' }}>Recent Audit Events</h3>
              <Link to="/admin/audit" className="btn btn-ghost btn-sm" style={{ fontSize: 12 }}>View all <ArrowRight size={13} /></Link>
            </div>
            {logs.length === 0 ? <p style={{ color: 'var(--gray-400)', fontSize: 13 }}>No audit events yet.</p> : (
              <table className="admin-table">
                <thead><tr><th>Action</th><th>Entity</th><th>Admin</th><th>Time</th></tr></thead>
                <tbody>
                  {logs.map(l => (
                    <tr key={l.logId}>
                      <td><code style={{ fontSize: 12 }}>{l.action}</code></td>
                      <td style={{ fontSize: 12 }}>{l.entityType}: {l.entityId}</td>
                      <td style={{ fontSize: 12 }}>{l.adminEmail}</td>
                      <td style={{ fontSize: 12, color: 'var(--gray-400)' }}>{new Date(l.timestamp).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </div>
  );
}
