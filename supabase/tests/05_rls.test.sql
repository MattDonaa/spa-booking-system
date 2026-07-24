-- ============================================================================
-- Tests: Row Level Security isolation between clients
-- Run with: supabase test db
--
-- Verifies that, under the `authenticated` role with a client's JWT, a client
-- sees only their own bookings — never another client's.
-- ============================================================================
begin;
select plan(3);

-- Two clients and a practitioner (profiles + client rows via the signup trigger).
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a@test.dev',
   '{"role":"client","full_name":"Client A"}'::jsonb),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@test.dev',
   '{"role":"client","full_name":"Client B"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'rp@test.dev',
   '{"role":"practitioner","full_name":"RLS Prac"}'::jsonb);
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

-- One booking for each client (created server-side, RLS-exempt).
insert into public.bookings (client_id, practitioner_id, service_id, room_id,
    status, starts_at, ends_at, buffer_starts_at, buffer_ends_at,
    price_cents, deposit_cents, currency)
select c.id, '33333333-3333-3333-3333-333333333333',
  '55555555-5555-5555-5555-555555555555',
  '44444444-4444-4444-4444-444444444444', 'confirmed',
  now() + (n || ' days')::interval, now() + (n || ' days')::interval + interval '1 hour',
  now() + (n || ' days')::interval, now() + (n || ' days')::interval + interval '1 hour',
  100000, 20000, 'ZAR'
from (values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 3),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, 5)
) as v(profile_id, n)
join public.clients c on c.profile_id = v.profile_id;

-- Act as Client A.
set local role authenticated;
set local request.jwt.claims to
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select is(
  (select count(*)::int from public.bookings), 1,
  'client A sees exactly one booking (their own)');

select is(
  (select count(*)::int from public.bookings b
   join public.clients c on c.id = b.client_id
   where c.profile_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0, 'client A cannot see client B''s booking');

-- Act as Client B.
set local request.jwt.claims to
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

select is(
  (select count(*)::int from public.bookings), 1,
  'client B sees exactly one booking (their own)');

reset role;
select * from finish();
rollback;
