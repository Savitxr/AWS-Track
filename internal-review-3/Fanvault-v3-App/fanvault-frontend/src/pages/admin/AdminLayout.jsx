import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Package, ArchiveX, Layers, ShoppingBag,
  ClipboardList, LogOut, Zap, ChevronRight
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import toast from 'react-hot-toast';
import './AdminLayout.css';

const NAV = [
  { to: '/admin',              label: 'Dashboard',   icon: LayoutDashboard, end: true },
  { to: '/admin/products',     label: 'Products',    icon: Package },
  { to: '/admin/inventory',    label: 'Inventory',   icon: ArchiveX },
  { to: '/admin/categories',   label: 'Categories',  icon: Layers },
  { to: '/admin/orders',       label: 'Orders',      icon: ShoppingBag },
  { to: '/admin/audit',        label: 'Audit Log',   icon: ClipboardList },
];

export default function AdminLayout() {
  const { logout, user } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    toast.success('Logged out');
    navigate('/');
  };

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="admin-sidebar-header">
          <Zap size={20} className="admin-logo-icon" />
          <span>FanVault Admin</span>
        </div>

        <div className="admin-user-pill">
          <div className="admin-avatar">{user?.email?.charAt(0).toUpperCase()}</div>
          <div>
            <p className="admin-user-email">{user?.email}</p>
            <span className="admin-role-badge">Admin</span>
          </div>
        </div>

        <nav className="admin-nav">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) => `admin-nav-link ${isActive ? 'active' : ''}`}
            >
              <Icon size={17} />
              <span>{label}</span>
              <ChevronRight size={14} className="admin-nav-arrow" />
            </NavLink>
          ))}
        </nav>

        <div className="admin-sidebar-footer">
          <a href="/" className="admin-nav-link">
            <LogOut size={17} />
            <span>Back to Store</span>
          </a>
          <button className="admin-nav-link danger" onClick={handleLogout}>
            <LogOut size={17} />
            <span>Sign Out</span>
          </button>
        </div>
      </aside>

      <main className="admin-content">
        <Outlet />
      </main>
    </div>
  );
}
