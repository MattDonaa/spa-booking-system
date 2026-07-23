-- ============================================================================
-- Migration: Audit Logs
-- ----------------------------------------------------------------------------
-- Central append-only audit trail. Populated by the record_audit() trigger
-- (defined earlier and attached to mutable business tables). This table is
-- created here, before any seeded inserts fire their audit triggers.
--
-- Note: audit rows reference the actor as a plain uuid (not a foreign key) so
-- that history is preserved even if the acting profile is later removed.
-- ============================================================================

create table public.audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_profile_id uuid,
  action public.audit_action not null,
  entity_type text not null,
  entity_id uuid not null,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id, created_at desc);
create index audit_logs_actor_idx
  on public.audit_logs (actor_profile_id, created_at desc);
create index audit_logs_action_idx
  on public.audit_logs (action, created_at desc);

comment on table public.audit_logs is
  'Append-only audit trail of mutations, with before/after snapshots.';

-- Audit records are immutable and must never be removed.
create trigger prevent_hard_delete before delete on public.audit_logs
  for each row execute function public.prevent_hard_delete();
