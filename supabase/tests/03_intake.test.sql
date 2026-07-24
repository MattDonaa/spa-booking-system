-- ============================================================================
-- Tests: Intake engine (instantiate / autosave / validation / submit)
-- Run with: supabase test db
-- ============================================================================
begin;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ic@test.dev',
   '{"role":"client","full_name":"Intake Client"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'ip@test.dev',
   '{"role":"practitioner","full_name":"Intake Prac"}'::jsonb);
insert into public.practitioners (id, profile_id)
  values ('33333333-3333-3333-3333-333333333333',
          '22222222-2222-2222-2222-222222222222');
insert into public.rooms (id, name)
  values ('44444444-4444-4444-4444-444444444444', 'Room');
insert into public.services (id, name, slug, duration_minutes, price_cents,
    requires_room, requires_intake)
  values ('55555555-5555-5555-5555-555555555555', 'Svc', 'svc', 60, 100000,
          true, true);
insert into public.practitioner_services (practitioner_id, service_id)
  values ('33333333-3333-3333-3333-333333333333',
          '55555555-5555-5555-5555-555555555555');
insert into public.practitioner_availability (practitioner_id, day_of_week,
    start_time, end_time)
  select '33333333-3333-3333-3333-333333333333', d, '00:00', '23:59'
  from generate_series(0, 6) as d;

-- A non-medical template with one required field (avoids the encryption key).
insert into public.form_templates (name, slug, form_type, version, schema,
    is_medical, is_active, published_at)
values ('Intake', 'intake', 'general_intake', 1,
        '[{"key":"q1","label":"Question 1","type":"text","required":true}]'::jsonb,
        false, true, now());

create temporary table _b (id uuid) on commit drop;
insert into _b
select (public.create_booking(
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  date_trunc('hour', now()) + interval '2 days',
  '11111111-1111-1111-1111-111111111111') -> 'data' ->> 'booking_id')::uuid;

-- 1. Instantiate the intake forms for the booking.
select is(
  (public.instantiate_intake_forms((select id from _b)) ->> 'ok'),
  'true', 'instantiate_intake_forms succeeds');

create temporary table _f (id uuid) on commit drop;
insert into _f
select id from public.intake_forms where booking_id = (select id from _b) limit 1;

-- 2. Autosave a partial (empty) response.
select is(
  (public.save_intake_response((select id from _f), '{"q1":""}'::jsonb) ->> 'ok'),
  'true', 'autosave succeeds without validation');

-- 3. Submitting with a missing required field is rejected.
select is(
  (public.submit_intake_form((select id from _f), '{"q1":""}'::jsonb)
     #>> '{error,code}'),
  'VALIDATION', 'submit rejects a missing required field');

-- 4. Submitting a valid response completes the form.
select is(
  (public.submit_intake_form((select id from _f), '{"q1":"answer"}'::jsonb) ->> 'ok'),
  'true', 'submit succeeds when valid');
select is(
  (select status::text from public.intake_forms where id = (select id from _f)),
  'completed', 'form is marked completed');
select ok(
  (select submitted_at from public.intake_forms where id = (select id from _f))
    is not null,
  'submitted_at is set');

select * from finish();
rollback;
