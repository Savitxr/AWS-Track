import { useState, useEffect } from 'react';
import { Save } from 'lucide-react';
import { adminAPI } from '../../api/client';
import toast from 'react-hot-toast';

export default function AdminInventory() {
  const [items,   setItems]   = useState([]);
  const [edits,   setEdits]   = useState({});
  const [saving,  setSaving]  = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    adminAPI.getInventory({ limit: 200 })
      .then(({ data }) => setItems(data.inventory || []))
      .catch(() => toast.error('Failed to load inventory'))
      .finally(() => setLoading(false));
  }, []);

  const handleEdit = (id, val) =>
    setEdits(e => ({ ...e, [id]: val }));

  const handleSave = async (id) => {
    const stock = Number(edits[id]);
    if (isNaN(stock) || stock < 0) return toast.error('Invalid stock value');
    setSaving(s => ({ ...s, [id]: true }));
    try {
      await adminAPI.updateStock(id, { stock });
      setItems(prev => prev.map(p => p.productId === id ? { ...p, stock } : p));
      setEdits(e => { const n = { ...e }; delete n[id]; return n; });
      toast.success('Stock updated');
    } catch {
      toast.error('Failed to update stock');
    } finally {
      setSaving(s => ({ ...s, [id]: false }));
    }
  };

  const outOfStock = items.filter(p => p.stock === 0).length;
  const lowStock   = items.filter(p => p.stock > 0 && p.stock <= 5).length;

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div>
          <h1>Inventory</h1>
          <p>
            {outOfStock > 0 && <span style={{ color: '#dc2626', marginRight: 12 }}>⚠ {outOfStock} out of stock</span>}
            {lowStock   > 0 && <span style={{ color: '#d97706'              }}>⚠ {lowStock} low stock</span>}
          </p>
        </div>
      </div>

      <div className="admin-card">
        {loading ? <div className="loading-screen" style={{ minHeight: 200 }}><div className="spinner" /></div> : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr><th>Product</th><th>SKU</th><th>Category</th><th>Franchise</th><th>Current Stock</th><th>Update</th></tr>
              </thead>
              <tbody>
                {items.length === 0 ? (
                  <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>No inventory data</td></tr>
                ) : items.map(p => {
                  const currentVal = edits[p.productId] !== undefined ? edits[p.productId] : p.stock;
                  const isDirty = edits[p.productId] !== undefined && Number(edits[p.productId]) !== p.stock;
                  return (
                    <tr key={p.productId}>
                      <td style={{ fontWeight: 600 }}>{p.name}</td>
                      <td><code style={{ fontSize: 12 }}>{p.sku}</code></td>
                      <td>{p.category}</td>
                      <td>{p.franchise}</td>
                      <td>
                        <span className={p.stock === 0 ? 'stock-zero' : p.stock <= 5 ? 'stock-low' : 'stock-ok'}>
                          {p.stock}
                        </span>
                      </td>
                      <td>
                        <div className="stock-input-wrap">
                          <input
                            type="number"
                            min="0"
                            value={currentVal}
                            onChange={e => handleEdit(p.productId, e.target.value)}
                          />
                          {isDirty && (
                            <button
                              className="btn btn-primary btn-sm"
                              onClick={() => handleSave(p.productId)}
                              disabled={saving[p.productId]}
                            >
                              {saving[p.productId] ? '...' : <Save size={12} />}
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
