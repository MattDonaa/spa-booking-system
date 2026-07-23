import 'server-only';

import { createClient } from '@/lib/supabase/server';

export interface CurrentUser {
  id: string;
  email: string | undefined;
}

/**
 * Returns the currently authenticated user (server-side), or null. Reads the
 * verified user from Supabase Auth — never trust client-supplied identity.
 */
export async function getCurrentUser(): Promise<CurrentUser | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;
  return { id: user.id, email: user.email };
}
