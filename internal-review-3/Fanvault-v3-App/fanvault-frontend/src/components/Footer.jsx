import { Link } from 'react-router-dom';
import { Zap, Instagram, Twitter, Youtube } from 'lucide-react';
import './Footer.css';

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-inner">
        <div className="footer-brand">
          <Link to="/" className="footer-logo">
            <Zap size={20} /> FanVault
          </Link>
          <p>Official licensed merchandise for sports teams, movies & shows. Wear your passion.</p>
          <div className="footer-social">
            <a href="#" aria-label="Instagram" className="social-icon"><Instagram size={18} /></a>
            <a href="#" aria-label="Twitter" className="social-icon"><Twitter size={18} /></a>
            <a href="#" aria-label="YouTube" className="social-icon"><Youtube size={18} /></a>
          </div>
        </div>

        <div className="footer-links">
          <div className="footer-col">
            <h4>Shop</h4>
            <Link to="/products?category=clothing">Clothing</Link>
            <Link to="/products?category=accessories">Accessories</Link>
            <Link to="/products?category=shoes">Shoes</Link>
            <Link to="/products?category=ornaments">Collectibles</Link>
          </div>
          <div className="footer-col">
            <h4>Franchises</h4>
            <Link to="/products?franchiseType=sports">Sports</Link>
            <Link to="/products?franchiseType=movie">Movies</Link>
            <Link to="/products?franchiseType=show">Shows</Link>
          </div>
          <div className="footer-col">
            <h4>Account</h4>
            <Link to="/login">Sign In</Link>
            <Link to="/register">Sign Up</Link>
            <Link to="/orders">My Orders</Link>
            <Link to="/profile">Profile</Link>
          </div>
        </div>
      </div>
      <div className="footer-bottom">
        <div className="container">
          <p>© 2025 FanVault. All rights reserved. All trademarks belong to their respective owners.</p>
        </div>
      </div>
    </footer>
  );
}
