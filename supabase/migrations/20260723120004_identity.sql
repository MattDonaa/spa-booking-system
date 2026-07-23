-- ============================================================================
-- Migration: Identity (profiles, clients, practitioners)
-- ----------------------------------------------------------------------------
-- profiles is the base identity, 1:1 with Supabase auth.users. Role-specific
-- data lives in the clients and practitioners tables.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'client',
  email text not null,
  full_name text not null,
  phone text,
  avatar_url text,
  locale text not null default 'en-ZA',
  timezone text not null default 'Africa/Johannesburg',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint profiles_email_format_chk
    check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  constraint profiles_full_name_not_blank_chk
    check (length(btrim(full_name)) > 0)
);

-- Case-insensitive uniqueness for active profiles.
create unique index profiles_email_unique_idx
  on public.profiles (lower(email))
  where deleted_at is null;

create index profiles_role_idx on public.profiles (role) where deleted_at is null;

comment on table public.profiles is
  'Base user identity, 1:1 with auth.users. Holds shared account fields and role.';

-- ----------------------------------------------------------------------------
-- clients
-- ----------------------------------------------------------------------------
create table public.clients (
  id uuid primary key default extensions.gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  date_of_birth date,
  emergency_contact_name text,
  emergency_contact_phone text,
  marketing_opt_in boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint clients_dob_not_future_chk
    check (date_of_birth is null or date_of_birth <= current_date)
);

create unique index clients_profile_unique_idx
  on public.clients (profile_id)
  where deleted_at is null;

comment on table public.clients is
  'Client-specific profile data. One active row per profile.';

-- ----------------------------------------------------------------------------
-- practitioners
-- ----------------------------------------------------------------------------
create table public.practitioners (
  id uuid primary key default extensions.gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  title text,
  bio text,
  specialties text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index practitioners_profile_unique_idx
  on public.practitioners (profile_id)
  where deleted_at is null;

create index practitioners_active_idx
  on public.practitioners (is_active)
  where deleted_at is null;

comment on table public.practitioners is
  'Practitioner-specific profile data. One active row per profile.';

-- ----------------------------------------------------------------------------
-- Triggers: updated_at, block hard delete, audit
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.clients
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.practitioners
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.clients
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.practitioners
  for each row execute function public.prevent_hard_delete();

create trigger record_audit
  after insert or update or delete on public.profiles
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.clients
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.practitioners
  for each row execute function public.record_audit();
