import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Star, ShoppingCart, Package, Truck, Shield, Check } from 'lucide-react';
import { productAPI } from '../api/client';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import './ProductDetailPage.css';

export default function ProductDetailPage() {
  const { productId } = useParams();
  const navigate = useNavigate();
  const { addItem } = useCart();
  const { user } = useAuth();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedSize, setSelectedSize] = useState(null);
  const [selectedColor, setSelectedColor] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [activeImage, setActiveImage] = useState(0);

  useEffect(() => {
    productAPI.getProduct(productId)
      .then(({ data }) => {
        setProduct(data.product);
        if (data.product.sizes?.length > 0) setSelectedSize(data.product.sizes[0]);
        if (data.product.colors?.length > 0) setSelectedColor(data.product.colors[0]);
      })
      .catch(() => navigate('/products'))
      .finally(() => setLoading(false));
  }, [productId, navigate]);

  if (loading) return <div className="loading-screen"><div className="spinner" /></div>;
  if (!product) return null;

  const discount = product.comparePrice
    ? Math.round(((product.comparePrice - product.price) / product.comparePrice) * 100)
    : 0;

  const handleAddToCart = () => {
    addItem(product, quantity, selectedSize, selectedColor);
  };

  const handleBuyNow = () => {
    addItem(product, quantity, selectedSize, selectedColor);
    if (user) navigate('/checkout');
    else navigate('/login');
  };

  const franchiseTypeColor = { sports: 'badge-blue', movie: 'badge-amber', show: 'badge-green' }[product.franchiseType] || 'badge-gray';

  return (
    <div className="product-detail-page page">
      <div className="container">
        {/* Breadcrumb */}
        <div className="breadcrumb">
          <button className="btn btn-ghost btn-sm" onClick={() => navigate(-1)}>
            <ArrowLeft size={15} /> Back
          </button>
          <span>/</span>
          <Link to="/products">Products</Link>
          <span>/</span>
          <span className="breadcrumb-current">{product.name}</span>
        </div>

        <div className="product-detail-layout">
          {/* Images */}
          <div className="product-images">
            <div className="main-image-wrapper">
              <img
                src={product.images?.[activeImage] || 'https://placehold.co/600x600/f4fdf6/2d6a4f?text=No+Image'}
                alt={product.name}
                className="main-image"
              />
              {discount > 0 && <div className="detail-discount-badge">-{discount}% OFF</div>}
            </div>
            {product.images?.length > 1 && (
              <div className="image-thumbnails">
                {product.images.map((img, i) => (
                  <button key={i} className={`thumbnail ${activeImage === i ? 'active' : ''}`} onClick={() => setActiveImage(i)}>
                    <img src={img} alt={`${product.name} view ${i + 1}`} />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Info */}
          <div className="product-info">
            <div className="product-tags">
              <span className={`badge ${franchiseTypeColor}`}>{product.franchiseType}</span>
              <span className="badge badge-gray">{product.category}</span>
              {product.stock <= 5 && product.stock > 0 && (
                <span className="badge badge-red">Only {product.stock} left</span>
              )}
            </div>

            <h1 className="product-detail-name">{product.name}</h1>

            <div className="product-detail-meta">
              <span className="franchise-tag">{product.franchise}</span>
              <div className="rating-display">
                {[1,2,3,4,5].map((s) => (
                  <Star key={s} size={15} fill={s <= Math.round(product.rating?.average) ? 'currentColor' : 'none'} />
                ))}
                <span>{product.rating?.average?.toFixed(1)}</span>
                <span className="rating-count">({product.rating?.count} reviews)</span>
              </div>
            </div>

            <div className="price-section">
              <span className="detail-price">₹{product.price.toLocaleString('en-IN')}</span>
              {product.comparePrice && (
                <>
                  <span className="detail-compare">₹{product.comparePrice.toLocaleString('en-IN')}</span>
                  <span className="detail-savings">Save ₹{(product.comparePrice - product.price).toLocaleString('en-IN')}</span>
                </>
              )}
            </div>

            <p className="product-detail-desc">{product.description}</p>

            {/* Sizes */}
            {product.sizes?.length > 0 && (
              <div className="option-group">
                <label className="option-label">Size: <strong>{selectedSize}</strong></label>
                <div className="option-chips">
                  {product.sizes.map((s) => (
                    <button key={s} className={`option-chip ${selectedSize === s ? 'active' : ''}`} onClick={() => setSelectedSize(s)}>{s}</button>
                  ))}
                </div>
              </div>
            )}

            {/* Colors */}
            {product.colors?.length > 0 && (
              <div className="option-group">
                <label className="option-label">Color: <strong>{selectedColor}</strong></label>
                <div className="option-chips">
                  {product.colors.map((c) => (
                    <button key={c} className={`option-chip ${selectedColor === c ? 'active' : ''}`} onClick={() => setSelectedColor(c)}>{c}</button>
                  ))}
                </div>
              </div>
            )}

            {/* Quantity */}
            <div className="option-group">
              <label className="option-label">Quantity</label>
              <div className="quantity-control">
                <button className="qty-btn" onClick={() => setQuantity(q => Math.max(1, q - 1))} disabled={quantity <= 1}>−</button>
                <span className="qty-display">{quantity}</span>
                <button className="qty-btn" onClick={() => setQuantity(q => Math.min(product.stock, q + 1))} disabled={quantity >= product.stock}>+</button>
              </div>
            </div>

            {/* Actions */}
            <div className="product-actions">
              <button className="btn btn-primary btn-lg btn-full" onClick={handleAddToCart} disabled={product.stock === 0}>
                <ShoppingCart size={18} />
                {product.stock === 0 ? 'Out of Stock' : 'Add to Cart'}
              </button>
              <button className="btn btn-secondary btn-lg btn-full" onClick={handleBuyNow} disabled={product.stock === 0}>
                Buy Now
              </button>
            </div>

            {/* Guarantees */}
            <div className="product-guarantees">
              <div className="guarantee-item"><Check size={14} /> Authentic & Licensed</div>
              <div className="guarantee-item"><Truck size={14} /> Free shipping above ₹1999</div>
              <div className="guarantee-item"><Shield size={14} /> Secure checkout</div>
              <div className="guarantee-item"><Package size={14} /> Easy returns</div>
            </div>

            {/* Tags */}
            {product.tags?.length > 0 && (
              <div className="product-tags-list">
                {product.tags.map((t) => <span key={t} className="tag">#{t}</span>)}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
