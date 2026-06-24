import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Shield, Truck, Award, Zap } from 'lucide-react';
import { productAPI } from '../api/client';
import ProductCard from '../components/ProductCard';
import './HomePage.css';

const CATEGORIES = [
  { key: 'clothing', label: 'Clothing', emoji: '👕', desc: 'Jerseys, hoodies, tees' },
  { key: 'accessories', label: 'Accessories', emoji: '🎒', desc: 'Caps, bags, scarves' },
  { key: 'shoes', label: 'Shoes', emoji: '👟', desc: 'Sneakers, boots' },
  { key: 'ornaments', label: 'Collectibles', emoji: '🏆', desc: 'Replicas, figurines' },
];

const FRANCHISES = [
  { name: 'Real Madrid', type: 'sports', emoji: '⚽', color: '#f8fafc' },
  { name: 'Mumbai Indians', type: 'sports', emoji: '🏏', color: '#f0f9ff' },
  { name: 'Chicago Bulls', type: 'sports', emoji: '🏀', color: '#fff1f2' },
  { name: 'Avengers', type: 'movie', emoji: '🦸', color: '#fefce8' },
  { name: 'Harry Potter', type: 'movie', emoji: '⚡', color: '#fdf4ff' },
  { name: 'Game of Thrones', type: 'show', emoji: '🐉', color: '#f0fdf4' },
];

export default function HomePage() {
  const [featured, setFeatured] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    productAPI.getProducts({ limit: 8, sortBy: 'rating.average', order: 'desc' })
      .then(({ data }) => setFeatured(Array.isArray(data?.products) ? data.products : []))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="home-page">
      {/* Hero */}
      <section className="hero">
        <div className="hero-content container">
          <div className="hero-badge">
            <Zap size={14} /> Official Licensed Merchandise
          </div>
          <h1 className="hero-title">
            Wear Your <span className="hero-gradient">Fandom</span>
          </h1>
          <p className="hero-subtitle">
            Official merchandise for your favourite sports teams, movies & shows.
            From jerseys to collectibles — all in one place.
          </p>
          <div className="hero-actions">
            <Link to="/products" className="btn btn-primary btn-lg">
              Shop Now <ArrowRight size={18} />
            </Link>
            <Link to="/products?franchiseType=sports" className="btn btn-secondary btn-lg">
              Explore Sports
            </Link>
          </div>
          <div className="hero-stats">
            <div className="stat"><span>500+</span><p>Products</p></div>
            <div className="stat-divider" />
            <div className="stat"><span>50+</span><p>Franchises</p></div>
            <div className="stat-divider" />
            <div className="stat"><span>100%</span><p>Official</p></div>
          </div>
        </div>
        <div className="hero-decoration">
          {['⚽','🏏','🏀','🦸','⚡','🐉','🎬','🏆'].map((em, i) => (
            <span key={i} className="hero-emoji" style={{ '--delay': `${i * 0.3}s`, '--x': `${Math.random() * 80 + 10}%`, '--y': `${Math.random() * 80 + 10}%` }}>{em}</span>
          ))}
        </div>
      </section>

      {/* Features strip */}
      <section className="features-strip">
        <div className="container features-grid">
          <div className="feature-item">
            <Shield size={20} />
            <div><strong>100% Authentic</strong><span>Official licensed products</span></div>
          </div>
          <div className="feature-item">
            <Truck size={20} />
            <div><strong>Free Shipping</strong><span>On orders above ₹1999</span></div>
          </div>
          <div className="feature-item">
            <Award size={20} />
            <div><strong>Premium Quality</strong><span>Guaranteed satisfaction</span></div>
          </div>
        </div>
      </section>

      {/* Categories */}
      <section className="section container">
        <div className="section-header">
          <h2>Shop by Category</h2>
          <p>Find exactly what you're looking for</p>
        </div>
        <div className="categories-grid">
          {CATEGORIES.map((cat) => (
            <Link key={cat.key} to={`/products?category=${cat.key}`} className="category-card">
              <div className="category-emoji">{cat.emoji}</div>
              <h3>{cat.label}</h3>
              <p>{cat.desc}</p>
              <span className="category-cta">Shop Now <ArrowRight size={14} /></span>
            </Link>
          ))}
        </div>
      </section>

      {/* Featured Products */}
      <section className="section featured-section">
        <div className="container">
          <div className="section-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
            <div>
              <h2>Featured Products</h2>
              <p>Top-rated merchandise from our collection</p>
            </div>
            <Link to="/products" className="btn btn-secondary btn-sm">
              View All <ArrowRight size={14} />
            </Link>
          </div>
          {loading ? (
            <div className="loading-screen"><div className="spinner" /><span>Loading products...</span></div>
          ) : (
            <div className="product-grid">
              {featured.map((p) => <ProductCard key={p.productId} product={p} />)}
            </div>
          )}
        </div>
      </section>

      {/* Franchises */}
      <section className="section container">
        <div className="section-header">
          <h2>Shop by Franchise</h2>
          <p>Your favourite teams and universes, all in one place</p>
        </div>
        <div className="franchises-grid">
          {FRANCHISES.map((f) => (
            <Link
              key={f.name}
              to={`/products?franchise=${encodeURIComponent(f.name)}`}
              className="franchise-card"
              style={{ '--bg': f.color }}
            >
              <div className="franchise-emoji">{f.emoji}</div>
              <h4>{f.name}</h4>
              <span className={`badge ${f.type === 'sports' ? 'badge-blue' : f.type === 'movie' ? 'badge-amber' : 'badge-green'}`}>{f.type}</span>
            </Link>
          ))}
        </div>
      </section>

      {/* CTA Banner */}
      <section className="cta-banner">
        <div className="container cta-inner">
          <div>
            <h2>Ready to show your fandom?</h2>
            <p>Join thousands of fans who shop official merchandise at FanVault.</p>
          </div>
          <div className="cta-actions">
            <Link to="/register" className="btn btn-primary btn-lg">Create Account</Link>
            <Link to="/products" className="btn btn-secondary btn-lg" style={{ background: 'rgba(255,255,255,0.15)', border: '2px solid rgba(255,255,255,0.4)', color: 'white' }}>
              Browse Products
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
