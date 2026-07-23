-- ============================================================================
-- Migration: Booking Engine — RPC Mutations
-- ----------------------------------------------------------------------------
-- Transactional booking operations, all inside PostgreSQL. These are the ONLY
-- sanctioned way to mutate bookings; the frontend never inserts directly.
--
-- Concurrency: each operation takes a transaction-scoped advisory lock keyed by
-- the practitioner (and room), serialising competing attempts for the same
-- resource, and re-checks availability under that lock. The GiST exclusion
-- constraints on `bookings` are the final backstop against overlaps.
--
-- These functions are SECURITY DEFINER (they must see all bookings to detect
-- conflicts) and therefore enforce authorization explicitly. They return a
-- structured JSON envelope: { ok, data } on success, { ok, error:{code,message} }
-- on failure — mirroring the app's Result<T> contract.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Internal: uniform JSON envelopes.
-- ----------------------------------------------------------------------------
create or replace function private.rpc_ok(p_data jsonb)
returns jsonb language sql immutable as $$
  select jsonb_build_object('ok', true, 'data', p_data);
$$;

create or replace function private.rpc_err(p_code text, p_message text)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'ok', false,
    'error', jsonb_build_object('code', p_code, 'message', p_message)
  );
$$;

-- ----------------------------------------------------------------------------
-- Internal: is the current caller a trusted server context (service role)?
-- ----------------------------------------------------------------------------
create or replace function private.is_service_role()
returns boolean language sql stable as $$
  select current_user = 'service_role' or auth.uid() is null;
$$;

-- ============================================================================
-- create_booking
-- Places a transactional hold (status = pending_hold) for a service with a
-- practitioner at a given start time. Optionally targets a specific room;
-- otherwise a free room is auto-assigned when the service requires one.
-- ============================================================================
create or replace function public.create_booking(
  p_service_id uuid,
  p_practitioner_id uuid,
  p_starts_at timestamptz,
  p_client_id uuid default null,
  p_room_id uuid default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_active public.booking_status[] := private.active_booking_statuses();
  v_now timestamptz := now();
  v_client_id uuid;
  v_lead integer;
  v_max_days integer;
  v_hold_minutes integer;
  v_deposit_pct numeric;
  v_duration integer;
  v_buf_before integer;
  v_buf_after integer;
  v_price integer;
  v_deposit integer;
  v_currency char(3);
  v_requires_room boolean;
  v_starts timestamptz;
  v_ends timestamptz;
  v_bstart timestamptz;
  v_bend timestamptz;
  v_room uuid;
  v_booking_id uuid;
begin
  -- Authentication.
  if v_uid is null and not private.is_service_role() then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  -- Resolve and authorize the client.
  v_client_id := coalesce(p_client_id, private.current_client_id());
  if v_client_id is null then
    return private.rpc_err('VALIDATION', 'A client is required to book.');
  end if;
  if v_uid is not null
     and not private.is_staff()
     and v_client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN',
      'You may only create bookings for your own account.');
  end if;

  if p_starts_at is null then
    return private.rpc_err('VALIDATION', 'A start time is required.');
  end if;

  -- Load settings.
  select bs.min_booking_lead_minutes, bs.max_booking_lead_days,
         bs.hold_duration_minutes, bs.default_deposit_percentage
    into v_lead, v_max_days, v_hold_minutes, v_deposit_pct
  from public.business_settings bs limit 1;

  v_lead := coalesce(v_lead, 120);
  v_max_days := coalesce(v_max_days, 90);
  v_hold_minutes := coalesce(v_hold_minutes, 15);
  v_deposit_pct := coalesce(v_deposit_pct, 20.00);

  -- Load service.
  select s.duration_minutes, s.buffer_before_minutes, s.buffer_after_minutes,
         s.price_cents, s.deposit_cents, s.currency, s.requires_room
    into v_duration, v_buf_before, v_buf_after,
         v_price, v_deposit, v_currency, v_requires_room
  from public.services s
  where s.id = p_service_id and s.is_active and s.deleted_at is null;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Service not found or inactive.');
  end if;

  -- Verify the practitioner offers this service and is active.
  if not exists (
    select 1
    from public.practitioner_services ps
    join public.practitioners pr on pr.id = ps.practitioner_id
    where ps.practitioner_id = p_practitioner_id
      and ps.service_id = p_service_id
      and ps.deleted_at is null
      and pr.is_active and pr.deleted_at is null
  ) then
    return private.rpc_err('VALIDATION',
      'This practitioner does not offer the selected service.');
  end if;

  v_starts := p_starts_at;
  v_ends := v_starts + make_interval(mins => v_duration);
  v_bstart := v_starts - make_interval(mins => v_buf_before);
  v_bend := v_ends + make_interval(mins => v_buf_after);

  -- Lead time and future-window rules.
  if v_starts < v_now + make_interval(mins => v_lead) then
    return private.rpc_err('VALIDATION',
      'The selected time is too soon to book.');
  end if;
  if v_starts > v_now + make_interval(days => v_max_days) then
    return private.rpc_err('VALIDATION',
      'The selected time is too far in the future.');
  end if;

  -- Serialise concurrent attempts for this practitioner (and room).
  perform pg_advisory_xact_lock(hashtextextended(p_practitioner_id::text, 0));
  if p_room_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_room_id::text, 1));
  end if;

  -- Working hours must cover the appointment.
  if not exists (
    select 1
    from public.practitioner_availability pa,
         public.business_settings bs
    where pa.practitioner_id = p_practitioner_id
      and pa.deleted_at is null
      and pa.day_of_week = extract(
        dow from (v_starts at time zone bs.timezone)
      )::smallint
      and (v_starts at time zone bs.timezone)::time >= pa.start_time
      and (v_ends at time zone bs.timezone)::time <= pa.end_time
      and (pa.effective_from is null
           or pa.effective_from <= (v_starts at time zone bs.timezone)::date)
      and (pa.effective_to is null
           or pa.effective_to >= (v_starts at time zone bs.timezone)::date)
  ) then
    return private.rpc_err('CONFLICT',
      'The practitioner is not available at this time.');
  end if;

  -- Not inside a blocking period.
  if exists (
    select 1 from public.availability_blocks abl
    where abl.deleted_at is null
      and (
        abl.practitioner_id = p_practitioner_id
        or (abl.practitioner_id is null and abl.room_id is null)
      )
      and tstzrange(abl.starts_at, abl.ends_at, '[)')
          && tstzrange(v_bstart, v_bend, '[)')
  ) then
    return private.rpc_err('CONFLICT',
      'The selected time is unavailable (blocked).');
  end if;

  -- No overlapping active booking for this practitioner.
  if exists (
    select 1 from public.bookings b
    where b.practitioner_id = p_practitioner_id
      and b.deleted_at is null
      and b.status = any (v_active)
      and tstzrange(b.buffer_starts_at, b.buffer_ends_at, '[)')
          && tstzrange(v_bstart, v_bend, '[)')
  ) then
    return private.rpc_err('CONFLICT',
      'This time slot is no longer available.');
  end if;

  -- Room assignment.
  if v_requires_room then
    if p_room_id is not null then
      -- Verify the requested room is free and not blocked.
      if exists (
        select 1 from public.bookings b
        where b.room_id = p_room_id and b.deleted_at is null
          and b.status = any (v_active)
          and tstzrange(b.buffer_starts_at, b.buffer_ends_at, '[)')
              && tstzrange(v_bstart, v_bend, '[)')
      ) or exists (
        select 1 from public.availability_blocks abl
        where abl.room_id = p_room_id and abl.deleted_at is null
          and tstzrange(abl.starts_at, abl.ends_at, '[)')
              && tstzrange(v_bstart, v_bend, '[)')
      ) then
        return private.rpc_err('CONFLICT',
          'The selected room is unavailable at this time.');
      end if;
      v_room := p_room_id;
    else
      -- Auto-assign the first free room, locking the row.
      select r.id into v_room
      from public.rooms r
      where r.is_active and r.deleted_at is null
        and not exists (
          select 1 from public.bookings b
          where b.room_id = r.id and b.deleted_at is null
            and b.status = any (v_active)
            and tstzrange(b.buffer_starts_at, b.buffer_ends_at, '[)')
                && tstzrange(v_bstart, v_bend, '[)')
        )
        and not exists (
          select 1 from public.availability_blocks abl
          where abl.room_id = r.id and abl.deleted_at is null
            and tstzrange(abl.starts_at, abl.ends_at, '[)')
                && tstzrange(v_bstart, v_bend, '[)')
        )
      order by r.created_at
      for update skip locked
      limit 1;

      if v_room is null then
        return private.rpc_err('CONFLICT',
          'No treatment room is available at this time.');
      end if;
    end if;
  else
    v_room := null;
  end if;

  -- Deposit: explicit service deposit, else percentage of price.
  if v_deposit is null or v_deposit = 0 then
    v_deposit := floor(v_price * v_deposit_pct / 100.0)::integer;
  end if;
  v_deposit := least(v_deposit, v_price);

  -- Insert the hold. The exclusion constraints are the final backstop.
  begin
    insert into public.bookings (
      client_id, practitioner_id, service_id, room_id, status,
      starts_at, ends_at, buffer_starts_at, buffer_ends_at,
      price_cents, deposit_cents, currency, hold_expires_at,
      notes, created_by
    )
    values (
      v_client_id, p_practitioner_id, p_service_id, v_room, 'pending_hold',
      v_starts, v_ends, v_bstart, v_bend,
      v_price, v_deposit, v_currency,
      v_now + make_interval(mins => v_hold_minutes),
      p_notes, v_uid
    )
    returning id into v_booking_id;
  exception
    when exclusion_violation then
      return private.rpc_err('CONFLICT',
        'This time slot was just taken. Please choose another.');
  end;

  return private.rpc_ok(jsonb_build_object(
    'booking_id', v_booking_id,
    'status', 'pending_hold',
    'starts_at', v_starts,
    'ends_at', v_ends,
    'room_id', v_room,
    'price_cents', v_price,
    'deposit_cents', v_deposit,
    'currency', v_currency,
    'hold_expires_at', v_now + make_interval(mins => v_hold_minutes)
  ));
end;
$$;

comment on function public.create_booking is
  'Transactional booking hold with advisory locking and availability checks.';

-- ============================================================================
-- transition_booking
-- Moves a booking to a new status, enforcing the state machine and clearing/
-- setting the relevant timestamps. booking_events are written by trigger.
-- ============================================================================
create or replace function public.transition_booking(
  p_booking_id uuid,
  p_to_status public.booking_status,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
begin
  if v_uid is null and not private.is_service_role() then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  -- Lock the booking row for the duration of the transaction.
  select * into v_booking
  from public.bookings
  where id = p_booking_id and deleted_at is null
  for update;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  -- Authorization: admin, the assigned practitioner, the owning client, or a
  -- trusted server context.
  if not private.is_service_role()
     and not private.is_admin()
     and v_booking.practitioner_id is distinct from private.current_practitioner_id()
     and v_booking.client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN',
      'You are not permitted to modify this booking.');
  end if;

  if v_booking.status = p_to_status then
    return private.rpc_err('VALIDATION', 'Booking is already in that status.');
  end if;

  if not public.is_valid_booking_transition(v_booking.status, p_to_status) then
    return private.rpc_err('CONFLICT', format(
      'Illegal transition from %s to %s.', v_booking.status, p_to_status));
  end if;

  update public.bookings
  set status = p_to_status,
      hold_expires_at = case
        when p_to_status in ('pending_hold', 'pending_payment')
          then hold_expires_at else null end,
      cancelled_at = case
        when p_to_status = 'cancelled' then now() else cancelled_at end,
      cancellation_reason = case
        when p_to_status = 'cancelled' then coalesce(p_reason, cancellation_reason)
        else cancellation_reason end,
      completed_at = case
        when p_to_status = 'completed' then now() else completed_at end
  where id = p_booking_id;

  return private.rpc_ok(jsonb_build_object(
    'booking_id', p_booking_id,
    'from_status', v_booking.status,
    'status', p_to_status
  ));
end;
$$;

comment on function public.transition_booking is
  'Applies a state-machine-validated status change to a booking.';

-- ============================================================================
-- cancel_booking
-- Convenience wrapper enforcing the cancellation-window rule for clients.
-- Staff and admins may cancel at any time.
-- ============================================================================
create or replace function public.cancel_booking(
  p_booking_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_window_hours integer;
begin
  if v_uid is null and not private.is_service_role() then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and deleted_at is null
  for update;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  if not private.is_service_role()
     and not private.is_staff()
     and v_booking.client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN',
      'You are not permitted to cancel this booking.');
  end if;

  -- Cancellation window applies to clients only.
  if not private.is_service_role() and not private.is_staff() then
    select coalesce(bs.cancellation_window_hours, 24) into v_window_hours
    from public.business_settings bs limit 1;

    if v_booking.starts_at - now() < make_interval(hours => v_window_hours) then
      return private.rpc_err('FORBIDDEN', format(
        'Bookings cannot be cancelled within %s hours of the appointment.',
        v_window_hours));
    end if;
  end if;

  return public.transition_booking(p_booking_id, 'cancelled', p_reason);
end;
$$;

comment on function public.cancel_booking is
  'Cancels a booking, enforcing the client cancellation window.';

-- ============================================================================
-- reschedule_booking
-- Moves an existing booking to a new start time, re-validating availability
-- under advisory locks. Preserves the booking's identity and history.
-- ============================================================================
create or replace function public.reschedule_booking(
  p_booking_id uuid,
  p_starts_at timestamptz,
  p_practitioner_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_active public.booking_status[] := private.active_booking_statuses();
  v_booking public.bookings;
  v_prac uuid;
  v_duration integer;
  v_buf_before integer;
  v_buf_after integer;
  v_requires_room boolean;
  v_starts timestamptz;
  v_ends timestamptz;
  v_bstart timestamptz;
  v_bend timestamptz;
  v_room uuid;
begin
  if v_uid is null and not private.is_service_role() then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and deleted_at is null
  for update;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  if not private.is_service_role()
     and not private.is_staff()
     and v_booking.client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN',
      'You are not permitted to reschedule this booking.');
  end if;

  if v_booking.status not in
     ('pending_hold', 'pending_payment', 'pending_intake', 'confirmed') then
    return private.rpc_err('CONFLICT',
      'This booking can no longer be rescheduled.');
  end if;

  v_prac := coalesce(p_practitioner_id, v_booking.practitioner_id);

  select s.duration_minutes, s.buffer_before_minutes, s.buffer_after_minutes,
         s.requires_room
    into v_duration, v_buf_before, v_buf_after, v_requires_room
  from public.services s where s.id = v_booking.service_id;

  v_starts := p_starts_at;
  v_ends := v_starts + make_interval(mins => v_duration);
  v_bstart := v_starts - make_interval(mins => v_buf_before);
  v_bend := v_ends + make_interval(mins => v_buf_after);

  perform pg_advisory_xact_lock(hashtextextended(v_prac::text, 0));

  -- No overlapping active booking (excluding this booking itself).
  if exists (
    select 1 from public.bookings b
    where b.practitioner_id = v_prac
      and b.id <> p_booking_id
      and b.deleted_at is null
      and b.status = any (v_active)
      and tstzrange(b.buffer_starts_at, b.buffer_ends_at, '[)')
          && tstzrange(v_bstart, v_bend, '[)')
  ) then
    return private.rpc_err('CONFLICT',
      'The requested time is no longer available.');
  end if;

  -- Not inside a blocking period.
  if exists (
    select 1 from public.availability_blocks abl
    where abl.deleted_at is null
      and (abl.practitioner_id = v_prac
           or (abl.practitioner_id is null and abl.room_id is null))
      and tstzrange(abl.starts_at, abl.ends_at, '[)')
          && tstzrange(v_bstart, v_bend, '[)')
  ) then
    return private.rpc_err('CONFLICT',
      'The requested time is unavailable (blocked).');
  end if;

  v_room := v_booking.room_id;

  begin
    update public.bookings
    set starts_at = v_starts,
        ends_at = v_ends,
        buffer_starts_at = v_bstart,
        buffer_ends_at = v_bend,
        practitioner_id = v_prac
    where id = p_booking_id;
  exception
    when exclusion_violation then
      return private.rpc_err('CONFLICT',
        'The requested time was just taken. Please choose another.');
  end;

  -- Record the reschedule explicitly (status is unchanged, so the status
  -- trigger does not fire).
  insert into public.booking_events (
    booking_id, event_type, from_status, to_status, actor_profile_id, metadata
  )
  values (
    p_booking_id, 'rescheduled', v_booking.status, v_booking.status, v_uid,
    jsonb_build_object('new_starts_at', v_starts, 'practitioner_id', v_prac)
  );

  return private.rpc_ok(jsonb_build_object(
    'booking_id', p_booking_id,
    'starts_at', v_starts,
    'ends_at', v_ends,
    'practitioner_id', v_prac,
    'room_id', v_room
  ));
end;
$$;

comment on function public.reschedule_booking is
  'Moves a booking to a new time, re-validating availability under a lock.';

-- ============================================================================
-- expire_booking_holds
-- Releases holds whose expiry has passed by transitioning them to 'expired'.
-- Intended to be run periodically (pg_cron, added in a later milestone).
-- Service-role only.
-- ============================================================================
create or replace function public.expire_booking_holds()
returns integer
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_count integer;
begin
  with expired as (
    update public.bookings
    set status = 'expired', hold_expires_at = null
    where status in ('pending_hold', 'pending_payment')
      and deleted_at is null
      and hold_expires_at is not null
      and hold_expires_at < now()
    returning id
  )
  select count(*) into v_count from expired;

  return v_count;
end;
$$;

comment on function public.expire_booking_holds is
  'Expires holds whose hold_expires_at has passed. Returns the count expired.';

-- ============================================================================
-- Grants (RPC permissions). Only these functions are exposed; everything else
-- was locked down in Milestone 3.
-- ============================================================================
grant execute on function
  public.get_available_slots(uuid, date, date, uuid, integer),
  public.create_booking(uuid, uuid, timestamptz, uuid, uuid, text),
  public.transition_booking(uuid, public.booking_status, text),
  public.cancel_booking(uuid, text),
  public.reschedule_booking(uuid, timestamptz, uuid),
  public.is_valid_booking_transition(public.booking_status, public.booking_status)
to authenticated, service_role;

-- The hold-expiry sweep is a server-side/cron job: service role only.
grant execute on function public.expire_booking_holds() to service_role;
