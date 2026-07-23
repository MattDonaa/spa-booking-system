-- ============================================================================
-- Migration: Row Level Security Policies, Grants & Permissions
-- ----------------------------------------------------------------------------
-- Defines the complete access model on top of the deny-by-default RLS enabled
-- in Milestone 2. Model summary:
--
--   * anon           — may browse the public catalog only (active rows).
--   * authenticated  — governed row-by-row by the policies below.
--   * client         — sees/edits only their own data.
--   * practitioner   — sees data for bookings assigned to them.
--   * admin          — full access.
--   * service_role   — bypasses RLS entirely (server-side only); it, and it
--                      alone, writes payments, webhook events, notifications,
--                      and audit logs.
--
-- No DELETE policies exist anywhere: business data is soft-deleted, and hard
-- deletes are already blocked by trigger. Tables with no policy for a command
-- deny that command for all non-service roles.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Base privileges. RLS filters rows, but a role still needs table privileges
-- for a command to be considered at all.
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

-- Public catalog: readable by anonymous visitors.
grant select on
  public.service_categories,
  public.services,
  public.rooms,
  public.practitioners,
  public.practitioner_services,
  public.practitioner_availability,
  public.availability_blocks,
  public.business_settings,
  public.form_templates
to anon;

-- Authenticated users: SELECT/INSERT/UPDATE across public tables (never
-- DELETE). RLS decides which rows and commands actually succeed.
grant select, insert, update on all tables in schema public to authenticated;

-- ============================================================================
-- profiles
-- ============================================================================
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or private.is_staff());

create policy profiles_insert_admin on public.profiles
  for insert to authenticated
  with check (private.is_admin());

create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid() or private.is_admin())
  with check (id = auth.uid() or private.is_admin());

-- ============================================================================
-- clients
-- ============================================================================
create policy clients_select on public.clients
  for select to authenticated
  using (profile_id = auth.uid() or private.is_staff());

create policy clients_insert on public.clients
  for insert to authenticated
  with check (profile_id = auth.uid() or private.is_admin());

create policy clients_update on public.clients
  for update to authenticated
  using (profile_id = auth.uid() or private.is_admin())
  with check (profile_id = auth.uid() or private.is_admin());

-- ============================================================================
-- practitioners
-- ============================================================================
create policy practitioners_select_public on public.practitioners
  for select to anon, authenticated
  using (deleted_at is null and is_active);

create policy practitioners_select_staff on public.practitioners
  for select to authenticated
  using (private.is_staff());

create policy practitioners_insert_admin on public.practitioners
  for insert to authenticated
  with check (private.is_admin());

create policy practitioners_update on public.practitioners
  for update to authenticated
  using (profile_id = auth.uid() or private.is_admin())
  with check (profile_id = auth.uid() or private.is_admin());

-- ============================================================================
-- Catalog reference data: public read (active), admin write.
-- ============================================================================
create policy service_categories_select on public.service_categories
  for select to anon, authenticated
  using (deleted_at is null and (is_active or private.is_staff()));
create policy service_categories_write on public.service_categories
  for insert to authenticated with check (private.is_admin());
create policy service_categories_update on public.service_categories
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create policy services_select on public.services
  for select to anon, authenticated
  using (deleted_at is null and (is_active or private.is_staff()));
create policy services_insert on public.services
  for insert to authenticated with check (private.is_admin());
create policy services_update on public.services
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create policy rooms_select on public.rooms
  for select to anon, authenticated
  using (deleted_at is null and (is_active or private.is_staff()));
create policy rooms_insert on public.rooms
  for insert to authenticated with check (private.is_admin());
create policy rooms_update on public.rooms
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create policy practitioner_services_select on public.practitioner_services
  for select to anon, authenticated
  using (deleted_at is null);
create policy practitioner_services_insert on public.practitioner_services
  for insert to authenticated
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );
create policy practitioner_services_update on public.practitioner_services
  for update to authenticated
  using (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  )
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );

-- ============================================================================
-- Availability: public read, practitioner manages own, admin manages all.
-- ============================================================================
create policy practitioner_availability_select on public.practitioner_availability
  for select to anon, authenticated
  using (deleted_at is null);
create policy practitioner_availability_insert on public.practitioner_availability
  for insert to authenticated
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );
create policy practitioner_availability_update on public.practitioner_availability
  for update to authenticated
  using (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  )
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );

create policy availability_blocks_select on public.availability_blocks
  for select to anon, authenticated
  using (deleted_at is null);
create policy availability_blocks_insert on public.availability_blocks
  for insert to authenticated
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );
create policy availability_blocks_update on public.availability_blocks
  for update to authenticated
  using (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  )
  with check (
    private.is_admin() or practitioner_id = private.current_practitioner_id()
  );

-- ============================================================================
-- business_settings: public read, admin update.
-- ============================================================================
create policy business_settings_select on public.business_settings
  for select to anon, authenticated
  using (deleted_at is null);
create policy business_settings_update on public.business_settings
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- ============================================================================
-- form_templates: authenticated read (active), staff read all, admin write.
-- ============================================================================
create policy form_templates_select on public.form_templates
  for select to authenticated
  using (deleted_at is null and (is_active or private.is_staff()));
create policy form_templates_insert on public.form_templates
  for insert to authenticated with check (private.is_admin());
create policy form_templates_update on public.form_templates
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
