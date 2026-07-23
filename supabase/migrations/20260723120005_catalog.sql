-- ============================================================================
-- Migration: Catalog (service categories, services, rooms,
--            practitioner_services, business settings)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- service_categories
-- ----------------------------------------------------------------------------
create table public.service_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  slug text not null,
  description text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint service_categories_name_not_blank_chk
    check (length(btrim(name)) > 0)
);

create unique index service_categories_slug_unique_idx
  on public.service_categories (slug)
  where deleted_at is null;

comment on table public.service_categories is 'Groupings for services.';

-- ----------------------------------------------------------------------------
-- rooms
-- ----------------------------------------------------------------------------
create table public.rooms (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  description text,
  capacity integer not null default 1,
  features text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint rooms_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint rooms_capacity_positive_chk check (capacity > 0)
);

create index rooms_active_idx on public.rooms (is_active) where deleted_at is null;

comment on table public.rooms is 'Physical treatment rooms / resources.';

-- ----------------------------------------------------------------------------
-- services
-- ----------------------------------------------------------------------------
create table public.services (
  id uuid primary key default extensions.gen_random_uuid(),
  category_id uuid references public.service_categories (id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  duration_minutes integer not null,
  buffer_before_minutes integer not null default 0,
  buffer_after_minutes integer not null default 0,
  price_cents integer not null,
  deposit_cents integer not null default 0,
  currency char(3) not null default 'ZAR',
  requires_room boolean not null default true,
  requires_intake boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint services_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint services_duration_positive_chk check (duration_minutes > 0),
  constraint services_buffers_nonnegative_chk
    check (buffer_before_minutes >= 0 and buffer_after_minutes >= 0),
  constraint services_price_nonnegative_chk check (price_cents >= 0),
  constraint services_deposit_range_chk
    check (deposit_cents >= 0 and deposit_cents <= price_cents),
  constraint services_currency_format_chk check (currency ~ '^[A-Z]{3}$')
);

create unique index services_slug_unique_idx
  on public.services (slug)
  where deleted_at is null;

create index services_category_idx on public.services (category_id);
create index services_active_idx on public.services (is_active) where deleted_at is null;

comment on table public.services is
  'Bookable services. Monetary amounts are stored in integer minor units (cents).';

-- ----------------------------------------------------------------------------
-- practitioner_services: which practitioners offer which services, with
-- optional per-practitioner overrides for price and duration.
-- ----------------------------------------------------------------------------
create table public.practitioner_services (
  id uuid primary key default extensions.gen_random_uuid(),
  practitioner_id uuid not null references public.practitioners (id) on delete cascade,
  service_id uuid not null references public.services (id) on delete cascade,
  price_cents_override integer,
  duration_minutes_override integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint practitioner_services_price_override_chk
    check (price_cents_override is null or price_cents_override >= 0),
  constraint practitioner_services_duration_override_chk
    check (duration_minutes_override is null or duration_minutes_override > 0)
);

create unique index practitioner_services_unique_idx
  on public.practitioner_services (practitioner_id, service_id)
  where deleted_at is null;

create index practitioner_services_service_idx
  on public.practitioner_services (service_id);

comment on table public.practitioner_services is
  'Join table linking practitioners to the services they provide.';

-- ----------------------------------------------------------------------------
-- business_settings: single-row global configuration. The singleton guard
-- ensures at most one active row.
-- ----------------------------------------------------------------------------
create table public.business_settings (
  id uuid primary key default extensions.gen_random_uuid(),
  singleton boolean not null default true,
  business_name text not null default 'Serenity Day Spa',
  timezone text not null default 'Africa/Johannesburg',
  currency char(3) not null default 'ZAR',
  default_deposit_percentage numeric(5, 2) not null default 20.00,
  hold_duration_minutes integer not null default 15,
  min_booking_lead_minutes integer not null default 120,
  max_booking_lead_days integer not null default 90,
  cancellation_window_hours integer not null default 24,
  contact_email text,
  contact_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint business_settings_singleton_chk check (singleton = true),
  constraint business_settings_deposit_pct_chk
    check (default_deposit_percentage >= 0 and default_deposit_percentage <= 100),
  constraint business_settings_hold_positive_chk check (hold_duration_minutes > 0),
  constraint business_settings_currency_format_chk check (currency ~ '^[A-Z]{3}$')
);

-- Enforces at most one settings row.
create unique index business_settings_singleton_idx
  on public.business_settings (singleton);

comment on table public.business_settings is
  'Global business configuration. Constrained to a single row via the singleton guard.';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.service_categories
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.rooms
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.services
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.practitioner_services
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.business_settings
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.service_categories
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.rooms
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.services
  for each row execute function public.prevent_hard_delete();

create trigger record_audit
  after insert or update or delete on public.services
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.rooms
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.business_settings
  for each row execute function public.record_audit();
