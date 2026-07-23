'use server';

import { createClient } from '@/lib/supabase/server';
import { logger } from '@/lib/logger';
import { err, ok, type Result } from '@/lib/result';

/**
 * Foundation health check server action.
 *
 * Demonstrates the standard server-action pattern used throughout the app:
 * thin entry point, structured `Result` return, structured logging, and no
 * thrown errors across the boundary. Verifies the Supabase connection is
 * reachable. Replaced/expanded by real features in later milestones.
 */
export async function checkHealth(): Promise<
  Result<{ status: 'ok'; checkedAt: string }>
> {
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.getSession();

    if (error) {
      logger.error('Health check: Supabase session error', error);
      return err('INTERNAL', 'Backend connectivity check failed.');
    }

    return ok({ status: 'ok', checkedAt: new Date().toISOString() });
  } catch (error) {
    logger.error('Health check: unexpected failure', error);
    return err('INTERNAL', 'Health check failed unexpectedly.');
  }
}
