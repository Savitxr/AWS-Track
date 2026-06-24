import { useState, useEffect, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Search, Filter, X, ChevronDown } from 'lucide-react';
import { productAPI } from '../api/client';
import ProductCard from '../components/ProductCard';
import './ProductsPage.css';

const CATEGORIES = ['clothing', 'accessories', 'shoes', 'ornaments'];
const FRANCHISE_TYPES = ['sports', 'movie', 'show'];
const SORT_OPTIONS = [
  { value: 'createdAt-desc', label: 'Newest First' },
  { value: 'price-asc', label: 'Price: Low → High' },
  { value: 'price-desc', label: 'Price: High → Low' },
  { value: 'rating.average-desc', label: 'Top Rated' },
];

export default function ProductsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [products, setProducts] = useState([]);
  const [pagination, setPagination] = useState({ total: 0, pages: 1, page: 1 });
  const [loading, setLoading] = useState(true);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const category = searchParams.get('category') || '';
  const franchiseType = searchParams.get('franchiseType') || '';
  const franchise = searchParams.get('franchise') || '';
  const search = searchParams.get('search') || '';
  const sort = searchParams.get('sort') || 'createdAt-desc';
  const page = Number(searchParams.get('page')) || 1;

  const [searchInput, setSearchInput] = useState(search);

  const [sortBy, order] = sort.split('-');

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await productAPI.getProducts({
        category: category || undefined,
        franchiseType: franchiseType || undefined,
        franchise: franchise || undefined,
        search: search || undefined,
        sortBy,
        order,
        page,
        limit: 12,
      });
      setProducts(Array.isArray(data?.products) ? data.products : []);
      setPagination(data?.pagination || { total: 0, pages: 1, page: 1 });
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [category, franchiseType, franchise, search, sortBy, order, page]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const updateParam = (key, value) => {
    const params = new URLSearchParams(searchParams);
    if (value) params.set(key, value);
    else params.delete(key);
    params.delete('page');
    setSearchParams(params);
  };

  const clearFilters = () => {
    setSearchParams({});
    setSearchInput('');
  };

  const handleSearch = (e) => {
    e.preventDefault();
    updateParam('search', searchInput);
  };

  const hasFilters = category || franchiseType || franchise || search;

  return (
    <div className="products-page page">
      <div className="container">
        {/* Header */}
        <div className="products-header">
          <div>
            <h1>Shop All Products</h1>
            <p>{loading ? 'Loading...' : `${pagination.total} products found`}</p>
          </div>
          <div className="products-toolbar">
            <button className="btn btn-ghost btn-sm filter-toggle" onClick={() => setSidebarOpen(!sidebarOpen)}>
              <Filter size={15} /> Filters {hasFilters && <span className="filter-dot" />}
            </button>
            <select
              className="form-input form-select sort-select"
              value={sort}
              onChange={(e) => updateParam('sort', e.target.value)}
            >
              {SORT_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
        </div>

        {/* Search bar */}
        <form className="search-bar" onSubmit={handleSearch}>
          <Search size={17} className="search-icon" />
          <input
            className="form-input search-input"
            placeholder="Search products, franchises..."
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
          />
          {searchInput && (
            <button type="button" className="search-clear" onClick={() => { setSearchInput(''); updateParam('search', ''); }}>
              <X size={15} />
            </button>
          )}
          <button type="submit" className="btn btn-primary btn-sm">Search</button>
        </form>

        <div className="products-layout">
          {/* Sidebar filters */}
          <aside className={`filters-sidebar ${sidebarOpen ? 'open' : ''}`}>
            <div className="sidebar-header">
              <h3>Filters</h3>
              {hasFilters && <button className="btn btn-ghost btn-sm" onClick={clearFilters}><X size={14} /> Clear all</button>}
            </div>

            {/* Category */}
            <div className="filter-section">
              <h4>Category <ChevronDown size={14} /></h4>
              <div className="filter-options">
                {CATEGORIES.map((c) => (
                  <label key={c} className="filter-option">
                    <input type="radio" name="category" checked={category === c} onChange={() => updateParam('category', category === c ? '' : c)} />
                    <span>{c.charAt(0).toUpperCase() + c.slice(1)}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Type */}
            <div className="filter-section">
              <h4>Type</h4>
              <div className="filter-options">
                {FRANCHISE_TYPES.map((t) => (
                  <label key={t} className="filter-option">
                    <input type="radio" name="type" checked={franchiseType === t} onChange={() => updateParam('franchiseType', franchiseType === t ? '' : t)} />
                    <span>{t.charAt(0).toUpperCase() + t.slice(1)}</span>
                  </label>
                ))}
              </div>
            </div>
          </aside>

          {/* Products grid */}
          <div className="products-main">
            {/* Active filters */}
            {hasFilters && (
              <div className="active-filters">
                {category && <span className="filter-tag">{category} <button onClick={() => updateParam('category', '')}><X size={11} /></button></span>}
                {franchiseType && <span className="filter-tag">{franchiseType} <button onClick={() => updateParam('franchiseType', '')}><X size={11} /></button></span>}
                {franchise && <span className="filter-tag">{franchise} <button onClick={() => updateParam('franchise', '')}><X size={11} /></button></span>}
                {search && <span className="filter-tag">"{search}" <button onClick={() => { setSearchInput(''); updateParam('search', ''); }}><X size={11} /></button></span>}
              </div>
            )}

            {loading ? (
              <div className="loading-screen"><div className="spinner" /><span>Loading products...</span></div>
            ) : products.length === 0 ? (
              <div className="empty-state">
                <Search size={48} />
                <h3>No products found</h3>
                <p>Try adjusting your filters or search terms</p>
                <button className="btn btn-primary" onClick={clearFilters}>Clear Filters</button>
              </div>
            ) : (
              <>
                <div className="product-grid">
                  {products.map((p) => <ProductCard key={p.productId} product={p} />)}
                </div>

                {/* Pagination */}
                {pagination.pages > 1 && (
                  <div className="pagination">
                    <button
                      className="btn btn-ghost btn-sm"
                      disabled={page <= 1}
                      onClick={() => updateParam('page', String(page - 1))}
                    >
                      ← Prev
                    </button>
                    {Array.from({ length: pagination.pages }, (_, i) => i + 1).map((p) => (
                      <button
                        key={p}
                        className={`btn btn-sm ${page === p ? 'btn-primary' : 'btn-ghost'}`}
                        onClick={() => updateParam('page', String(p))}
                      >
                        {p}
                      </button>
                    ))}
                    <button
                      className="btn btn-ghost btn-sm"
                      disabled={page >= pagination.pages}
                      onClick={() => updateParam('page', String(page + 1))}
                    >
                      Next →
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
