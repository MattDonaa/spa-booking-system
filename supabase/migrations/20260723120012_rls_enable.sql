-- ============================================================================
-- Migration: Enable Row Level Security (deny-by-default)
-- ----------------------------------------------------------------------------
-- RLS is enabled on every table now, as a secure default. With RLS enabled and
-- no policies defined, all access via the anon/authenticated roles is denied;
-- only the service role (server-side, trusted) can read or write. The concrete,
-- role-aware policies are added in Milestone 3 (Authentication & Security).
--
-- This guarantees that no sensitive data — especially medical intake and
-- consent records — is ever exposed before the security model is in place.
-- ============================================================================

do $$
declare
  t text;
  tables text[] := array[
    'profiles',
    'clients',
    'practitioners',
    'service_categories',
    'rooms',
    'services',
    'practitioner_services',
    'business_settings',
    'practitioner_availability',
    'availability_blocks',
    'bookings',
    'booking_events',
    'payments',
    'refunds',
    'payment_webhook_events',
    'form_templates',
    'intake_forms',
    'consent_records',
    'notification_queue',
    'notifications',
    'audit_logs'
  ];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security;', t);
    -- FORCE ensures the table owner is also subject to RLS, closing a common
    -- gap. The service role (used server-side) still bypasses RLS by design.
    execute format('alter table public.%I force row level security;', t);
  end loop;
end;
$$;
