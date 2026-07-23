import 'server-only';

import { createClient as createSupabaseClient } from '@supabase/supabase-js';

import { env } from '@/lib/env';
import { getServerEnv } from '@/lib/env';
import type { Database } from '@/lib/supabase/types';

/**
 * Privileged Supabase client using the service role key.
 *
 * This client BYPASSES Row Level Security. It must ONLY be used in trusted
 * server-side contexts (Edge Functions, webhooks, background jobs) for
 * operations that legitimately require elevated access.
 *
 * The `server-only` import guarantees a build error if this module is ever
 * imported into a client bundle.
 */
export function createAdminClient() {
  const serverEnv = getServerEnv();

  return createSupabaseClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    serverEnv.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}
