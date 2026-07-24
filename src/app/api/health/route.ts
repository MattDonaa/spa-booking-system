import { NextResponse } from 'next/server';

import { createClient } from '@/lib/supabase/server';
import { logger } from '@/lib/logger';

/**
 * Health check endpoint for load balancers, container HEALTHCHECK, and uptime
 * monitors. Returns 200 when the app is up and the database is reachable, 503
 * otherwise. Never exposes secrets or internal detail.
 */
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function GET() {
  const startedAt = Date.now();

  try {
    const supabase = await createClient();
    // A cheap, RLS-safe round-trip that confirms the database is reachable.
    const { error } = await supabase.rpc('is_valid_booking_transition', {
      p_from: 'confirmed',
      p_to: 'completed',
    } as never);

    if (error) {
      logger.error('Health check: database unreachable', error);
      return NextResponse.json(
        { status: 'degraded', database: 'error' },
        { status: 503 },
      );
    }

    return NextResponse.json({
      status: 'ok',
      database: 'ok',
      uptimeCheckMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Health check failed', error);
    return NextResponse.json({ status: 'error' }, { status: 503 });
  }
}
