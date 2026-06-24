import { Link, useNavigate } from 'react-router-dom';
import { Trash2, ShoppingBag, ArrowLeft, Plus, Minus } from 'lucide-react';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import './CartPage.css';

export default function CartPage() {
  const { items, removeItem, updateQuantity, total, clearCart } = useCart();
  const { user } = useAuth();
  const navigate = useNavigate();

  const shipping = total >= 1999 ? 0 : 99;
  const tax = Math.round(total * 0.18);
  const grandTotal = total + shipping + tax;

  if (items.length === 0) {
    return (
      <div className="page">
        <div className="container">
          <div className="empty-state" style={{ marginTop: 40 }}>
            <ShoppingBag size={64} />
            <h3>Your cart is empty</h3>
            <p>Looks like you haven't added anything yet.</p>
            <Link to="/products" className="btn btn-primary btn-lg">Start Shopping</Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <div className="container">
        <div className="page-header">
          <button className="btn btn-ghost btn-sm" onClick={() => navigate(-1)}>
            <ArrowLeft size={15} /> Continue Shopping
          </button>
          <h1>Shopping Cart</h1>
        </div>

        <div className="cart-layout">
          {/* Items */}
          <div className="cart-items">
            <div className="cart-items-header">
              <span>{items.length} item{items.length > 1 ? 's' : ''}</span>
              <button className="btn btn-ghost btn-sm" onClick={clearCart}>
                <Trash2 size={13} /> Clear All
              </button>
            </div>

            {items.map((item) => (
              <div key={`${item.productId}-${item.size}-${item.color}`} className="cart-item">
                <div className="cart-item-image">
                  <img
                    src={item.image || 'https://placehold.co/100x100/f4fdf6/2d6a4f?text=Item'}
                    alt={item.name}
                  />
                </div>
                <div className="cart-item-details">
                  <Link to={`/products/${item.productId}`} className="cart-item-name">{item.name}</Link>
                  <div className="cart-item-variants">
                    {item.size && <span>Size: <strong>{item.size}</strong></span>}
                    {item.color && <span>Color: <strong>{item.color}</strong></span>}
                    {item.franchise && <span className="badge badge-green" style={{ fontSize: 10 }}>{item.franchise}</span>}
                  </div>
                  <div className="cart-item-bottom">
                    <div className="qty-ctrl">
                      <button className="qty-btn" onClick={() => updateQuantity(item.productId, item.size, item.color, item.quantity - 1)}>
                        <Minus size={12} />
                      </button>
                      <span>{item.quantity}</span>
                      <button className="qty-btn" onClick={() => updateQuantity(item.productId, item.size, item.color, item.quantity + 1)}>
                        <Plus size={12} />
                      </button>
                    </div>
                    <span className="cart-item-price">₹{(item.price * item.quantity).toLocaleString('en-IN')}</span>
                    <button
                      className="remove-btn"
                      onClick={() => removeItem(item.productId, item.size, item.color)}
                      aria-label="Remove item"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Summary */}
          <div className="cart-summary card">
            <div className="card-body">
              <h3>Order Summary</h3>
              <div className="summary-rows">
                <div className="summary-row">
                  <span>Subtotal ({items.length} items)</span>
                  <span>₹{total.toLocaleString('en-IN')}</span>
                </div>
                <div className="summary-row">
                  <span>Shipping</span>
                  <span className={shipping === 0 ? 'free-shipping' : ''}>
                    {shipping === 0 ? 'FREE' : `₹${shipping}`}
                  </span>
                </div>
                <div className="summary-row">
                  <span>Tax (18% GST)</span>
                  <span>₹{tax.toLocaleString('en-IN')}</span>
                </div>
                {shipping > 0 && (
                  <div className="free-shipping-hint">
                    Add ₹{(1999 - total).toLocaleString('en-IN')} more for free shipping!
                  </div>
                )}
                <div className="divider" />
                <div className="summary-row total-row">
                  <span>Total</span>
                  <span>₹{grandTotal.toLocaleString('en-IN')}</span>
                </div>
              </div>
              <button
                className="btn btn-primary btn-full btn-lg"
                onClick={() => user ? navigate('/checkout') : navigate('/login')}
                style={{ marginTop: 16 }}
              >
                <ShoppingBag size={18} />
                {user ? 'Proceed to Checkout' : 'Sign In to Checkout'}
              </button>
              <Link to="/products" className="btn btn-ghost btn-full" style={{ marginTop: 8 }}>
                Continue Shopping
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
