import { useState, useEffect } from 'react';
import { adminAPI } from '../../api/client';
import toast from 'react-hot-toast';

const STATUSES = ['placed', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];

export default function AdminOrders() {
  const [orders,   setOrders]   = useState([]);
  const [status,   setStatus]   = useState('');
  const [loading,  setLoading]  = useState(true);
  const [updating, setUpdating] = useState(null);

  const load = async () => {
    setLoading(true);
    try {
      const { data } = await adminAPI.getAllOrders({ status: status || undefined, limit: 50 });
      setOrders(data.orders || []);
    } catch { toast.error('Failed to load orders'); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [status]);

  const handleStatusChange = async (orderId, newStatus) => {
    setUpdating(orderId);
    try {
      await adminAPI.updateOrderStatus(orderId, { status: newStatus });
      setOrders(prev => prev.map(o => o.orderId === orderId ? { ...o, status: newStatus } : o));
      toast.success('Order status updated');
    } catch { toast.error('Failed to update order'); }
    finally { setUpdating(null); }
  };

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div>
          <h1>Orders</h1>
          <p>{orders.length} order{orders.length !== 1 ? 's' : ''} shown</p>
        </div>
        <select
          value={status}
          onChange={e => setStatus(e.target.value)}
          style={{ padding: '8px 12px', borderRadius: 8, border: '1px solid var(--border)', fontFamily: 'inherit', fontSize: 13 }}
        >
          <option value="">All Statuses</option>
          {STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
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
                  <th>Order #</th><th>Customer</th><th>Items</th>
                  <th>Total</th><th>Current Status</th><th>Date</th><th>Update Status</th>
                </tr>
              </thead>
              <tbody>
                {orders.length === 0 ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>
                      No orders found
                    </td>
                  </tr>
                ) : orders.map(o => (
                  <tr key={o.orderId}>
                    <td><code style={{ fontSize: 12 }}>{o.orderNumber}</code></td>
                    <td style={{ fontSize: 12 }}>{o.userEmail}</td>
                    <td style={{ fontSize: 12 }}>{o.items?.length || 0} item(s)</td>
                    <td style={{ fontWeight: 600 }}>₹{o.total?.toLocaleString('en-IN')}</td>
                    <td>
                      <span className={`status-badge status-${o.status}`}>{o.status}</span>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--gray-400)' }}>
                      {new Date(o.createdAt).toLocaleDateString('en-IN')}
                    </td>
                    <td>
                      <select
                        value={o.status}
                        onChange={e => handleStatusChange(o.orderId, e.target.value)}
                        disabled={updating === o.orderId}
                        style={{ padding: '5px 8px', borderRadius: 6, border: '1px solid var(--border)', fontSize: 12, fontFamily: 'inherit' }}
                      >
                        {STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
