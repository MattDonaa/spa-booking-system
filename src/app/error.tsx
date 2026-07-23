'use client';

import { useEffect } from 'react';

import { Button } from '@/components/ui/button';
import { logger } from '@/lib/logger';

/**
 * Route-segment error boundary. Catches rendering errors and offers recovery
 * without a full reload.
 */
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    logger.error('Unhandled UI error', error, { digest: error.digest });
  }, [error]);

  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-4 px-4 text-center">
      <h1 className="text-2xl font-semibold">Something went wrong</h1>
      <p className="max-w-md text-muted-foreground">
        An unexpected error occurred. You can try again, and if the problem
        persists please contact support.
      </p>
      <Button onClick={reset}>Try again</Button>
    </main>
  );
}
