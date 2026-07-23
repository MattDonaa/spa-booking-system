-- ============================================================================
-- Migration: Bookings & Booking Events
-- ----------------------------------------------------------------------------
-- The bookings table is the heart of the system. Double bookings are made
-- impossible at the database level via GiST exclusion constraints over the
-- buffered time range — the last line of defence behind the transactional
-- booking engine (Milestone 4). Every state change is recorded in the
-- append-only booking_events log by trigger.
-- ============================================================================

-- The GiST exclusion constraints below rely on the default uuid operator class
-- provided by btree_gist, which lives in the `extensions` schema. Ensure it is
-- on the search_path while this migration runs.
set search_path = public, extensions;

-- ----------------------------------------------------------------------------
-- bookings
-- ----------------------------------------------------------------------------
create table public.bookings (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  practitioner_id uuid not null references public.practitioners (id) on delete restrict,
  service_id uuid not null references public.services (id) on delete restrict,
  room_id uuid references public.rooms (id) on delete restrict,
  status public.booking_status not null default 'pending_hold',
  -- Actual appointment window.
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- Appointment window extended by service buffers; used for overlap checks.
  buffer_starts_at timestamptz not null,
  buffer_ends_at timestamptz not null,
  -- Monetary snapshot taken at booking time (minor units / cents).
  price_cents integer not null,
  deposit_cents integer not null default 0,
  currency char(3) not null default 'ZAR',
  -- When a pending_hold expires and the slot is released.
  hold_expires_at timestamptz,
  notes text,
  cancellation_reason text,
  cancelled_at timestamptz,
  completed_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint bookings_time_order_chk check (starts_at < ends_at),
  constraint bookings_buffer_envelope_chk
    check (buffer_starts_at <= starts_at and ends_at <= buffer_ends_at),
  constraint bookings_price_nonnegative_chk check (price_cents >= 0),
  constraint bookings_deposit_range_chk
    check (deposit_cents >= 0 and deposit_cents <= price_cents),
  constraint bookings_currency_format_chk check (currency ~ '^[A-Z]{3}$'),
  -- No two active bookings for the same practitioner may overlap (buffers
  -- included). Terminal/released statuses are excluded so freed slots rebook.
  constraint bookings_no_practitioner_overlap
    exclude using gist (
      practitioner_id with =,
      tstzrange(buffer_starts_at, buffer_ends_at, '[)') with &&
    )
    where (
      deleted_at is null
      and status in (
        'pending_hold', 'pending_payment', 'pending_intake',
        'confirmed', 'checked_in', 'in_progress', 'completed'
      )
    ),
  -- The same rule for rooms, where a room is assigned.
  constraint bookings_no_room_overlap
    exclude using gist (
      room_id with =,
      tstzrange(buffer_starts_at, buffer_ends_at, '[)') with &&
    )
    where (
      deleted_at is null
      and room_id is not null
      and status in (
        'pending_hold', 'pending_payment', 'pending_intake',
        'confirmed', 'checked_in', 'in_progress', 'completed'
      )
    )
);

create index bookings_client_idx on public.bookings (client_id) where deleted_at is null;
create index bookings_practitioner_time_idx
  on public.bookings (practitioner_id, starts_at) where deleted_at is null;
create index bookings_room_time_idx
  on public.bookings (room_id, starts_at) where deleted_at is null;
create index bookings_service_idx on public.bookings (service_id);
create index bookings_status_idx on public.bookings (status) where deleted_at is null;
-- Supports the expiry sweep (pg_cron in a later milestone) over pending holds.
create index bookings_hold_expiry_idx
  on public.bookings (hold_expires_at)
  where status in ('pending_hold', 'pending_payment') and deleted_at is null;

comment on table public.bookings is
  'Appointments. Overlaps are prevented by GiST exclusion constraints on the buffered range.';

-- ----------------------------------------------------------------------------
-- booking_events: append-only lifecycle log. One row per creation and per
-- status change (written by the record_booking_event trigger below).
-- ----------------------------------------------------------------------------
create table public.booking_events (
  id uuid primary key default extensions.gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  event_type public.booking_event_type not null,
  from_status public.booking_status,
  to_status public.booking_status,
  actor_profile_id uuid references public.profiles (id) on delete set null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index booking_events_booking_idx
  on public.booking_events (booking_id, created_at);

comment on table public.booking_events is
  'Append-only log of booking lifecycle events (creation and status changes).';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.bookings
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.bookings
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.booking_events
  for each row execute function public.prevent_hard_delete();

-- Records booking_events on creation and every status change.
create trigger record_booking_event
  after insert or update on public.bookings
  for each row execute function public.record_booking_event();

create trigger record_audit
  after insert or update or delete on public.bookings
  for each row execute function public.record_audit();
