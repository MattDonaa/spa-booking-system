-- ============================================================================
-- Tests: Concurrency / double-booking backstop
-- Run with: supabase test db
--
-- The booking engine serialises attempts with advisory locks, but the ultimate
-- guarantee is the GiST exclusion constraint on bookings. This test proves the
-- constraint rejects a directly-inserted overlapping booking, and that the
-- engine surfaces a clean CONFLICT for an already-taken slot.
-- ============================================================================
begin;
select plan(2);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'cc@test.dev',
   '{"role":"client","full_name":"Conc Client"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'cp@test.dev',
   '{"role":"practitioner","full_name":"Conc Prac"}'::jsonb);
insert into public.practitioners (id, profile_id)
  values ('33333333-3333-3333-3333-333333333333',
          '22222222-2222-2222-2222-222222222222');
insert into public.rooms (id, name)
  values ('44444444-4444-4444-4444-444444444444', 'Room');
insert into public.services (id, name, slug, duration_minutes, price_cents,
    requires_room)
  values ('55555555-5555-5555-5555-555555555555', 'Svc', 'svc', 60, 100000, true);
insert into public.practitioner_services (practitioner_id, service_id)
  values ('33333333-3333-3333-3333-333333333333',
          '55555555-5555-5555-5555-555555555555');
insert into public.practitioner_availability (practitioner_id, day_of_week,
    start_time, end_time)
  select '33333333-3333-3333-3333-333333333333', d, '00:00', '23:59'
  from generate_series(0, 6) as d;

-- Establish the first booking at a fixed slot.
create temporary table _slot (t timestamptz) on commit drop;
insert into _slot values (date_trunc('hour', now()) + interval '2 days' + interval '10 hours');

select public.create_booking(
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  (select t from _slot),
  '11111111-1111-1111-1111-111111111111');

-- 1. A directly-inserted overlapping booking is rejected by the exclusion
--    constraint (SQLSTATE 23P01).
select throws_ok(
  $$
    insert into public.bookings (client_id, practitioner_id, service_id, room_id,
      status, starts_at, ends_at, buffer_starts_at, buffer_ends_at,
      price_cents, deposit_cents, currency)
    select c.id, '33333333-3333-3333-3333-333333333333',
      '55555555-5555-5555-5555-555555555555',
      '44444444-4444-4444-4444-444444444444', 'confirmed',
      (select t from _slot), (select t from _slot) + interval '1 hour',
      (select t from _slot), (select t from _slot) + interval '1 hour',
      100000, 20000, 'ZAR'
    from public.clients c
    where c.profile_id = '11111111-1111-1111-1111-111111111111'
  $$,
  '23P01', null,
  'overlapping booking is rejected by the exclusion constraint');

-- 2. The engine surfaces a clean CONFLICT for the taken slot.
select is(
  (public.create_booking(
    '55555555-5555-5555-5555-555555555555',
    '33333333-3333-3333-3333-333333333333',
    (select t from _slot),
    '11111111-1111-1111-1111-111111111111') #>> '{error,code}'),
  'CONFLICT', 'engine returns CONFLICT for an already-taken slot');

select * from finish();
rollback;
