// ============================================================================
// Supabase client factories for Edge Functions.
// ============================================================================
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

import { requireEnv } from './http.ts';

/**
 * Service-role client. Bypasses RLS and is the only client permitted to call
 * the webhook-applying RPCs (record_payment_event / record_refund_event).
 * NEVER expose the service role key outside the server.
 */
export function serviceClient(): SupabaseClient {
  return createClient(
    requireEnv('SUPABASE_URL'),
    requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

/**
 * User-scoped client that forwards the caller's JWT, so RLS and the RPC
 * authorization checks apply. Used by payments-initiate.
 */
export function userClient(authHeader: string | null): SupabaseClient {
  return createClient(
    requireEnv('SUPABASE_URL'),
    requireEnv('SUPABASE_ANON_KEY'),
    {
      global: { headers: authHeader ? { Authorization: authHeader } : {} },
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
}
