'use client';

import { useEffect } from 'react';

import { logger } from '@/lib/logger';

/**
 * Global error boundary. Catches errors thrown in the root layout itself.
 * Must render its own <html> and <body> because it replaces the entire tree.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    logger.error('Unhandled root error', error, { digest: error.digest });
  }, [error]);

  return (
    <html lang="en">
      <body>
        <main
          style={{
            display: 'flex',
            minHeight: '100dvh',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '1rem',
            padding: '1rem',
            textAlign: 'center',
            fontFamily: 'system-ui, sans-serif',
          }}
        >
          <h1 style={{ fontSize: '1.5rem', fontWeight: 600 }}>
            Something went wrong
          </h1>
          <p>A critical error occurred. Please reload the page.</p>
          <button
            onClick={reset}
            style={{
              padding: '0.5rem 1rem',
              borderRadius: '0.5rem',
              border: '1px solid currentColor',
              cursor: 'pointer',
            }}
          >
            Try again
          </button>
        </main>
      </body>
    </html>
  );
}
