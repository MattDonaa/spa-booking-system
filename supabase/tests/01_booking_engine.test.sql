-- ============================================================================
-- Tests: Booking engine (create / conflict / lead-time / transition /
--        cancel window / hold expiry / availability)
--
-- Run with: supabase test db
--
-- These tests run as the migration superuser, for which auth.uid() is NULL, so
-- private.is_service_role() returns true and the RPCs act in a trusted server
-- context. Client identity is passed explicitly via p_client_id.
-- ============================================================================
begin;
select plan(12);

-- --------------------------------------------------------------------------
-- Fixtures. Auth users drive the handle_new_user trigger, which provisions
-- profiles (and a client row for the client user).
-- --------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data)
values
  ('11111111-1111-1111-1111-111111111111', 'client@test.dev',
   '{"role":"client","full_name":"Test Client"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'prac@test.dev',
   '{"role":"practitioner","full_name":"Test Practitioner"}'::jsonb);

-- Practitioner row for the practitioner profile.
insert into public.practitioners (id, profile_id, is_active)
values ('33333333-3333-3333-3333-333333333333',
        '22222222-2222-2222-2222-222222222222', true);

-- A room.
insert into public.rooms (id, name)
values ('44444444-4444-4444-4444-444444444444', 'Room 1');

-- A service (60 min, 10 min buffers, requires a room).
insert into public.services (
  id, name, slug, duration_minutes, buffer_before_minutes,
  buffer_after_minutes, price_cents, deposit_cents, requires_room
)
values ('55555555-5555-5555-5555-555555555555', 'Massage', 'massage',
        60, 10, 10, 100000, 0, true);

-- Practitioner offers the service.
insert into public.practitioner_services (practitioner_id, service_id)
values ('33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555');

-- Practitioner available all day, every day.
insert into public.practitioner_availability (
  practitioner_id, day_of_week, start_time, end_time
)
select '33333333-3333-3333-3333-333333333333', d, '00:00', '23:59'
from generate_series(0, 6) as d;

-- A capture variable via a temp table for the created booking id.
create temporary table _t (start_at timestamptz, booking_id uuid) on commit drop;
insert into _t (start_at)
values (date_trunc('hour', now()) + interval '2 days' + interval '10 hours');

-- --------------------------------------------------------------------------
-- 1. Happy path: create a booking.
-- --------------------------------------------------------------------------
select is(
  (public.create_booking(
     '55555555-5555-5555-5555-555555555555',
     '33333333-3333-3333-3333-333333333333',
     (select start_at from _t),
     '11111111-1111-1111-1111-111111111111'
   ) ->> 'ok'),
  'true',
  'create_booking succeeds for a free slot');

-- Record the created booking id for later assertions.
update _t set booking_id = (
  select id from public.bookings order by created_at desc limit 1
);

-- 2. Exactly one booking exists and it is a hold.
select is(
  (select count(*)::int from public.bookings), 1,
  'exactly one booking was created');
select is(
  (select status::text from public.bookings limit 1), 'pending_hold',
  'new booking is in pending_hold');

-- 3. A booking_event was recorded on creation.
select ok(
  exists (
    select 1 from public.booking_events
    where booking_id = (select booking_id from _t)
      and event_type = 'created'
  ),
  'a "created" booking_event was recorded');

-- 4. A room was auto-assigned.
select ok(
  (select room_id from public.bookings limit 1) is not null,
  'a room was auto-assigned');

-- --------------------------------------------------------------------------
-- 5. Double booking: an overlapping create is rejected with CONFLICT.
-- --------------------------------------------------------------------------
select is(
  (public.create_booking(
     '55555555-5555-5555-5555-555555555555',
     '33333333-3333-3333-3333-333333333333',
     (select start_at from _t),
     '11111111-1111-1111-1111-111111111111'
   ) #>> '{error,code}'),
  'CONFLICT',
  'overlapping booking is rejected with CONFLICT');

-- --------------------------------------------------------------------------
-- 6. Lead-time rule: a start time in the past/too-soon is rejected.
-- --------------------------------------------------------------------------
select is(
  (public.create_booking(
     '55555555-5555-5555-5555-555555555555',
     '33333333-3333-3333-3333-333333333333',
     now() + interval '5 minutes',
     '11111111-1111-1111-1111-111111111111'
   ) #>> '{error,code}'),
  'VALIDATION',
  'a start time within the lead window is rejected');

-- --------------------------------------------------------------------------
-- 7. State machine via transition_booking: illegal jump is rejected.
-- --------------------------------------------------------------------------
select is(
  (public.transition_booking(
     (select booking_id from _t), 'completed'
   ) #>> '{error,code}'),
  'CONFLICT',
  'pending_hold -> completed is rejected by transition_booking');

-- 8. Legal transition succeeds.
select is(
  (public.transition_booking(
     (select booking_id from _t), 'pending_payment'
   ) ->> 'ok'),
  'true',
  'pending_hold -> pending_payment succeeds');

-- --------------------------------------------------------------------------
-- 9. Hold expiry sweep expires an overdue hold.
-- --------------------------------------------------------------------------
update public.bookings
set hold_expires_at = now() - interval '1 minute'
where id = (select booking_id from _t);

select ok(
  public.expire_booking_holds() >= 1,
  'expire_booking_holds expires at least one overdue hold');
select is(
  (select status::text from public.bookings
   where id = (select booking_id from _t)),
  'expired',
  'the overdue hold is now expired');

-- --------------------------------------------------------------------------
-- 10. Availability: the freed slot is offered again after expiry.
-- --------------------------------------------------------------------------
select ok(
  exists (
    select 1 from public.get_available_slots(
      '55555555-5555-5555-5555-555555555555',
      ((select start_at from _t) at time zone 'Africa/Johannesburg')::date,
      ((select start_at from _t) at time zone 'Africa/Johannesburg')::date,
      '33333333-3333-3333-3333-333333333333',
      60
    )
    where starts_at = (select start_at from _t)
  ),
  'the freed slot is available again after the hold expires');

select * from finish();
rollback;
