import { cookies } from 'next/headers';

import { createServerClient, type CookieOptions } from '@supabase/ssr';

import { env } from '@/lib/env';
import type { Database } from '@/lib/supabase/types';

/**
 * Supabase client for use in Server Components, Server Actions, and Route
 * Handlers. Reads and writes the auth session via Next.js cookies.
 *
 * Uses the public anon key and therefore respects Row Level Security — this
 * is the correct client for all user-scoped data access.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(
          cookiesToSet: {
            name: string;
            value: string;
            options: CookieOptions;
          }[],
        ) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            // `setAll` was called from a Server Component. This can be safely
            // ignored when middleware is refreshing the session, which is the
            // configuration used by this app.
          }
        },
      },
    },
  );
}
