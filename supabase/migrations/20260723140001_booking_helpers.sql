-- ============================================================================
-- Migration: Booking Engine — Helpers & State Machine
-- ----------------------------------------------------------------------------
-- Shared building blocks for the booking engine:
--   * private.active_booking_statuses()  — statuses that occupy a time slot.
--   * public.is_valid_booking_transition() — the booking state machine, as a
--     pure lookup of allowed (from -> to) transitions.
--   * public.get_available_slots()        — the availability engine.
--
-- All booking mutations live in PostgreSQL (Milestone 4b). The frontend never
-- inserts bookings directly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Statuses for which a booking occupies its time slot (blocks other bookings).
-- Terminal/released statuses (expired, cancelled, refunded, no_show) are absent
-- so their slots free up immediately.
-- ----------------------------------------------------------------------------
create or replace function private.active_booking_statuses()
returns public.booking_status[]
language sql
immutable
as $$
  select array[
    'pending_hold', 'pending_payment', 'pending_intake',
    'confirmed', 'checked_in', 'in_progress', 'completed'
  ]::public.booking_status[];
$$;

-- ----------------------------------------------------------------------------
-- Booking state machine. Returns true when a transition from -> to is allowed.
-- Terminal states (expired, cancelled, refunded, no_show) permit no outward
-- transitions. Idempotent no-op transitions (from = to) are not "changes" and
-- are rejected here; callers should treat them as already-in-state.
-- ----------------------------------------------------------------------------
create or replace function public.is_valid_booking_transition(
  p_from public.booking_status,
  p_to public.booking_status
)
returns boolean
language sql
immutable
as $$
  select p_to = any (
    case p_from
      when 'pending_hold' then
        array['pending_payment', 'pending_intake', 'confirmed',
              'cancelled', 'expired']
      when 'pending_payment' then
        array['pending_intake', 'confirmed', 'cancelled', 'expired']
      when 'pending_intake' then
        array['confirmed', 'cancelled', 'expired']
      when 'confirmed' then
        array['checked_in', 'cancelled', 'no_show']
      when 'checked_in' then
        array['in_progress', 'no_show', 'cancelled']
      when 'in_progress' then
        array['completed', 'cancelled']
      when 'completed' then
        array['refunded']
      else
        array[]::text[]
    end::public.booking_status[]
  );
$$;

comment on function public.is_valid_booking_transition is
  'Booking state machine: true if the from -> to status transition is permitted.';

-- ----------------------------------------------------------------------------
-- Availability engine.
--
-- Returns bookable slots for a service over a date range, honouring:
--   * practitioner recurring working hours (with effective_from/effective_to),
--   * service duration and before/after buffer times,
--   * existing active bookings (buffered overlap) per practitioner,
--   * availability blocks / time off / holidays (practitioner-specific,
--     room-specific, and business-wide),
--   * room availability when the service requires a room,
--   * minimum booking lead time and the maximum future booking window.
--
-- Times are interpreted in the business timezone (business_settings.timezone).
-- The date range is capped at 62 days to bound the work.
-- ----------------------------------------------------------------------------
create or replace function public.get_available_slots(
  p_service_id uuid,
  p_from date,
  p_to date,
  p_practitioner_id uuid default null,
  p_step_minutes integer default 15
)
returns table (
  practitioner_id uuid,
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_tz text;
  v_lead_minutes integer;
  v_max_days integer;
  v_duration integer;
  v_buf_before integer;
  v_buf_after integer;
  v_requires_room boolean;
  v_active public.booking_status[] := private.active_booking_statuses();
  v_now timestamptz := now();
  v_earliest timestamptz;
  v_latest timestamptz;
  v_prac uuid;
  v_day date;
  v_win record;
  v_cursor timestamptz;
  v_start timestamptz;
  v_end timestamptz;
  v_bstart timestamptz;
  v_bend timestamptz;
begin
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'Invalid date range' using errcode = 'check_violation';
  end if;
  if (p_to - p_from) > 62 then
    raise exception 'Date range too large (max 62 days)'
      using errcode = 'check_violation';
  end if;
  if p_step_minutes < 5 or p_step_minutes > 240 then
    raise exception 'Invalid step size' using errcode = 'check_violation';
  end if;

  select bs.timezone, bs.min_booking_lead_minutes, bs.max_booking_lead_days
    into v_tz, v_lead_minutes, v_max_days
  from public.business_settings bs
  limit 1;

  v_tz := coalesce(v_tz, 'Africa/Johannesburg');
  v_lead_minutes := coalesce(v_lead_minutes, 120);
  v_max_days := coalesce(v_max_days, 90);

  select s.duration_minutes, s.buffer_before_minutes, s.buffer_after_minutes,
         s.requires_room
    into v_duration, v_buf_before, v_buf_after, v_requires_room
  from public.services s
  where s.id = p_service_id and s.is_active and s.deleted_at is null;

  if not found then
    return; -- unknown/inactive service: no slots.
  end if;

  v_earliest := v_now + make_interval(mins => v_lead_minutes);
  v_latest := v_now + make_interval(days => v_max_days);

  -- Iterate candidate practitioners offering this service.
  for v_prac in
    select pr.id
    from public.practitioners pr
    join public.practitioner_services ps
      on ps.practitioner_id = pr.id and ps.deleted_at is null
    where ps.service_id = p_service_id
      and pr.is_active
      and pr.deleted_at is null
      and (p_practitioner_id is null or pr.id = p_practitioner_id)
  loop
    -- Iterate each day in the requested range.
    for v_day in
      select d::date
      from generate_series(p_from, p_to, interval '1 day') as d
    loop
      -- Iterate this practitioner's working windows for that weekday.
      for v_win in
        select pa.start_time, pa.end_time
        from public.practitioner_availability pa
        where pa.practitioner_id = v_prac
          and pa.deleted_at is null
          and pa.day_of_week = extract(dow from v_day)::smallint
          and (pa.effective_from is null or pa.effective_from <= v_day)
          and (pa.effective_to is null or pa.effective_to >= v_day)
      loop
        v_cursor := (v_day + v_win.start_time) at time zone v_tz;

        while (v_cursor + make_interval(mins => v_duration))
              <= ((v_day + v_win.end_time) at time zone v_tz) loop
          v_start := v_cursor;
          v_end := v_start + make_interval(mins => v_duration);
          v_bstart := v_start - make_interval(mins => v_buf_before);
          v_bend := v_end + make_interval(mins => v_buf_after);

          if v_start >= v_earliest and v_start <= v_latest
            -- No overlapping active booking for this practitioner.
            and not exists (
              select 1 from public.bookings b
              where b.practitioner_id = v_prac
                and b.deleted_at is null
                and b.status = any (v_active)
                and tstzrange(b.buffer_starts_at, b.buffer_ends_at, '[)')
                    && tstzrange(v_bstart, v_bend, '[)')
            )
            -- No blocking period (practitioner-specific or business-wide).
            and not exists (
              select 1 from public.availability_blocks abl
              where abl.deleted_at is null
                and (
                  abl.practitioner_id = v_prac
                  or (abl.practitioner_id is null and abl.room_id is null)
                )
                and tstzrange(abl.starts_at, abl.ends_at, '[)')
                    && tstzrange(v_bstart, v_bend, '[)')
            )
            -- If a room is required, at least one must be free.
            and (
              not v_requires_room
              or exists (
                select 1 from public.rooms r
                where r.is_active and r.deleted_at is null
                  and not exists (
                    select 1 from public.bookings b2
                    where b2.room_id = r.id
                      and b2.deleted_at is null
                      and b2.status = any (v_active)
                      and tstzrange(b2.buffer_starts_at, b2.buffer_ends_at, '[)')
                          && tstzrange(v_bstart, v_bend, '[)')
                  )
                  and not exists (
                    select 1 from public.availability_blocks abl2
                    where abl2.room_id = r.id
                      and abl2.deleted_at is null
                      and tstzrange(abl2.starts_at, abl2.ends_at, '[)')
                          && tstzrange(v_bstart, v_bend, '[)')
                  )
              )
            )
          then
            practitioner_id := v_prac;
            starts_at := v_start;
            ends_at := v_end;
            return next;
          end if;

          v_cursor := v_cursor + make_interval(mins => p_step_minutes);
        end loop;
      end loop;
    end loop;
  end loop;

  return;
end;
$$;

comment on function public.get_available_slots is
  'Availability engine: bookable slots for a service over a date range.';
