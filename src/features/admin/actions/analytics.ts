'use server';

import { createClient } from '@/lib/supabase/server';
import { unwrapRpc } from '@/lib/rpc';
import type { Result } from '@/lib/result';
import type {
  AnalyticsOverview,
  ClientAnalytics,
  PractitionerStat,
  ServiceStat,
} from '@/features/admin/analytics-types';

export async function analyticsOverview(
  from?: string,
  to?: string,
): Promise<Result<AnalyticsOverview>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('analytics_overview', {
    p_from: from ?? null,
    p_to: to ?? null,
  } as never);
  return unwrapRpc<AnalyticsOverview>(data, error);
}

export async function analyticsServices(
  from?: string,
  to?: string,
): Promise<Result<ServiceStat[]>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('analytics_services', {
    p_from: from ?? null,
    p_to: to ?? null,
  } as never);
  return unwrapRpc<ServiceStat[]>(data, error);
}

export async function analyticsPractitioners(
  from?: string,
  to?: string,
): Promise<Result<PractitionerStat[]>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('analytics_practitioners', {
    p_from: from ?? null,
    p_to: to ?? null,
  } as never);
  return unwrapRpc<PractitionerStat[]>(data, error);
}

export async function analyticsClients(): Promise<Result<ClientAnalytics>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('analytics_clients', {
    p_limit: 10,
  } as never);
  return unwrapRpc<ClientAnalytics>(data, error);
}
