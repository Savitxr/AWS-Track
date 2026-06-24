import { useState, useEffect } from 'react';
import { Plus, ToggleLeft, ToggleRight } from 'lucide-react';
import { adminAPI } from '../../api/client';
import toast from 'react-hot-toast';

const TYPES = [
  { key: 'category', label: 'Categories' },
  { key: 'franchise', label: 'Franchises' },
];

export default function AdminCategories() {
  const [tab,     setTab]     = useState('category');
  const [items,   setItems]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [form,    setForm]    = useState({ metaId: '', displayName: '', description: '', franchiseType: 'sports', sortOrder: 0 });
  const [saving,  setSaving]  = useState(false);

  const load = async (type) => {
    setLoading(true);
    try {
      const { data } = await adminAPI.getMetadata(type);
      setItems(data.items || []);
    } catch { toast.error('Failed to load'); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(tab); }, [tab]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await adminAPI.upsertMetadata(tab, form);
      toast.success('Saved');
      setForm({ metaId: '', displayName: '', description: '', franchiseType: 'sports', sortOrder: 0 });
      load(tab);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Save failed');
    } finally { setSaving(false); }
  };

  const toggleActive = async (item) => {
    try {
      if (item.isActive) {
        await adminAPI.deleteMetadata(tab, item.metaId);
      } else {
        await adminAPI.upsertMetadata(tab, { ...item, isActive: true });
      }
      load(tab);
    } catch { toast.error('Failed to update'); }
  };

  return (
    <div className="admin-page">
      <div className="admin-page-header">
        <div>
          <h1>Categories &amp; Franchises</h1>
          <p>Manage metadata used across the product catalog</p>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {TYPES.map(t => (
          <button
            key={t.key}
            className={`btn btn-sm ${tab === t.key ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => setTab(t.key)}
          >{t.label}</button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 20 }}>
        <div className="admin-card">
          <h3 style={{ marginBottom: 14, fontSize: '1rem' }}>
            Existing {TYPES.find(t => t.key === tab)?.label}
          </h3>
          {loading ? (
            <div className="loading-screen" style={{ minHeight: 120 }}><div className="spinner" /></div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>ID</th><th>Display Name</th>
                    {tab === 'franchise' && <th>Type</th>}
                    <th>Sort</th><th>Status</th><th>Toggle</th>
                  </tr>
                </thead>
                <tbody>
                  {items.length === 0 ? (
                    <tr>
                      <td colSpan={tab === 'franchise' ? 6 : 5} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: 24 }}>
                        No entries yet. Add one using the form →
                      </td>
                    </tr>
                  ) : items.map(item => (
                    <tr key={item.metaId}>
                      <td><code style={{ fontSize: 12 }}>{item.metaId}</code></td>
                      <td style={{ fontWeight: 600 }}>{item.displayName}</td>
                      {tab === 'franchise' && <td>{item.franchiseType || '—'}</td>}
                      <td>{item.sortOrder ?? 0}</td>
                      <td>
                        <span className={`status-badge ${item.isActive ? 'status-active' : 'status-inactive'}`}>
                          {item.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td>
                        <button
                          className="btn btn-ghost btn-sm"
                          onClick={() => toggleActive(item)}
                          title={item.isActive ? 'Deactivate' : 'Activate'}
                        >
                          {item.isActive
                            ? <ToggleRight size={18} style={{ color: 'var(--brand)' }} />
                            : <ToggleLeft size={18} />}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="admin-card">
          <h3 style={{ marginBottom: 14, fontSize: '1rem' }}>
            <Plus size={15} style={{ marginRight: 6, verticalAlign: 'middle' }} />
            Add / Update Entry
          </h3>
          <form onSubmit={handleSubmit}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div className="admin-form-group">
                <label>ID (slug) *</label>
                <input
                  required
                  value={form.metaId}
                  onChange={e => setForm(f => ({ ...f, metaId: e.target.value.toLowerCase().replace(/\s+/g, '-') }))}
                  placeholder="e.g. mumbai-indians"
                />
                <span className="admin-form-hint">Lowercase slug, used as DB key</span>
              </div>
              <div className="admin-form-group">
                <label>Display Name *</label>
                <input
                  required
                  value={form.displayName}
                  onChange={e => setForm(f => ({ ...f, displayName: e.target.value }))}
                  placeholder="e.g. Mumbai Indians"
                />
              </div>
              <div className="admin-form-group">
                <label>Description</label>
                <input
                  value={form.description}
                  onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                  placeholder="Optional short description"
                />
              </div>
              {tab === 'franchise' && (
                <div className="admin-form-group">
                  <label>Franchise Type</label>
                  <select
                    value={form.franchiseType}
                    onChange={e => setForm(f => ({ ...f, franchiseType: e.target.value }))}
                  >
                    <option value="sports">Sports</option>
                    <option value="movie">Movie</option>
                    <option value="show">Show</option>
                  </select>
                </div>
              )}
              <div className="admin-form-group">
                <label>Sort Order</label>
                <input
                  type="number"
                  value={form.sortOrder}
                  onChange={e => setForm(f => ({ ...f, sortOrder: Number(e.target.value) }))}
                />
              </div>
              <button type="submit" className="btn btn-primary btn-sm" disabled={saving}>
                {saving ? 'Saving...' : 'Save Entry'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
