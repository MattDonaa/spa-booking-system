-- ============================================================================
-- Migration: Shared Functions & Trigger Functions
-- ----------------------------------------------------------------------------
-- Reusable trigger functions applied across the schema:
--   * set_updated_at        — keeps updated_at accurate on every UPDATE.
--   * prevent_hard_delete   — blocks DELETE on business tables (soft delete only).
--   * record_audit          — writes before/after snapshots to audit_logs.
--   * record_booking_event  — appends to booking_events on create/status change.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- set_updated_at: bump updated_at to now() on every row update.
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger function: sets updated_at to the current time on UPDATE.';

-- ----------------------------------------------------------------------------
-- prevent_hard_delete: enforce "never delete business data".
-- Business tables must be soft-deleted (set deleted_at) instead of removed.
-- ----------------------------------------------------------------------------
create or replace function public.prevent_hard_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception
    'Hard deletes are not permitted on % (set deleted_at instead).',
    tg_table_name
    using errcode = 'restrict_violation';
  return null;
end;
$$;

comment on function public.prevent_hard_delete() is
  'Trigger function: raises an exception to block hard DELETEs on business tables.';

-- ----------------------------------------------------------------------------
-- record_audit: append a row to audit_logs describing the change.
-- Attached AFTER INSERT/UPDATE/DELETE on audited tables. Distinguishes plain
-- updates from soft deletes and restores by inspecting deleted_at transitions.
-- ----------------------------------------------------------------------------
create or replace function public.record_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action public.audit_action;
  v_entity_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  if (tg_op = 'INSERT') then
    v_action := 'insert';
    v_before := null;
    v_after := to_jsonb(new);
    v_entity_id := new.id;
  elsif (tg_op = 'UPDATE') then
    if (old.deleted_at is null and new.deleted_at is not null) then
      v_action := 'soft_delete';
    elsif (old.deleted_at is not null and new.deleted_at is null) then
      v_action := 'restore';
    else
      v_action := 'update';
    end if;
    v_before := to_jsonb(old);
    v_after := to_jsonb(new);
    v_entity_id := new.id;
  else -- DELETE
    v_action := 'delete';
    v_before := to_jsonb(old);
    v_after := null;
    v_entity_id := old.id;
  end if;

  insert into public.audit_logs (
    actor_profile_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  )
  values (
    nullif(current_setting('request.jwt.claim.sub', true), '')::uuid,
    v_action,
    tg_table_name,
    v_entity_id,
    v_before,
    v_after
  );

  return coalesce(new, old);
end;
$$;

comment on function public.record_audit() is
  'Trigger function: records an audit_logs entry (with before/after JSON) for a mutation.';

-- ----------------------------------------------------------------------------
-- record_booking_event: append to booking_events on booking creation and on
-- every status change. Enforces "every booking state change creates an event".
-- ----------------------------------------------------------------------------
create or replace function public.record_booking_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
begin
  if (tg_op = 'INSERT') then
    insert into public.booking_events (
      booking_id, event_type, from_status, to_status, actor_profile_id
    )
    values (new.id, 'created', null, new.status, v_actor);
  elsif (tg_op = 'UPDATE' and new.status is distinct from old.status) then
    insert into public.booking_events (
      booking_id, event_type, from_status, to_status, actor_profile_id
    )
    values (new.id, 'status_changed', old.status, new.status, v_actor);
  end if;

  return new;
end;
$$;

comment on function public.record_booking_event() is
  'Trigger function: appends a booking_events row on booking creation and status change.';
