-- ============================================================================
-- Tests: Notification engine (enqueue dedupe / claim / retry backoff)
-- Run with: supabase test db
-- ============================================================================
begin;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'nc@test.dev',
   '{"role":"client","full_name":"Notify Client"}'::jsonb);

-- 1. Enqueue a notification.
select is(
  (public.enqueue_notification(
     'booking_confirmation', 'email', '11111111-1111-1111-1111-111111111111',
     '{}'::jsonb, null, now(), 'dedupe-1') ->> 'ok'),
  'true', 'enqueue_notification succeeds');

-- 2. Enqueuing the same dedupe key is a no-op.
select is(
  (public.enqueue_notification(
     'booking_confirmation', 'email', '11111111-1111-1111-1111-111111111111',
     '{}'::jsonb, null, now(), 'dedupe-1') #>> '{data,deduplicated}'),
  'true', 'enqueue is deduplicated by dedupe_key');

-- 3. The worker claims the due notification.
create temporary table _n (id uuid) on commit drop;
insert into _n select id from public.claim_due_notifications(10) limit 1;
select ok((select id from _n) is not null, 'a due notification is claimed');

-- 4. Claiming moves it to processing.
select is(
  (select status::text from public.notification_queue where id = (select id from _n)),
  'processing', 'claimed notification is processing');

-- 5. A first failure is retriable (not terminal).
select is(
  (public.mark_notification_failed((select id from _n), 'send error')
     #>> '{data,terminal}'),
  'false', 'first failure is retriable');

-- 6. It is requeued for a later retry.
select is(
  (select status::text from public.notification_queue where id = (select id from _n)),
  'queued', 'failed notification is requeued for retry');

select * from finish();
rollback;
