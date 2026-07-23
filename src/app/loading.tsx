import { Loader2 } from 'lucide-react';

/**
 * Root-level loading UI shown during navigation and streaming.
 */
export default function Loading() {
  return (
    <div
      className="flex min-h-dvh items-center justify-center"
      role="status"
      aria-label="Loading"
    >
      <Loader2 className="size-8 animate-spin text-primary" aria-hidden />
      <span className="sr-only">Loading…</span>
    </div>
  );
}
