-- ============================================================================
-- Migration: Client Portal Read/Update RPCs
-- ----------------------------------------------------------------------------
-- Read models and profile updates for the client portal. Returning composed
-- JSON from the database keeps query logic server-side and consistent with the
-- rest of the system. Each function is scoped to the calling client (or staff/
-- admin/service) and returns the standard { ok, data | error } envelope.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- get_my_profile
-- ----------------------------------------------------------------------------
create or replace function public.get_my_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  select jsonb_build_object(
    'profile_id', p.id,
    'role', p.role,
    'email', p.email,
    'full_name', p.full_name,
    'phone', p.phone,
    'avatar_url', p.avatar_url,
    'client', case when c.id is null then null else jsonb_build_object(
      'client_id', c.id,
      'date_of_birth', c.date_of_birth,
      'emergency_contact_name', c.emergency_contact_name,
      'emergency_contact_phone', c.emergency_contact_phone,
      'marketing_opt_in', c.marketing_opt_in
    ) end
  )
  into v_result
  from public.profiles p
  left join public.clients c on c.profile_id = p.id and c.deleted_at is null
  where p.id = v_uid and p.deleted_at is null;

  if v_result is null then
    return private.rpc_err('NOT_FOUND', 'Profile not found.');
  end if;
  return private.rpc_ok(v_result);
end;
$$;

-- ----------------------------------------------------------------------------
-- update_my_profile
-- ----------------------------------------------------------------------------
create or replace function public.update_my_profile(
  p_full_name text default null,
  p_phone text default null,
  p_date_of_birth date default null,
  p_emergency_contact_name text default null,
  p_emergency_contact_phone text default null,
  p_marketing_opt_in boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  update public.profiles
  set full_name = coalesce(nullif(btrim(p_full_name), ''), full_name),
      phone = coalesce(p_phone, phone)
  where id = v_uid and deleted_at is null;

  update public.clients
  set date_of_birth = coalesce(p_date_of_birth, date_of_birth),
      emergency_contact_name =
        coalesce(p_emergency_contact_name, emergency_contact_name),
      emergency_contact_phone =
        coalesce(p_emergency_contact_phone, emergency_contact_phone),
      marketing_opt_in = coalesce(p_marketing_opt_in, marketing_opt_in)
  where profile_id = v_uid and deleted_at is null;

  return public.get_my_profile();
end;
$$;

-- ----------------------------------------------------------------------------
-- list_my_bookings: scope = 'upcoming' | 'past' | 'all'
-- ----------------------------------------------------------------------------
create or replace function public.list_my_bookings(
  p_scope text default 'all'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_client uuid := private.current_client_id();
  v_rows jsonb;
begin
  if v_client is null then
    return private.rpc_err('FORBIDDEN', 'No client account.');
  end if;

  select coalesce(jsonb_agg(row order by row_starts desc), '[]'::jsonb)
  into v_rows
  from (
    select
      b.starts_at as row_starts,
      jsonb_build_object(
        'booking_id', b.id,
        'status', b.status,
        'starts_at', b.starts_at,
        'ends_at', b.ends_at,
        'price_cents', b.price_cents,
        'deposit_cents', b.deposit_cents,
        'currency', b.currency,
        'service', jsonb_build_object('id', s.id, 'name', s.name),
        'practitioner', jsonb_build_object('id', pr.id, 'name', pp.full_name)
      ) as row
    from public.bookings b
    join public.services s on s.id = b.service_id
    join public.practitioners pr on pr.id = b.practitioner_id
    join public.profiles pp on pp.id = pr.profile_id
    where b.client_id = v_client
      and b.deleted_at is null
      and (
        p_scope = 'all'
        or (p_scope = 'upcoming' and b.starts_at >= now()
            and b.status not in ('cancelled', 'expired', 'no_show', 'completed', 'refunded'))
        or (p_scope = 'past' and (b.starts_at < now()
            or b.status in ('completed', 'cancelled', 'no_show', 'refunded', 'expired')))
      )
  ) sub;

  return private.rpc_ok(v_rows);
end;
$$;

-- ----------------------------------------------------------------------------
-- get_my_booking: full detail incl. payments, intake forms, action flags.
-- ----------------------------------------------------------------------------
create or replace function public.get_my_booking(
  p_booking_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_client uuid := private.current_client_id();
  v_booking public.bookings;
  v_window integer;
  v_can_cancel boolean;
  v_can_reschedule boolean;
  v_payments jsonb;
  v_forms jsonb;
  v_detail jsonb;
begin
  select * into v_booking
  from public.bookings
  where id = p_booking_id and deleted_at is null;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  if not private.is_admin()
     and v_booking.client_id is distinct from v_client
     and v_booking.practitioner_id is distinct from private.current_practitioner_id() then
    return private.rpc_err('FORBIDDEN', 'Not permitted.');
  end if;

  select coalesce(cancellation_window_hours, 24) into v_window
  from public.business_settings limit 1;

  v_can_reschedule := v_booking.status in
    ('pending_hold', 'pending_payment', 'pending_intake', 'confirmed');
  v_can_cancel := v_booking.status in
    ('pending_hold', 'pending_payment', 'pending_intake', 'confirmed')
    and v_booking.starts_at - now() >= make_interval(hours => v_window);

  select coalesce(jsonb_agg(jsonb_build_object(
      'payment_id', p.id, 'status', p.status, 'amount_cents', p.amount_cents,
      'currency', p.currency, 'payment_type', p.payment_type,
      'provider', p.provider, 'paid_at', p.paid_at, 'created_at', p.created_at
    ) order by p.created_at desc), '[]'::jsonb)
  into v_payments
  from public.payments p where p.booking_id = p_booking_id and p.deleted_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
      'intake_form_id', f.id, 'status', f.status, 'is_medical', f.is_medical,
      'template_name', t.name
    )), '[]'::jsonb)
  into v_forms
  from public.intake_forms f
  join public.form_templates t on t.id = f.template_id
  where f.booking_id = p_booking_id and f.deleted_at is null;

  select jsonb_build_object(
    'booking_id', v_booking.id,
    'status', v_booking.status,
    'starts_at', v_booking.starts_at,
    'ends_at', v_booking.ends_at,
    'price_cents', v_booking.price_cents,
    'deposit_cents', v_booking.deposit_cents,
    'currency', v_booking.currency,
    'notes', v_booking.notes,
    'service', jsonb_build_object('id', s.id, 'name', s.name,
                                  'duration_minutes', s.duration_minutes),
    'practitioner', jsonb_build_object('id', pr.id, 'name', pp.full_name),
    'can_cancel', v_can_cancel,
    'can_reschedule', v_can_reschedule,
    'payments', v_payments,
    'intake_forms', v_forms
  )
  into v_detail
  from public.services s, public.practitioners pr, public.profiles pp
  where s.id = v_booking.service_id
    and pr.id = v_booking.practitioner_id
    and pp.id = pr.profile_id;

  return private.rpc_ok(v_detail);
end;
$$;

-- ----------------------------------------------------------------------------
-- list_my_payments: payments across the client's bookings (for invoices).
-- ----------------------------------------------------------------------------
create or replace function public.list_my_payments()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_client uuid := private.current_client_id();
  v_rows jsonb;
begin
  if v_client is null then
    return private.rpc_err('FORBIDDEN', 'No client account.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'payment_id', p.id,
      'booking_id', p.booking_id,
      'status', p.status,
      'amount_cents', p.amount_cents,
      'currency', p.currency,
      'payment_type', p.payment_type,
      'provider', p.provider,
      'paid_at', p.paid_at,
      'created_at', p.created_at,
      'service_name', s.name,
      'starts_at', b.starts_at
    ) order by p.created_at desc), '[]'::jsonb)
  into v_rows
  from public.payments p
  join public.bookings b on b.id = p.booking_id
  join public.services s on s.id = b.service_id
  where b.client_id = v_client and p.deleted_at is null;

  return private.rpc_ok(v_rows);
end;
$$;

-- ----------------------------------------------------------------------------
-- list_my_intake_forms: intake forms across the client's bookings.
-- ----------------------------------------------------------------------------
create or replace function public.list_my_intake_forms()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_client uuid := private.current_client_id();
  v_rows jsonb;
begin
  if v_client is null then
    return private.rpc_err('FORBIDDEN', 'No client account.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'intake_form_id', f.id,
      'booking_id', f.booking_id,
      'status', f.status,
      'is_medical', f.is_medical,
      'template_name', t.name,
      'starts_at', b.starts_at,
      'service_name', s.name
    ) order by b.starts_at desc), '[]'::jsonb)
  into v_rows
  from public.intake_forms f
  join public.form_templates t on t.id = f.template_id
  join public.bookings b on b.id = f.booking_id
  join public.services s on s.id = b.service_id
  where f.client_id = v_client and f.deleted_at is null;

  return private.rpc_ok(v_rows);
end;
$$;

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
grant execute on function
  public.get_my_profile(),
  public.update_my_profile(text, text, date, text, text, boolean),
  public.list_my_bookings(text),
  public.get_my_booking(uuid),
  public.list_my_payments(),
  public.list_my_intake_forms()
to authenticated, service_role;
