import { createBrowserClient } from '@supabase/ssr';

import { env } from '@/lib/env';
import type { Database } from '@/lib/supabase/types';

/**
 * Supabase client for use in Client Components (browser runtime).
 *
 * Uses the public anon key. All access is subject to Row Level Security.
 * Never use the service role key here.
 */
export function createClient() {
  return createBrowserClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
}
