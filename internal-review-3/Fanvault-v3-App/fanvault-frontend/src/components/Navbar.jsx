import { useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { ShoppingCart, User, Menu, X, Zap, LogOut, Package, ChevronDown, Shield } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';
import toast from 'react-hot-toast';
import './Navbar.css';

export default function Navbar() {
  const { user, logout } = useAuth();
  const { count } = useCart();
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    toast.success('Logged out successfully');
    navigate('/');
    setDropdownOpen(false);
    setMobileOpen(false);
  };

  return (
    <nav className="navbar">
      <div className="navbar-inner container">
        {/* Logo */}
        <Link to="/" className="navbar-logo">
          <Zap size={22} />
          <span>FanVault</span>
        </Link>

        {/* Desktop Nav Links */}
        <div className="navbar-links">
          <NavLink to="/" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'} end>
            Home
          </NavLink>
          <NavLink to="/products" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            Shop
          </NavLink>
        </div>

        {/* Actions */}
        <div className="navbar-actions">
          {/* Cart */}
          <Link to="/cart" className="navbar-icon-btn" aria-label="Cart">
            <ShoppingCart size={20} />
            {count > 0 && <span className="cart-badge">{count > 99 ? '99+' : count}</span>}
          </Link>

          {/* User */}
          {user ? (
            <div className="user-dropdown">
              <button
                className="navbar-user-btn"
                onClick={() => setDropdownOpen(!dropdownOpen)}
                aria-label="User menu"
              >
                <div className="user-avatar">{user.email.charAt(0).toUpperCase()}</div>
                <ChevronDown size={14} className={`chevron ${dropdownOpen ? 'open' : ''}`} />
              </button>
              {dropdownOpen && (
                <>
                  <div className="dropdown-backdrop" onClick={() => setDropdownOpen(false)} />
                  <div className="dropdown-menu">
                    <div className="dropdown-header">
                      <p className="dropdown-email">{user.email}</p>
                      <span className="badge badge-green">{user.role}</span>
                    </div>
                    <div className="divider" style={{ margin: '8px 0' }} />
                    <Link to="/profile" className="dropdown-item" onClick={() => setDropdownOpen(false)}>
                      <User size={15} /> My Profile
                    </Link>
                    <Link to="/orders" className="dropdown-item" onClick={() => setDropdownOpen(false)}>
                      <Package size={15} /> My Orders
                    </Link>
                    {user.role === 'admin' && (
                      <Link
                        to="/admin"
                        className="dropdown-item"
                        onClick={() => setDropdownOpen(false)}
                        style={{ color: 'var(--brand)', fontWeight: 600 }}
                      >
                        <Shield size={15} /> Admin Portal
                      </Link>
                    )}
                    <div className="divider" style={{ margin: '8px 0' }} />
                    <button className="dropdown-item danger" onClick={handleLogout}>
                      <LogOut size={15} /> Sign Out
                    </button>
                  </div>
                </>
              )}
            </div>
          ) : (
            <div className="navbar-auth">
              <Link to="/login" className="btn btn-ghost btn-sm">Sign In</Link>
              <Link to="/register" className="btn btn-primary btn-sm">Sign Up</Link>
            </div>
          )}

          {/* Mobile toggle */}
          <button
            className="navbar-icon-btn mobile-menu-btn"
            onClick={() => setMobileOpen(!mobileOpen)}
            aria-label="Toggle menu"
          >
            {mobileOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <div className="mobile-menu">
          <NavLink to="/" className="mobile-nav-link" onClick={() => setMobileOpen(false)} end>Home</NavLink>
          <NavLink to="/products" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>Shop</NavLink>
          <NavLink to="/cart" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>Cart ({count})</NavLink>
          {user ? (
            <>
              <NavLink to="/orders" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>My Orders</NavLink>
              <NavLink to="/profile" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>Profile</NavLink>
              <button className="mobile-nav-link danger" onClick={handleLogout}>Sign Out</button>
            </>
          ) : (
            <>
              <NavLink to="/login" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>Sign In</NavLink>
              <NavLink to="/register" className="mobile-nav-link" onClick={() => setMobileOpen(false)}>Sign Up</NavLink>
            </>
          )}
        </div>
      )}
    </nav>
  );
}
