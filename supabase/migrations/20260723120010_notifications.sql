-- ============================================================================
-- Migration: Notifications & Notification Queue
-- ----------------------------------------------------------------------------
-- notification_queue holds outbound messages to be delivered (with retry).
-- notifications logs each delivery attempt against a queue entry. This split
-- keeps scheduling/retry state separate from the immutable delivery history,
-- so every notification is retryable and auditable.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- notification_queue: scheduled outbound messages with retry bookkeeping.
-- ----------------------------------------------------------------------------
create table public.notification_queue (
  id uuid primary key default extensions.gen_random_uuid(),
  recipient_profile_id uuid references public.profiles (id) on delete set null,
  booking_id uuid references public.bookings (id) on delete cascade,
  channel public.notification_channel not null,
  notification_type public.notification_type not null,
  -- Rendered/renderable message data (recipient address, template vars, body).
  payload jsonb not null default '{}',
  status public.notification_status not null default 'queued',
  scheduled_for timestamptz not null default now(),
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  next_attempt_at timestamptz,
  last_error text,
  sent_at timestamptz,
  -- Guards against enqueuing duplicate messages (e.g. one reminder per booking).
  dedupe_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint notification_queue_attempts_chk
    check (attempts >= 0 and attempts <= max_attempts),
  constraint notification_queue_max_attempts_chk check (max_attempts > 0)
);

create unique index notification_queue_dedupe_unique_idx
  on public.notification_queue (dedupe_key)
  where dedupe_key is not null and deleted_at is null;

-- Supports the delivery worker claiming due, non-terminal messages.
create index notification_queue_due_idx
  on public.notification_queue (status, scheduled_for)
  where status in ('queued', 'failed') and deleted_at is null;

create index notification_queue_booking_idx
  on public.notification_queue (booking_id);

comment on table public.notification_queue is
  'Outbound notifications pending delivery, with scheduling and retry state.';

-- ----------------------------------------------------------------------------
-- notifications: immutable per-attempt delivery log.
-- ----------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  queue_id uuid not null references public.notification_queue (id) on delete cascade,
  channel public.notification_channel not null,
  status public.notification_status not null,
  provider text,
  provider_message_id text,
  -- Provider response for this delivery attempt.
  response jsonb,
  error text,
  attempted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index notifications_queue_idx
  on public.notifications (queue_id, attempted_at);

comment on table public.notifications is
  'Immutable log of individual notification delivery attempts.';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.notification_queue
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.notifications
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.notification_queue
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.notifications
  for each row execute function public.prevent_hard_delete();
