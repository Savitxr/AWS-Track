import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Package, Truck, CheckCircle, Clock, X, MapPin } from 'lucide-react';
import { orderAPI } from '../api/client';
import toast from 'react-hot-toast';

const STEPS = ['placed', 'confirmed', 'processing', 'shipped', 'delivered'];

export default function OrderDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [order, setOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState(false);

  useEffect(() => {
    orderAPI.getOrder(id)
      .then(({ data }) => setOrder(data.order))
      .catch(() => navigate('/orders'))
      .finally(() => setLoading(false));
  }, [id, navigate]);

  const handleCancel = async () => {
    if (!window.confirm('Cancel this order?')) return;
    setCancelling(true);
    try {
      const { data } = await orderAPI.cancelOrder(id);
      setOrder(data.order);
      toast.success('Order cancelled');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed to cancel order');
    } finally {
      setCancelling(false);
    }
  };

  if (loading) return <div className="loading-screen"><div className="spinner" /></div>;
  if (!order) return null;

  const currentStep = STEPS.indexOf(order.status);
  const isCancelled = order.status === 'cancelled';

  const statusColors = { placed: 'badge-amber', confirmed: 'badge-blue', processing: 'badge-blue', shipped: 'badge-blue', delivered: 'badge-green', cancelled: 'badge-red' };

  return (
    <div className="page">
      <div className="container" style={{ maxWidth: 800 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 28, flexWrap: 'wrap' }}>
          <button className="btn btn-ghost btn-sm" onClick={() => navigate('/orders')}>
            <ArrowLeft size={15} /> My Orders
          </button>
          <h1 style={{ fontSize: '1.6rem', margin: 0 }}>Order #{order.orderNumber}</h1>
          <span className={`badge ${statusColors[order.status]}`}>
            {order.status.charAt(0).toUpperCase() + order.status.slice(1)}
          </span>
        </div>

        {/* Progress tracker */}
        {!isCancelled && (
          <div className="card card-body" style={{ marginBottom: 20 }}>
            <div className="order-progress">
              {STEPS.map((step, i) => (
                <div key={step} className={`progress-step ${i <= currentStep ? 'done' : ''} ${i === currentStep ? 'active' : ''}`}>
                  <div className="progress-icon">
                    {i < currentStep ? <CheckCircle size={18} /> : i === 0 ? <Clock size={18} /> : i < 3 ? <Package size={18} /> : <Truck size={18} />}
                  </div>
                  <span>{step.charAt(0).toUpperCase() + step.slice(1)}</span>
                  {i < STEPS.length - 1 && <div className={`progress-line ${i < currentStep ? 'done' : ''}`} />}
                </div>
              ))}
            </div>
          </div>
        )}

        {isCancelled && (
          <div style={{ background: '#fee2e2', border: '1px solid #fca5a5', borderRadius: 'var(--radius-md)', padding: '16px 20px', marginBottom: 20, display: 'flex', gap: 10, alignItems: 'center' }}>
            <X size={18} color="#dc2626" />
            <span style={{ fontSize: 14, color: '#991b1b', fontWeight: 600 }}>This order has been cancelled.</span>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
          {/* Items */}
          <div className="card card-body" style={{ gridColumn: '1 / -1' }}>
            <h3 style={{ marginBottom: 16 }}>Items ({order.items.length})</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {order.items.map((item, i) => (
                <div key={i} style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                  <div style={{ width: 64, height: 64, borderRadius: 'var(--radius)', overflow: 'hidden', border: '1px solid var(--border)', flexShrink: 0 }}>
                    <img src={item.image || 'https://placehold.co/64x64/f4fdf6/2d6a4f?text=Item'} alt={item.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <p style={{ fontWeight: 600, fontSize: 14, margin: '0 0 4px', color: 'var(--text-primary)' }}>{item.name}</p>
                    <div style={{ display: 'flex', gap: 10, fontSize: 12, color: 'var(--text-muted)' }}>
                      {item.size && <span>Size: {item.size}</span>}
                      {item.color && <span>Color: {item.color}</span>}
                      <span>Qty: {item.quantity}</span>
                    </div>
                  </div>
                  <span style={{ fontWeight: 700, color: 'var(--brand-dark)' }}>₹{(item.price * item.quantity).toLocaleString('en-IN')}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Shipping */}
          <div className="card card-body">
            <h3 style={{ marginBottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}><MapPin size={16} /> Delivery Address</h3>
            <div style={{ fontSize: 14, color: 'var(--text-secondary)', lineHeight: 1.7 }}>
              <p style={{ margin: 0 }}>{order.shippingAddress.line1}</p>
              {order.shippingAddress.line2 && <p style={{ margin: 0 }}>{order.shippingAddress.line2}</p>}
              <p style={{ margin: 0 }}>{order.shippingAddress.city}, {order.shippingAddress.state}</p>
              <p style={{ margin: 0 }}>{order.shippingAddress.postalCode}, {order.shippingAddress.country}</p>
            </div>
          </div>

          {/* Summary */}
          <div className="card card-body">
            <h3 style={{ marginBottom: 12 }}>Order Summary</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, fontSize: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-secondary)' }}>
                <span>Subtotal</span><span>₹{order.subtotal?.toLocaleString('en-IN')}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-secondary)' }}>
                <span>Shipping</span><span>{order.shippingCost === 0 ? 'FREE' : `₹${order.shippingCost}`}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-secondary)' }}>
                <span>Tax (GST)</span><span>₹{order.tax?.toLocaleString('en-IN')}</span>
              </div>
              <div style={{ height: 1, background: 'var(--border)', margin: '4px 0' }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 800, fontSize: 16, color: 'var(--brand-dark)' }}>
                <span>Total</span><span>₹{order.total?.toLocaleString('en-IN')}</span>
              </div>
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>
                Payment: {order.paymentMethod?.toUpperCase()}
                {' · '}
                <span className={`badge ${order.paymentStatus === 'paid' ? 'badge-green' : 'badge-amber'}`}>{order.paymentStatus}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', gap: 12, marginTop: 24, flexWrap: 'wrap' }}>
          <Link to="/products" className="btn btn-secondary">Continue Shopping</Link>
          {!isCancelled && !['shipped', 'delivered'].includes(order.status) && (
            <button className="btn btn-danger" onClick={handleCancel} disabled={cancelling}>
              {cancelling ? 'Cancelling...' : 'Cancel Order'}
            </button>
          )}
        </div>
      </div>

      <style>{`
        .order-progress { display: flex; align-items: center; gap: 0; }
        .progress-step { display: flex; align-items: center; gap: 8px; flex-direction: column; position: relative; flex: 1; }
        .progress-step > div:first-child { flex-direction: row; display: flex; align-items: center; gap: 8px; }
        .progress-step { flex-direction: row; align-items: center; gap: 0; flex: 1; }
        .progress-icon { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: var(--gray-100); color: var(--text-muted); flex-shrink: 0; transition: all var(--transition); }
        .progress-step.done .progress-icon, .progress-step.active .progress-icon { background: var(--brand); color: white; }
        .progress-step span { font-size: 12px; font-weight: 600; color: var(--text-muted); white-space: nowrap; padding: 0 8px; }
        .progress-step.done span, .progress-step.active span { color: var(--brand); }
        .progress-line { flex: 1; height: 2px; background: var(--border); transition: background var(--transition); }
        .progress-line.done { background: var(--brand); }
        @media (max-width: 600px) { .progress-step span { display: none; } }
      `}</style>
    </div>
  );
}
