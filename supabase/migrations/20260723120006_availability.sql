-- ============================================================================
-- Migration: Availability (recurring schedules, blocks / time off)
-- ----------------------------------------------------------------------------
-- Defines when practitioners are bookable (recurring weekly schedule) and when
-- they or rooms are explicitly unavailable (blocks). The booking engine
-- (Milestone 4) reads these to compute open slots.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- practitioner_availability: recurring weekly working hours.
-- day_of_week uses PostgreSQL's convention (0 = Sunday ... 6 = Saturday),
-- matching extract(dow from ...).
-- ----------------------------------------------------------------------------
create table public.practitioner_availability (
  id uuid primary key default extensions.gen_random_uuid(),
  practitioner_id uuid not null references public.practitioners (id) on delete cascade,
  day_of_week smallint not null,
  start_time time not null,
  end_time time not null,
  effective_from date,
  effective_to date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint practitioner_availability_dow_chk
    check (day_of_week between 0 and 6),
  constraint practitioner_availability_time_order_chk
    check (start_time < end_time),
  constraint practitioner_availability_effective_order_chk
    check (
      effective_from is null
      or effective_to is null
      or effective_from <= effective_to
    )
);

create index practitioner_availability_lookup_idx
  on public.practitioner_availability (practitioner_id, day_of_week)
  where deleted_at is null;

comment on table public.practitioner_availability is
  'Recurring weekly working hours per practitioner (0 = Sunday .. 6 = Saturday).';

-- ----------------------------------------------------------------------------
-- availability_blocks: explicit non-bookable time. Scopes to a practitioner,
-- a room, or (when both are null) the whole business (e.g. public holiday).
-- ----------------------------------------------------------------------------
create table public.availability_blocks (
  id uuid primary key default extensions.gen_random_uuid(),
  practitioner_id uuid references public.practitioners (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete cascade,
  block_type public.availability_block_type not null default 'time_off',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint availability_blocks_time_order_chk check (starts_at < ends_at)
);

create index availability_blocks_practitioner_idx
  on public.availability_blocks (practitioner_id, starts_at, ends_at)
  where deleted_at is null;

create index availability_blocks_room_idx
  on public.availability_blocks (room_id, starts_at, ends_at)
  where deleted_at is null;

comment on table public.availability_blocks is
  'Explicit non-bookable periods for a practitioner, room, or the whole business.';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.practitioner_availability
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.availability_blocks
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.practitioner_availability
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.availability_blocks
  for each row execute function public.prevent_hard_delete();
