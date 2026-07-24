-- ============================================================================
-- Migration: Analytics RPCs
-- ----------------------------------------------------------------------------
-- Read-only analytics aggregates for the admin portal, all admin-gated. Each
-- returns composed JSON in the standard envelope. Monetary values are in cents.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- analytics_overview: headline KPIs, a daily revenue series, the booking status
-- breakdown, conversion, abandonment, no-shows, cancellations, and averages.
-- ----------------------------------------------------------------------------
create or replace function public.analytics_overview(
  p_from date default (current_date - 30),
  p_to date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v jsonb;
  v_created integer;
  v_converted integer;
begin
  if not private.is_admin() then
    return private.rpc_err('FORBIDDEN', 'Admin access required.');
  end if;

  -- Conversion is measured over bookings created in the window: those that
  -- reached confirmed or beyond vs all created.
  select count(*) into v_created
  from public.bookings
  where deleted_at is null and created_at::date between p_from and p_to;

  select count(*) into v_converted
  from public.bookings
  where deleted_at is null and created_at::date between p_from and p_to
    and status in ('confirmed','checked_in','in_progress','completed','refunded');

  select jsonb_build_object(
    'range', jsonb_build_object('from', p_from, 'to', p_to),
    'kpis', jsonb_build_object(
      'revenue_cents', (
        select coalesce(sum(amount_cents),0) from public.payments
        where deleted_at is null and status = 'succeeded'
          and paid_at::date between p_from and p_to),
      'refunds_cents', (
        select coalesce(sum(amount_cents),0) from public.refunds
        where deleted_at is null and status = 'succeeded'
          and refunded_at::date between p_from and p_to),
      'bookings_created', v_created,
      'bookings_completed', (
        select count(*) from public.bookings
        where deleted_at is null and status = 'completed'
          and starts_at::date between p_from and p_to),
      'no_shows', (
        select count(*) from public.bookings
        where deleted_at is null and status = 'no_show'
          and starts_at::date between p_from and p_to),
      'cancellations', (
        select count(*) from public.bookings
        where deleted_at is null and status = 'cancelled'
          and starts_at::date between p_from and p_to),
      'abandoned', (
        select count(*) from public.bookings
        where deleted_at is null and status = 'expired'
          and created_at::date between p_from and p_to),
      'avg_booking_value_cents', (
        select coalesce(round(avg(price_cents)),0)::int from public.bookings
        where deleted_at is null and status = 'completed'
          and starts_at::date between p_from and p_to),
      'conversion_rate_pct', case when v_created > 0
        then round(100.0 * v_converted / v_created, 1) else 0 end
    ),
    'revenue_series', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', d::date, 'revenue_cents', coalesce(r.revenue,0)) order by d), '[]'::jsonb)
      from generate_series(p_from, p_to, interval '1 day') d
      left join (
        select paid_at::date as day, sum(amount_cents) as revenue
        from public.payments
        where deleted_at is null and status = 'succeeded'
          and paid_at::date between p_from and p_to
        group by paid_at::date
      ) r on r.day = d::date
    ),
    'status_breakdown', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'status', status, 'count', cnt) order by cnt desc), '[]'::jsonb)
      from (
        select status, count(*) as cnt from public.bookings
        where deleted_at is null and created_at::date between p_from and p_to
        group by status
      ) s
    )
  ) into v;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- analytics_services: popular treatments by volume and revenue.
-- ----------------------------------------------------------------------------
create or replace function public.analytics_services(
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

  select coalesce(jsonb_agg(jsonb_build_object(
    'service_name', name, 'bookings', bookings, 'revenue_cents', revenue
  ) order by bookings desc), '[]'::jsonb) into v
  from (
    select s.name,
      count(*) filter (where b.status not in ('cancelled','expired','no_show')) as bookings,
      coalesce(sum(p.amount_cents) filter (where p.status = 'succeeded'), 0) as revenue
    from public.bookings b
    join public.services s on s.id = b.service_id
    left join public.payments p on p.booking_id = b.id and p.deleted_at is null
    where b.deleted_at is null and b.starts_at::date between p_from and p_to
    group by s.name
  ) t;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- analytics_practitioners: utilisation/occupancy and performance.
-- Utilisation = booked minutes / available minutes (from the recurring
-- schedule) over the window.
-- ----------------------------------------------------------------------------
create or replace function public.analytics_practitioners(
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

  with available as (
    select pa.practitioner_id,
      sum(
        (extract(epoch from (pa.end_time - pa.start_time)) / 60.0)
        * (select count(*) from generate_series(p_from, p_to, interval '1 day') d
           where extract(dow from d)::int = pa.day_of_week)
      ) as available_minutes
    from public.practitioner_availability pa
    where pa.deleted_at is null
    group by pa.practitioner_id
  ),
  booked as (
    select b.practitioner_id,
      count(*) as bookings,
      sum(extract(epoch from (b.ends_at - b.starts_at)) / 60.0) as booked_minutes,
      coalesce(sum(pay.amount_cents) filter (where pay.status = 'succeeded'), 0) as revenue
    from public.bookings b
    left join public.payments pay on pay.booking_id = b.id and pay.deleted_at is null
    where b.deleted_at is null
      and b.starts_at::date between p_from and p_to
      and b.status in ('confirmed','checked_in','in_progress','completed')
    group by b.practitioner_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'practitioner_name', prof.full_name,
    'bookings', coalesce(bk.bookings, 0),
    'booked_minutes', round(coalesce(bk.booked_minutes, 0))::int,
    'available_minutes', round(coalesce(av.available_minutes, 0))::int,
    'utilisation_pct', case
      when coalesce(av.available_minutes, 0) > 0
      then round(100.0 * coalesce(bk.booked_minutes,0) / av.available_minutes, 1)
      else 0 end,
    'revenue_cents', coalesce(bk.revenue, 0)
  ) order by coalesce(bk.revenue, 0) desc), '[]'::jsonb) into v
  from public.practitioners pr
  join public.profiles prof on prof.id = pr.profile_id
  left join available av on av.practitioner_id = pr.id
  left join booked bk on bk.practitioner_id = pr.id
  where pr.deleted_at is null and pr.is_active;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- analytics_clients: lifetime value (all-time) — average and top clients.
-- ----------------------------------------------------------------------------
create or replace function public.analytics_clients(
  p_limit integer default 10
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

  with ltv as (
    select b.client_id,
      count(distinct b.id) filter (where b.status = 'completed') as visits,
      coalesce(sum(p.amount_cents) filter (where p.status = 'succeeded'), 0) as total
    from public.bookings b
    left join public.payments p on p.booking_id = b.id and p.deleted_at is null
    where b.deleted_at is null
    group by b.client_id
  )
  select jsonb_build_object(
    'average_ltv_cents', (
      select coalesce(round(avg(total)), 0)::int from ltv where total > 0),
    'top', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'client_name', prof.full_name, 'visits', l.visits, 'total_cents', l.total
      ) order by l.total desc), '[]'::jsonb)
      from (select * from ltv order by total desc limit least(greatest(p_limit,1),50)) l
      join public.clients c on c.id = l.client_id
      join public.profiles prof on prof.id = c.profile_id
    )
  ) into v;

  return private.rpc_ok(v);
end;
$$;

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
grant execute on function
  public.analytics_overview(date, date),
  public.analytics_services(date, date),
  public.analytics_practitioners(date, date),
  public.analytics_clients(integer)
to authenticated, service_role;
