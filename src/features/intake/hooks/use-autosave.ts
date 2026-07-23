'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

export type AutosaveStatus = 'idle' | 'saving' | 'saved' | 'error';

/**
 * Debounced autosave. Returns a `schedule` callback that (re)starts the debounce
 * timer, and the current save status. The latest value is always captured, so
 * rapid edits collapse into a single save.
 */
export function useAutosave<T>(
  save: (value: T) => Promise<{ ok: boolean }>,
  delayMs = 1200,
) {
  const [status, setStatus] = useState<AutosaveStatus>('idle');
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pending = useRef<T | null>(null);

  const flush = useCallback(async () => {
    if (pending.current === null) return;
    const value = pending.current;
    pending.current = null;
    setStatus('saving');
    try {
      const result = await save(value);
      setStatus(result.ok ? 'saved' : 'error');
    } catch {
      setStatus('error');
    }
  }, [save]);

  const schedule = useCallback(
    (value: T) => {
      pending.current = value;
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(flush, delayMs);
    },
    [flush, delayMs],
  );

  // Flush any pending save on unmount.
  useEffect(() => {
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  return { schedule, status };
}
