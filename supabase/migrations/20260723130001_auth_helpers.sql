-- ============================================================================
-- Migration: Authentication Helpers & JWT Handling
-- ----------------------------------------------------------------------------
-- Security-definer helper functions used by Row Level Security policies, plus
-- the trigger that provisions a profile for every new auth user, a guard that
-- restricts role changes to admins, and the custom access-token hook that adds
-- the application role to the JWT.
--
-- Helpers live in the `private` schema, which is NOT exposed through the API
-- (config.toml api.schemas = ["public"]). They are SECURITY DEFINER and owned
-- by the migration role, so they bypass RLS internally — this is what lets a
-- policy on `profiles` consult `profiles` without infinite recursion.
-- ============================================================================

create schema if not exists private;

-- Lock the schema down: nothing is callable/visible to API roles by default.
revoke all on schema private from anon, authenticated;
grant usage on schema private to anon, authenticated;

-- ----------------------------------------------------------------------------
-- private.current_app_role: the current user's application role, or NULL.
-- ----------------------------------------------------------------------------
create or replace function private.current_app_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.deleted_at is null;
$$;

-- ----------------------------------------------------------------------------
-- Role predicates. Each is SECURITY DEFINER and RLS-safe.
-- ----------------------------------------------------------------------------
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and deleted_at is null
  );
$$;

create or replace function private.is_practitioner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'practitioner' and deleted_at is null
  );
$$;

-- Staff = practitioner or admin.
create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('practitioner', 'admin')
      and deleted_at is null
  );
$$;

-- ----------------------------------------------------------------------------
-- Resolve the current user's client / practitioner row id (NULL if none).
-- ----------------------------------------------------------------------------
create or replace function private.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.clients c
  where c.profile_id = auth.uid() and c.deleted_at is null;
$$;

create or replace function private.current_practitioner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select pr.id
  from public.practitioners pr
  where pr.profile_id = auth.uid() and pr.deleted_at is null;
$$;

grant execute on function
  private.current_app_role(),
  private.is_admin(),
  private.is_practitioner(),
  private.is_staff(),
  private.current_client_id(),
  private.current_practitioner_id()
to anon, authenticated;

-- ----------------------------------------------------------------------------
-- handle_new_user: provision a profile (and a client row for self-service
-- signups) whenever an auth user is created. Role and name are read from the
-- signup metadata, defaulting to a client account.
-- ----------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.user_role;
  v_full_name text;
begin
  v_role := coalesce(
    (new.raw_user_meta_data ->> 'role')::public.user_role,
    'client'
  );
  v_full_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, role, email, full_name)
  values (new.id, v_role, new.email, v_full_name);

  -- Give self-service clients a client record immediately.
  if v_role = 'client' then
    insert into public.clients (profile_id) values (new.id);
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ----------------------------------------------------------------------------
-- enforce_role_change: only admins (or trusted server-side contexts where
-- auth.uid() is NULL, e.g. the service role) may change a profile's role.
-- ----------------------------------------------------------------------------
create or replace function private.enforce_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.role is distinct from old.role)
     and auth.uid() is not null
     and not private.is_admin() then
    raise exception 'Only administrators may change a profile role.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger enforce_role_change
  before update on public.profiles
  for each row execute function private.enforce_role_change();

-- ----------------------------------------------------------------------------
-- custom_access_token_hook: injects the application role into the JWT as the
-- `user_role` claim. Enable via Supabase Auth Hooks (config or dashboard) so
-- the role is available to the client and to PostgREST without a profiles read.
-- ----------------------------------------------------------------------------
create or replace function private.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_claims jsonb;
  v_role public.user_role;
begin
  select role into v_role
  from public.profiles
  where id = (event ->> 'user_id')::uuid
    and deleted_at is null;

  v_claims := event -> 'claims';

  if v_role is not null then
    v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role::text));
  end if;

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

-- The auth hook is invoked by the dedicated auth admin role only.
revoke execute on function private.custom_access_token_hook(jsonb)
  from anon, authenticated, public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    grant usage on schema private to supabase_auth_admin;
    grant execute on function private.custom_access_token_hook(jsonb)
      to supabase_auth_admin;
  end if;
end;
$$;
