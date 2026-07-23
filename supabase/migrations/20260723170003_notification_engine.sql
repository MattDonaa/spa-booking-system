-- ============================================================================
-- Migration: Notification Engine (queue RPCs + reminder scheduler)
-- ----------------------------------------------------------------------------
-- The notification_queue holds outbound messages; a worker (Edge Function)
-- claims due messages, delivers them, and reports the outcome. Failed deliveries
-- are retried with exponential backoff up to max_attempts. Each attempt is
-- logged to the notifications delivery log.
--
--   * enqueue_notification      — add a message (deduplicated).
--   * claim_due_notifications   — worker claims due messages (skip locked).
--   * mark_notification_sent    — success + delivery log.
--   * mark_notification_failed  — failure: retry with backoff or give up.
--   * schedule_booking_notifications — confirmation + appointment reminder.
--   * enqueue_due_reminders     — cron sweep: reminders, review & rebooking.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- enqueue_notification
-- ----------------------------------------------------------------------------
create or replace function public.enqueue_notification(
  p_notification_type public.notification_type,
  p_channel public.notification_channel,
  p_recipient_profile_id uuid,
  p_payload jsonb default '{}'::jsonb,
  p_booking_id uuid default null,
  p_scheduled_for timestamptz default now(),
  p_dedupe_key text default null,
  p_max_attempts integer default 5
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_id uuid;
begin
  if not private.is_service_role() and not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Not permitted to enqueue notifications.');
  end if;

  insert into public.notification_queue (
    recipient_profile_id, booking_id, channel, notification_type,
    payload, status, scheduled_for, max_attempts, dedupe_key
  )
  values (
    p_recipient_profile_id, p_booking_id, p_channel, p_notification_type,
    p_payload, 'queued', p_scheduled_for, p_max_attempts, p_dedupe_key
  )
  on conflict (dedupe_key) where (dedupe_key is not null and deleted_at is null)
  do nothing
  returning id into v_id;

  return private.rpc_ok(jsonb_build_object(
    'notification_id', v_id, 'deduplicated', v_id is null));
end;
$$;

comment on function public.enqueue_notification is
  'Adds an outbound notification to the queue (deduplicated by dedupe_key).';

-- ----------------------------------------------------------------------------
-- claim_due_notifications: atomically claim due, retriable messages. Service
-- role only (the dispatch worker).
-- ----------------------------------------------------------------------------
create or replace function public.claim_due_notifications(
  p_limit integer default 20
)
returns setof public.notification_queue
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not private.is_service_role() then
    raise exception 'Service role required' using errcode = 'insufficient_privilege';
  end if;

  return query
  update public.notification_queue q
  set status = 'processing', attempts = attempts + 1, updated_at = now()
  where q.id in (
    select id from public.notification_queue
    where status = 'queued'
      and deleted_at is null
      and scheduled_for <= now()
      and (next_attempt_at is null or next_attempt_at <= now())
    order by scheduled_for
    for update skip locked
    limit greatest(p_limit, 1)
  )
  returning q.*;
end;
$$;

comment on function public.claim_due_notifications is
  'Claims up to N due notifications for delivery (FOR UPDATE SKIP LOCKED).';

-- ----------------------------------------------------------------------------
-- mark_notification_sent
-- ----------------------------------------------------------------------------
create or replace function public.mark_notification_sent(
  p_notification_id uuid,
  p_provider text default null,
  p_provider_message_id text default null,
  p_response jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_channel public.notification_channel;
begin
  if not private.is_service_role() then
    return private.rpc_err('FORBIDDEN', 'Service role required.');
  end if;

  update public.notification_queue
  set status = 'sent', sent_at = now(), last_error = null
  where id = p_notification_id
  returning channel into v_channel;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Notification not found.');
  end if;

  insert into public.notifications (
    queue_id, channel, status, provider, provider_message_id, response
  )
  values (
    p_notification_id, v_channel, 'sent', p_provider, p_provider_message_id, p_response
  );

  return private.rpc_ok(jsonb_build_object('notification_id', p_notification_id));
end;
$$;

comment on function public.mark_notification_sent is
  'Marks a notification delivered and writes a delivery-log entry.';

-- ----------------------------------------------------------------------------
-- mark_notification_failed: retry with exponential backoff, or give up when
-- max_attempts is reached.
-- ----------------------------------------------------------------------------
create or replace function public.mark_notification_failed(
  p_notification_id uuid,
  p_error text,
  p_provider text default null,
  p_response jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_q public.notification_queue;
  v_terminal boolean;
  v_backoff interval;
begin
  if not private.is_service_role() then
    return private.rpc_err('FORBIDDEN', 'Service role required.');
  end if;

  select * into v_q
  from public.notification_queue where id = p_notification_id for update;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Notification not found.');
  end if;

  v_terminal := v_q.attempts >= v_q.max_attempts;
  -- Exponential backoff: 2^attempts minutes, capped at ~1 hour.
  v_backoff := make_interval(mins => least(power(2, v_q.attempts)::int, 60));

  update public.notification_queue
  set status = case when v_terminal then 'failed' else 'queued' end,
      last_error = p_error,
      next_attempt_at = case when v_terminal then null else now() + v_backoff end
  where id = p_notification_id;

  insert into public.notifications (
    queue_id, channel, status, provider, response, error
  )
  values (
    p_notification_id, v_q.channel,
    case when v_terminal then 'failed' else 'queued' end,
    p_provider, p_response, p_error
  );

  return private.rpc_ok(jsonb_build_object(
    'notification_id', p_notification_id,
    'terminal', v_terminal,
    'retry_at', case when v_terminal then null else now() + v_backoff end));
end;
$$;

comment on function public.mark_notification_failed is
  'Records a failed delivery; retries with backoff or fails terminally.';

-- ----------------------------------------------------------------------------
-- Internal: build a notification payload from a booking.
-- ----------------------------------------------------------------------------
create or replace function private.booking_notification_payload(p_booking_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'client_name', p.full_name,
    'service_name', s.name,
    'starts_at', to_char(b.starts_at, 'YYYY-MM-DD HH24:MI'),
    'amount', to_char(b.deposit_cents / 100.0, 'FM999999990.00'),
    'business_name', coalesce(bs.business_name, 'Serenity Day Spa'),
    'recipient_email', p.email,
    'recipient_phone', p.phone,
    'booking_url', coalesce(nullif(current_setting('app.base_url', true), ''),
                            'http://localhost:3000') || '/bookings/' || b.id
  )
  from public.bookings b
  join public.clients c on c.id = b.client_id
  join public.profiles p on p.id = c.profile_id
  join public.services s on s.id = b.service_id
  cross join lateral (
    select business_name from public.business_settings limit 1
  ) bs
  where b.id = p_booking_id;
$$;

-- ----------------------------------------------------------------------------
-- Internal: enqueue a booking notification on all suitable channels for the
-- recipient (email always; WhatsApp/SMS when a phone number is on file).
-- ----------------------------------------------------------------------------
create or replace function private.enqueue_booking_channels(
  p_booking_id uuid,
  p_type public.notification_type,
  p_dedupe_prefix text,
  p_scheduled_for timestamptz
)
returns integer
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_payload jsonb := private.booking_notification_payload(p_booking_id);
  v_profile uuid;
  v_phone text;
  v_count integer := 0;
begin
  if v_payload is null then
    return 0;
  end if;

  select p.id, p.phone into v_profile, v_phone
  from public.bookings b
  join public.clients c on c.id = b.client_id
  join public.profiles p on p.id = c.profile_id
  where b.id = p_booking_id;

  perform public.enqueue_notification(
    p_type, 'email', v_profile, v_payload, p_booking_id, p_scheduled_for,
    p_dedupe_prefix || '_email_' || p_booking_id::text);
  v_count := v_count + 1;

  if v_phone is not null and length(btrim(v_phone)) > 0 then
    perform public.enqueue_notification(
      p_type, 'whatsapp', v_profile, v_payload, p_booking_id, p_scheduled_for,
      p_dedupe_prefix || '_whatsapp_' || p_booking_id::text);
    v_count := v_count + 1;
  end if;

  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- schedule_booking_notifications: confirmation now + appointment reminder 24h
-- before the appointment.
-- ----------------------------------------------------------------------------
create or replace function public.schedule_booking_notifications(
  p_booking_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_booking public.bookings;
  v_reminder_at timestamptz;
begin
  if not private.is_service_role() and not private.is_staff() then
    return private.rpc_err('FORBIDDEN', 'Not permitted.');
  end if;

  select * into v_booking
  from public.bookings where id = p_booking_id and deleted_at is null;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  perform private.enqueue_booking_channels(
    p_booking_id, 'booking_confirmation', 'confirm', now());

  v_reminder_at := v_booking.starts_at - interval '24 hours';
  if v_reminder_at > now() then
    perform private.enqueue_booking_channels(
      p_booking_id, 'appointment_reminder', 'reminder', v_reminder_at);
  end if;

  return private.rpc_ok(jsonb_build_object('booking_id', p_booking_id));
end;
$$;

comment on function public.schedule_booking_notifications is
  'Enqueues the confirmation and the 24h appointment reminder for a booking.';

-- ----------------------------------------------------------------------------
-- enqueue_due_reminders: periodic sweep (pg_cron). Enqueues appointment
-- reminders, post-visit review requests, and rebooking reminders. Idempotent
-- via dedupe keys. Service role only.
-- ----------------------------------------------------------------------------
create or replace function public.enqueue_due_reminders()
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_row record;
  v_reminders integer := 0;
  v_reviews integer := 0;
  v_rebookings integer := 0;
begin
  if not private.is_service_role() then
    raise exception 'Service role required' using errcode = 'insufficient_privilege';
  end if;

  -- Appointment reminders: confirmed bookings starting in the next 24 hours.
  for v_row in
    select id from public.bookings
    where status = 'confirmed' and deleted_at is null
      and starts_at between now() and now() + interval '24 hours'
  loop
    v_reminders := v_reminders + private.enqueue_booking_channels(
      v_row.id, 'appointment_reminder', 'reminder', now());
  end loop;

  -- Review requests: completed within the last 2 days.
  for v_row in
    select id from public.bookings
    where status = 'completed' and deleted_at is null
      and completed_at between now() - interval '2 days' and now()
  loop
    v_reviews := v_reviews + private.enqueue_booking_channels(
      v_row.id, 'review_request', 'review', now());
  end loop;

  -- Rebooking reminders: completed ~6 weeks ago.
  for v_row in
    select id from public.bookings
    where status = 'completed' and deleted_at is null
      and completed_at between now() - interval '43 days'
                          and now() - interval '42 days'
  loop
    v_rebookings := v_rebookings + private.enqueue_booking_channels(
      v_row.id, 'rebooking_reminder', 'rebook', now());
  end loop;

  return private.rpc_ok(jsonb_build_object(
    'appointment_reminders', v_reminders,
    'review_requests', v_reviews,
    'rebooking_reminders', v_rebookings));
end;
$$;

comment on function public.enqueue_due_reminders is
  'Periodic sweep enqueuing appointment reminders, review and rebooking messages.';

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
grant execute on function
  public.enqueue_notification(
    public.notification_type, public.notification_channel, uuid, jsonb, uuid,
    timestamptz, text, integer),
  public.schedule_booking_notifications(uuid)
to authenticated, service_role;

grant execute on function
  public.claim_due_notifications(integer),
  public.mark_notification_sent(uuid, text, text, jsonb),
  public.mark_notification_failed(uuid, text, text, jsonb),
  public.enqueue_due_reminders()
to service_role;
