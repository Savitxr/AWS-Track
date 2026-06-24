import { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Plus, Pencil, Trash2, Search } from 'lucide-react';
import { adminAPI } from '../../api/client';
import toast from 'react-hot-toast';

const CATEGORIES = ['clothing', 'accessories', 'shoes', 'ornaments'];

export default function AdminProducts() {
  const navigate = useNavigate();
  const [products, setProducts] = useState([]);
  const [search,   setSearch]   = useState('');
  const [category, setCategory] = useState('');
  const [loading,  setLoading]  = useState(true);
  const [deleting, setDeleting] = useState(null);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await adminAPI.getProducts({ category: category || undefined, search: search || undefined, limit: 100 });
      setProducts(data.products || []);
    } catch { toast.error('Failed to load products'); }
    finally { setLoading(false); }
  }, [category, search]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const handleDelete = async (id, name) => {
    if (!window.confirm(`Deactivate "${name}"?`)) return;
    setDeleting(id);
    try {
      await adminAPI.deleteProduct(id);
      toast.success('Product deactivated');
      fetchProducts();
    } catch { toast.error('Failed to delete product'); }
    finally { setDeleting(null); }
  };

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div><h1>Products</h1><p>{products.length} products in catalog</p></div>
        <Link to="/admin/products/new" className="btn btn-primary btn-sm">
          <Plus size={15} /> New Product
        </Link>
      </div>

      <div className="admin-card">
        <div className="admin-search-bar">
          <div style={{ position: 'relative', flex: 1 }}>
            <Search size={14} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--gray-400)' }} />
            <input
              placeholder="Search products..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ paddingLeft: 32, width: '100%' }}
            />
          </div>
          <select value={category} onChange={e => setCategory(e.target.value)}>
            <option value="">All Categories</option>
            {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        {loading ? <div className="loading-screen" style={{ minHeight: 200 }}><div className="spinner" /></div> : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Image</th><th>Name</th><th>SKU</th><th>Category</th>
                  <th>Franchise</th><th>Stock</th><th>Price</th><th>Status</th><th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {products.length === 0 ? (
                  <tr><td colSpan={9} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>No products found</td></tr>
                ) : products.map(p => (
                  <tr key={p.productId}>
                    <td>
                      {p.images?.[0]
                        ? <img src={p.images[0]} alt={p.name} style={{ width: 42, height: 42, objectFit: 'cover', borderRadius: 6, border: '1px solid var(--border)' }} />
                        : <div style={{ width: 42, height: 42, background: 'var(--gray-100)', borderRadius: 6 }} />
                      }
                    </td>
                    <td style={{ fontWeight: 600, maxWidth: 180 }}>{p.name}</td>
                    <td><code style={{ fontSize: 12 }}>{p.sku}</code></td>
                    <td>{p.category}</td>
                    <td>{p.franchise}</td>
                    <td>
                      <span className={`${p.stock === 0 ? 'stock-zero' : p.stock <= 5 ? 'stock-low' : 'stock-ok'}`}>
                        {p.stock}
                      </span>
                    </td>
                    <td>₹{p.price?.toLocaleString('en-IN')}</td>
                    <td>
                      <span className={`status-badge ${p.isActive ? 'status-active' : 'status-inactive'}`}>
                        {p.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <div className="admin-actions-row">
                        <button className="btn btn-ghost btn-sm" onClick={() => navigate(`/admin/products/${p.productId}/edit`)}>
                          <Pencil size={13} />
                        </button>
                        <button
                          className="btn btn-sm"
                          style={{ color: '#dc2626', background: 'transparent' }}
                          onClick={() => handleDelete(p.productId, p.name)}
                          disabled={deleting === p.productId}
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
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
