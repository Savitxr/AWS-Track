import { Link } from 'react-router-dom';
import { Star, ShoppingCart } from 'lucide-react';
import { useCart } from '../context/CartContext';
import './ProductCard.css';

export default function ProductCard({ product }) {
  const { addItem } = useCart();
  const discount = product.comparePrice
    ? Math.round(((product.comparePrice - product.price) / product.comparePrice) * 100)
    : 0;

  const franchiseTypeColor = {
    sports: 'badge-blue',
    movie: 'badge-amber',
    show: 'badge-green',
  }[product.franchiseType] || 'badge-gray';

  return (
    <div className="product-card">
      <Link to={`/products/${product.productId}`} className="product-image-link">
        <div className="product-image-wrapper">
          <img
            src={product.images?.[0] || 'https://placehold.co/400x400/f4fdf6/2d6a4f?text=No+Image'}
            alt={product.name}
            className="product-image"
            loading="lazy"
          />
          {discount > 0 && (
            <div className="discount-badge">-{discount}%</div>
          )}
          {product.stock === 0 && (
            <div className="out-of-stock-overlay">Out of Stock</div>
          )}
        </div>
      </Link>

      <div className="product-card-body">
        <div className="product-meta">
          <span className={`badge ${franchiseTypeColor}`}>{product.franchiseType}</span>
          <span className="product-franchise">{product.franchise}</span>
        </div>
        <Link to={`/products/${product.productId}`}>
          <h3 className="product-name">{product.name}</h3>
        </Link>

        <div className="product-rating">
          <Star size={13} fill="currentColor" />
          <span>{product.rating?.average?.toFixed(1) || '0.0'}</span>
          <span className="rating-count">({product.rating?.count || 0})</span>
        </div>

        <div className="product-footer">
          <div className="product-price">
            <span className="price-current">₹{product.price.toLocaleString('en-IN')}</span>
            {product.comparePrice && (
              <span className="price-compare">₹{product.comparePrice.toLocaleString('en-IN')}</span>
            )}
          </div>
          <button
            className="btn btn-primary btn-sm add-to-cart-btn"
            disabled={product.stock === 0}
            onClick={() => addItem(product)}
            aria-label={`Add ${product.name} to cart`}
          >
            <ShoppingCart size={14} />
          </button>
        </div>
      </div>
    </div>
  );
}
