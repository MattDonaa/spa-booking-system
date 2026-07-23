-- ============================================================================
-- Seed data
-- ----------------------------------------------------------------------------
-- Minimal, non-sample seed required for the application to function: the
-- singleton business settings row. Applied after all migrations on
-- `supabase db reset`. Intentionally contains no demo bookings, clients, or
-- practitioners.
-- ============================================================================

insert into public.business_settings (singleton)
values (true)
on conflict (singleton) do nothing;
