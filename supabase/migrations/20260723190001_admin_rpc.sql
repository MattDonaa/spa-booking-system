-- ============================================================================
-- Migration: Admin Portal RPCs
-- ----------------------------------------------------------------------------
-- Read and write operations for the admin portal, all gated to admins (a few
-- reads allow staff). Composed JSON is returned in the standard envelope. These
-- functions are SECURITY DEFINER and enforce authorization explicitly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- admin_dashboard: headline operational metrics.
-- ----------------------------------------------------------------------------
create or replace function public.admin_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select jsonb_build_object(
    'today_bookings', (
      select count(*) from public.bookings
      where deleted_at is null
        and starts_at::date = current_date
        and status not in ('cancelled', 'expired', 'no_show')),
    'upcoming_bookings', (
      select count(*) from public.bookings
      where deleted_at is null and starts_at >= now()
        and status in ('pending_hold','pending_payment','pending_intake','confirmed')),
    'pending_payments', (
      select count(*) from public.payments
      where deleted_at is null and status in ('pending','processing')),
    'revenue_month_cents', (
      select coalesce(sum(amount_cents), 0) from public.payments
      where deleted_at is null and status = 'succeeded'
        and paid_at >= date_trunc('month', now())),
    'active_practitioners', (
      select count(*) from public.practitioners
      where deleted_at is null and is_active),
    'pending_forms', (
      select count(*) from public.intake_forms
      where deleted_at is null and status <> 'completed')
  ) into v;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- admin_list_bookings: filter by date range and optional status.
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_bookings(
  p_from timestamptz default now() - interval '7 days',
  p_to timestamptz default now() + interval '30 days',
  p_status public.booking_status default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_id', b.id, 'status', b.status,
    'starts_at', b.starts_at, 'ends_at', b.ends_at,
    'price_cents', b.price_cents, 'currency', b.currency,
    'client_name', cp.full_name,
    'practitioner_name', pp.full_name,
    'service_name', s.name,
    'room_name', r.name
  ) order by b.starts_at), '[]'::jsonb) into v
  from public.bookings b
  join public.clients c on c.id = b.client_id
  join public.profiles cp on cp.id = c.profile_id
  join public.practitioners pr on pr.id = b.practitioner_id
  join public.profiles pp on pp.id = pr.profile_id
  join public.services s on s.id = b.service_id
  left join public.rooms r on r.id = b.room_id
  where b.deleted_at is null
    and b.starts_at >= p_from and b.starts_at <= p_to
    and (p_status is null or b.status = p_status);

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- admin_list_practitioners
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_practitioners()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'practitioner_id', pr.id, 'name', p.full_name, 'email', p.email,
    'title', pr.title, 'bio', pr.bio, 'specialties', pr.specialties,
    'is_active', pr.is_active
  ) order by p.full_name), '[]'::jsonb) into v
  from public.practitioners pr
  join public.profiles p on p.id = pr.profile_id
  where pr.deleted_at is null;

  return private.rpc_ok(v);
end;
$$;

create or replace function public.admin_update_practitioner(
  p_practitioner_id uuid,
  p_title text default null,
  p_bio text default null,
  p_specialties text[] default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  update public.practitioners
  set title = coalesce(p_title, title),
      bio = coalesce(p_bio, bio),
      specialties = coalesce(p_specialties, specialties),
      is_active = coalesce(p_is_active, is_active)
  where id = p_practitioner_id and deleted_at is null;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Practitioner not found.');
  end if;
  return private.rpc_ok(jsonb_build_object('practitioner_id', p_practitioner_id));
end;
$$;

-- ----------------------------------------------------------------------------
-- Services
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_services()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'service_id', s.id, 'name', s.name, 'slug', s.slug,
    'description', s.description, 'duration_minutes', s.duration_minutes,
    'buffer_before_minutes', s.buffer_before_minutes,
    'buffer_after_minutes', s.buffer_after_minutes,
    'price_cents', s.price_cents, 'deposit_cents', s.deposit_cents,
    'currency', s.currency, 'requires_room', s.requires_room,
    'requires_intake', s.requires_intake, 'is_active', s.is_active
  ) order by s.name), '[]'::jsonb) into v
  from public.services s where s.deleted_at is null;

  return private.rpc_ok(v);
end;
$$;

create or replace function public.admin_upsert_service(
  p_name text,
  p_slug text,
  p_duration_minutes integer,
  p_price_cents integer,
  p_service_id uuid default null,
  p_description text default null,
  p_buffer_before_minutes integer default 0,
  p_buffer_after_minutes integer default 0,
  p_deposit_cents integer default 0,
  p_requires_room boolean default true,
  p_requires_intake boolean default false,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare v_id uuid;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  if p_service_id is null then
    insert into public.services (
      name, slug, description, duration_minutes, buffer_before_minutes,
      buffer_after_minutes, price_cents, deposit_cents, requires_room,
      requires_intake, is_active)
    values (
      p_name, p_slug, p_description, p_duration_minutes, p_buffer_before_minutes,
      p_buffer_after_minutes, p_price_cents, p_deposit_cents, p_requires_room,
      p_requires_intake, p_is_active)
    returning id into v_id;
  else
    update public.services set
      name = p_name, slug = p_slug, description = p_description,
      duration_minutes = p_duration_minutes,
      buffer_before_minutes = p_buffer_before_minutes,
      buffer_after_minutes = p_buffer_after_minutes,
      price_cents = p_price_cents, deposit_cents = p_deposit_cents,
      requires_room = p_requires_room, requires_intake = p_requires_intake,
      is_active = p_is_active
    where id = p_service_id and deleted_at is null
    returning id into v_id;
    if v_id is null then
      return private.rpc_err('NOT_FOUND', 'Service not found.');
    end if;
  end if;

  return private.rpc_ok(jsonb_build_object('service_id', v_id));
end;
$$;

-- ----------------------------------------------------------------------------
-- Rooms
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_rooms()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'room_id', r.id, 'name', r.name, 'description', r.description,
    'capacity', r.capacity, 'features', r.features, 'is_active', r.is_active
  ) order by r.name), '[]'::jsonb) into v
  from public.rooms r where r.deleted_at is null;

  return private.rpc_ok(v);
end;
$$;

create or replace function public.admin_upsert_room(
  p_name text,
  p_room_id uuid default null,
  p_description text default null,
  p_capacity integer default 1,
  p_features text[] default '{}',
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare v_id uuid;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  if p_room_id is null then
    insert into public.rooms (name, description, capacity, features, is_active)
    values (p_name, p_description, p_capacity, p_features, p_is_active)
    returning id into v_id;
  else
    update public.rooms set
      name = p_name, description = p_description, capacity = p_capacity,
      features = p_features, is_active = p_is_active
    where id = p_room_id and deleted_at is null
    returning id into v_id;
    if v_id is null then
      return private.rpc_err('NOT_FOUND', 'Room not found.');
    end if;
  end if;

  return private.rpc_ok(jsonb_build_object('room_id', v_id));
end;
$$;

-- ----------------------------------------------------------------------------
-- Availability: list a practitioner's schedule + blocks; add a block.
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_availability(
  p_practitioner_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select jsonb_build_object(
    'schedule', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', pa.id, 'day_of_week', pa.day_of_week,
        'start_time', pa.start_time, 'end_time', pa.end_time
      ) order by pa.day_of_week, pa.start_time), '[]'::jsonb)
      from public.practitioner_availability pa
      where pa.practitioner_id = p_practitioner_id and pa.deleted_at is null),
    'blocks', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', ab.id, 'block_type', ab.block_type,
        'starts_at', ab.starts_at, 'ends_at', ab.ends_at, 'reason', ab.reason
      ) order by ab.starts_at desc), '[]'::jsonb)
      from public.availability_blocks ab
      where ab.practitioner_id = p_practitioner_id and ab.deleted_at is null
        and ab.ends_at >= now() - interval '30 days')
  ) into v;

  return private.rpc_ok(v);
end;
$$;

create or replace function public.admin_add_availability_block(
  p_practitioner_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_block_type public.availability_block_type default 'time_off',
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare v_id uuid;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;
  if p_starts_at >= p_ends_at then
    return private.rpc_err('VALIDATION', 'End must be after start.');
  end if;

  insert into public.availability_blocks (
    practitioner_id, block_type, starts_at, ends_at, reason)
  values (p_practitioner_id, p_block_type, p_starts_at, p_ends_at, p_reason)
  returning id into v_id;

  return private.rpc_ok(jsonb_build_object('block_id', v_id));
end;
$$;

-- ----------------------------------------------------------------------------
-- Payments (admin view)
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_payments(
  p_from timestamptz default now() - interval '30 days',
  p_to timestamptz default now(),
  p_status public.payment_status default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'payment_id', p.id, 'status', p.status, 'amount_cents', p.amount_cents,
    'currency', p.currency, 'provider', p.provider,
    'payment_type', p.payment_type, 'created_at', p.created_at,
    'paid_at', p.paid_at, 'client_name', cp.full_name, 'service_name', s.name
  ) order by p.created_at desc), '[]'::jsonb) into v
  from public.payments p
  join public.bookings b on b.id = p.booking_id
  join public.clients c on c.id = b.client_id
  join public.profiles cp on cp.id = c.profile_id
  join public.services s on s.id = b.service_id
  where p.deleted_at is null
    and p.created_at >= p_from and p.created_at <= p_to
    and (p_status is null or p.status = p_status);

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- Form templates (admin view; create_template_version already exists)
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_templates()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'template_id', t.id, 'name', t.name, 'slug', t.slug,
    'form_type', t.form_type, 'version', t.version,
    'is_medical', t.is_medical, 'is_active', t.is_active,
    'field_count', jsonb_array_length(t.schema)
  ) order by t.slug, t.version desc), '[]'::jsonb) into v
  from public.form_templates t where t.deleted_at is null;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- Business settings
-- ----------------------------------------------------------------------------
create or replace function public.get_business_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Staff access required.');
  end if;

  select to_jsonb(bs) into v from public.business_settings bs limit 1;
  return private.rpc_ok(coalesce(v, '{}'::jsonb));
end;
$$;

create or replace function public.update_business_settings(
  p_business_name text default null,
  p_timezone text default null,
  p_currency char(3) default null,
  p_default_deposit_percentage numeric default null,
  p_hold_duration_minutes integer default null,
  p_min_booking_lead_minutes integer default null,
  p_max_booking_lead_days integer default null,
  p_cancellation_window_hours integer default null,
  p_contact_email text default null,
  p_contact_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  update public.business_settings set
    business_name = coalesce(nullif(btrim(p_business_name), ''), business_name),
    timezone = coalesce(p_timezone, timezone),
    currency = coalesce(p_currency, currency),
    default_deposit_percentage =
      coalesce(p_default_deposit_percentage, default_deposit_percentage),
    hold_duration_minutes = coalesce(p_hold_duration_minutes, hold_duration_minutes),
    min_booking_lead_minutes =
      coalesce(p_min_booking_lead_minutes, min_booking_lead_minutes),
    max_booking_lead_days = coalesce(p_max_booking_lead_days, max_booking_lead_days),
    cancellation_window_hours =
      coalesce(p_cancellation_window_hours, cancellation_window_hours),
    contact_email = coalesce(p_contact_email, contact_email),
    contact_phone = coalesce(p_contact_phone, contact_phone)
  where singleton = true;

  return public.get_business_settings();
end;
$$;

-- ----------------------------------------------------------------------------
-- Audit logs
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_audit_logs(
  p_limit integer default 100,
  p_entity_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb) into v
  from (
    select a.created_at,
      jsonb_build_object(
        'id', a.id, 'action', a.action, 'entity_type', a.entity_type,
        'entity_id', a.entity_id, 'actor_profile_id', a.actor_profile_id,
        'created_at', a.created_at
      ) as row
    from public.audit_logs a
    where (p_entity_type is null or a.entity_type = p_entity_type)
    order by a.created_at desc
    limit least(greatest(p_limit, 1), 500)
  ) sub;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- Notification centre: list + retry
-- ----------------------------------------------------------------------------
create or replace function public.admin_list_notifications(
  p_status public.notification_status default null,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb) into v
  from (
    select q.created_at,
      jsonb_build_object(
        'id', q.id, 'channel', q.channel, 'notification_type', q.notification_type,
        'status', q.status, 'attempts', q.attempts, 'max_attempts', q.max_attempts,
        'scheduled_for', q.scheduled_for, 'sent_at', q.sent_at,
        'last_error', q.last_error, 'created_at', q.created_at
      ) as row
    from public.notification_queue q
    where q.deleted_at is null
      and (p_status is null or q.status = p_status)
    order by q.created_at desc
    limit least(greatest(p_limit, 1), 500)
  ) sub;

  return private.rpc_ok(v);
end;
$$;

create or replace function public.admin_retry_notification(
  p_notification_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  update public.notification_queue
  set status = 'queued', next_attempt_at = null, scheduled_for = now(),
      attempts = case when attempts >= max_attempts then 0 else attempts end
  where id = p_notification_id and status = 'failed' and deleted_at is null;

  if not found then
    return private.rpc_err('CONFLICT', 'Only failed notifications can be retried.');
  end if;
  return private.rpc_ok(jsonb_build_object('notification_id', p_notification_id));
end;
$$;

-- ----------------------------------------------------------------------------
-- Reports: light operational summary (deeper analytics in Milestone 10).
-- ----------------------------------------------------------------------------
create or replace function public.admin_reports(
  p_from date default (current_date - 30),
  p_to date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare v jsonb;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  select jsonb_build_object(
    'range', jsonb_build_object('from', p_from, 'to', p_to),
    'bookings_total', (
      select count(*) from public.bookings
      where deleted_at is null and starts_at::date between p_from and p_to),
    'bookings_completed', (
      select count(*) from public.bookings
      where deleted_at is null and status = 'completed'
        and starts_at::date between p_from and p_to),
    'bookings_cancelled', (
      select count(*) from public.bookings
      where deleted_at is null and status in ('cancelled','no_show')
        and starts_at::date between p_from and p_to),
    'revenue_cents', (
      select coalesce(sum(amount_cents), 0) from public.payments
      where deleted_at is null and status = 'succeeded'
        and paid_at::date between p_from and p_to),
    'refunds_cents', (
      select coalesce(sum(amount_cents), 0) from public.refunds
      where deleted_at is null and status = 'succeeded'
        and refunded_at::date between p_from and p_to)
  ) into v;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- Grants (authorization is enforced inside each function).
-- ----------------------------------------------------------------------------
grant execute on function
  public.admin_dashboard(),
  public.admin_list_bookings(timestamptz, timestamptz, public.booking_status),
  public.admin_list_practitioners(),
  public.admin_update_practitioner(uuid, text, text, text[], boolean),
  public.admin_list_services(),
  public.admin_upsert_service(text, text, integer, integer, uuid, text, integer, integer, integer, boolean, boolean, boolean),
  public.admin_list_rooms(),
  public.admin_upsert_room(text, uuid, text, integer, text[], boolean),
  public.admin_list_availability(uuid),
  public.admin_add_availability_block(uuid, timestamptz, timestamptz, public.availability_block_type, text),
  public.admin_list_payments(timestamptz, timestamptz, public.payment_status),
  public.admin_list_templates(),
  public.get_business_settings(),
  public.update_business_settings(text, text, char, numeric, integer, integer, integer, integer, text, text),
  public.admin_list_audit_logs(integer, text),
  public.admin_list_notifications(public.notification_status, integer),
  public.admin_retry_notification(uuid),
  public.admin_reports(date, date)
to authenticated, service_role;
