import { createContext, useContext, useState, useEffect } from 'react';
import toast from 'react-hot-toast';

const CartContext = createContext(null);

export function CartProvider({ children }) {
  const [items, setItems] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('cart')) || [];
    } catch { return []; }
  });

  useEffect(() => {
    localStorage.setItem('cart', JSON.stringify(items));
  }, [items]);

  const addItem = (product, quantity = 1, size = null, color = null) => {
    setItems((prev) => {
      const key = `${product.productId}-${size}-${color}`;
      const existing = prev.find((i) => `${i.productId}-${i.size}-${i.color}` === key);
      if (existing) {
        toast.success('Quantity updated');
        return prev.map((i) =>
          `${i.productId}-${i.size}-${i.color}` === key
            ? { ...i, quantity: i.quantity + quantity }
            : i
        );
      }
      toast.success('Added to cart!');
      return [...prev, {
        productId: product.productId,
        name: product.name,
        price: product.price,
        image: product.images?.[0] || '',
        franchise: product.franchise,
        size,
        color,
        quantity,
      }];
    });
  };

  const removeItem = (productId, size, color) => {
    setItems((prev) =>
      prev.filter((i) => !(i.productId === productId && i.size === size && i.color === color))
    );
  };

  const updateQuantity = (productId, size, color, quantity) => {
    if (quantity < 1) return removeItem(productId, size, color);
    setItems((prev) =>
      prev.map((i) =>
        i.productId === productId && i.size === size && i.color === color
          ? { ...i, quantity }
          : i
      )
    );
  };

  const clearCart = () => setItems([]);

  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const count = items.reduce((sum, i) => sum + i.quantity, 0);

  return (
    <CartContext.Provider value={{ items, addItem, removeItem, updateQuantity, clearCart, total, count }}>
      {children}
    </CartContext.Provider>
  );
}

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
};
