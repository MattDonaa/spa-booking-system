-- ============================================================================
-- Tests: Payment engine & webhook idempotency (RPC tests)
-- Run with: supabase test db
-- ============================================================================
begin;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'pc@test.dev',
   '{"role":"client","full_name":"Pay Client"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'pp@test.dev',
   '{"role":"practitioner","full_name":"Pay Prac"}'::jsonb);
insert into public.practitioners (id, profile_id)
  values ('33333333-3333-3333-3333-333333333333',
          '22222222-2222-2222-2222-222222222222');
insert into public.rooms (id, name)
  values ('44444444-4444-4444-4444-444444444444', 'Room');
insert into public.services (id, name, slug, duration_minutes, price_cents,
    deposit_cents, requires_room)
  values ('55555555-5555-5555-5555-555555555555', 'Svc', 'svc', 60, 100000,
          20000, true);
insert into public.practitioner_services (practitioner_id, service_id)
  values ('33333333-3333-3333-3333-333333333333',
          '55555555-5555-5555-5555-555555555555');
insert into public.practitioner_availability (practitioner_id, day_of_week,
    start_time, end_time)
  select '33333333-3333-3333-3333-333333333333', d, '00:00', '23:59'
  from generate_series(0, 6) as d;

create temporary table _b (id uuid) on commit drop;
insert into _b
select (public.create_booking(
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  date_trunc('hour', now()) + interval '2 days',
  '11111111-1111-1111-1111-111111111111') -> 'data' ->> 'booking_id')::uuid;

-- 1. initiate_payment succeeds.
select is(
  (public.initiate_payment((select id from _b), 'payfast', 'deposit') ->> 'ok'),
  'true', 'initiate_payment succeeds');

-- 2. It is idempotent: a second call does not create a second payment.
create temporary table _p (id uuid) on commit drop;
insert into _p
select (public.initiate_payment((select id from _b), 'payfast', 'deposit')
        -> 'data' ->> 'payment_id')::uuid;
select is(
  (select count(*)::int from public.payments where booking_id = (select id from _b)),
  1, 'initiate_payment is idempotent');

-- 3. A verified success webhook is applied and advances the booking.
select is(
  (public.record_payment_event('payfast', 'evt_1', (select id from _p),
     'succeeded', 'ref1', true, '{}'::jsonb) ->> 'ok'),
  'true', 'verified webhook applied');
select is(
  (select status::text from public.bookings where id = (select id from _b)),
  'confirmed', 'booking advanced to confirmed on payment success');

-- 4. A duplicate webhook (same provider event_id) is a no-op.
select is(
  (public.record_payment_event('payfast', 'evt_1', (select id from _p),
     'succeeded', 'ref1', true, '{}'::jsonb) #>> '{data,already_processed}'),
  'true', 'duplicate webhook event is idempotent');

-- 5. An unverified signature is rejected.
select is(
  (public.record_payment_event('payfast', 'evt_2', (select id from _p),
     'succeeded', 'ref2', false, '{}'::jsonb) #>> '{error,code}'),
  'FORBIDDEN', 'unverified webhook signature rejected');

select * from finish();
rollback;
