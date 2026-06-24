import { Component } from 'react';

/**
 * ErrorBoundary – wraps the app so that a render-time JS crash
 * shows a friendly UI instead of a completely blank white page.
 *
 * Usage (already wired in App.jsx via <ErrorBoundary>):
 *   <ErrorBoundary>
 *     <YourComponent />
 *   </ErrorBoundary>
 */
export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    console.error('[ErrorBoundary] caught:', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 20,
          padding: 40,
          textAlign: 'center',
          fontFamily: 'Inter, sans-serif',
          background: '#f4fdf6',
        }}>
          <div style={{ fontSize: 64 }}>⚡</div>
          <h1 style={{ fontSize: '2rem', color: '#1b4332', margin: 0 }}>
            Something went wrong
          </h1>
          <p style={{ color: '#6b7280', maxWidth: 480, lineHeight: 1.6 }}>
            FanVault encountered an unexpected error. This is usually caused by a
            temporary network issue or a backend service that is not yet available.
          </p>
          <details style={{ fontSize: 12, color: '#9ca3af', maxWidth: 600, textAlign: 'left' }}>
            <summary style={{ cursor: 'pointer', marginBottom: 8 }}>Error details</summary>
            <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
              {this.state.error?.toString()}
            </pre>
          </details>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', justifyContent: 'center' }}>
            <button
              onClick={() => { this.setState({ hasError: false, error: null }); }}
              style={{
                padding: '10px 24px',
                background: '#2d6a4f',
                color: 'white',
                border: 'none',
                borderRadius: 8,
                fontWeight: 700,
                cursor: 'pointer',
                fontSize: 14,
              }}
            >
              Try Again
            </button>
            <button
              onClick={() => { window.location.href = '/'; }}
              style={{
                padding: '10px 24px',
                background: 'white',
                color: '#2d6a4f',
                border: '2px solid #2d6a4f',
                borderRadius: 8,
                fontWeight: 700,
                cursor: 'pointer',
                fontSize: 14,
              }}
            >
              Go Home
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
