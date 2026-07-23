-- ============================================================================
-- Migration: RLS Policies — Bookings, Payments, Medical & Audit
-- ----------------------------------------------------------------------------
-- Access rules for the operational and sensitive tables. Payments, webhook
-- events, notifications, and audit logs are written exclusively by the service
-- role (which bypasses RLS): no INSERT/UPDATE policies are granted here, so
-- those commands are denied for every non-service role. Intake and consent
-- records enforce medical-record protection (POPIA): visible only to the owning
-- client, the practitioner assigned to the related booking, and admins.
-- ============================================================================

-- ============================================================================
-- bookings
-- ============================================================================
create policy bookings_select on public.bookings
  for select to authenticated
  using (
    private.is_admin()
    or client_id = private.current_client_id()
    or practitioner_id = private.current_practitioner_id()
  );

create policy bookings_insert on public.bookings
  for insert to authenticated
  with check (
    private.is_staff()
    or client_id = private.current_client_id()
  );

create policy bookings_update on public.bookings
  for update to authenticated
  using (
    private.is_admin()
    or client_id = private.current_client_id()
    or practitioner_id = private.current_practitioner_id()
  )
  with check (
    private.is_admin()
    or client_id = private.current_client_id()
    or practitioner_id = private.current_practitioner_id()
  );

-- ============================================================================
-- booking_events: read-only for the parties to the booking. Rows are written
-- solely by the record_booking_event trigger (SECURITY DEFINER).
-- ============================================================================
create policy booking_events_select on public.booking_events
  for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1
      from public.bookings b
      where b.id = booking_id
        and (
          b.client_id = private.current_client_id()
          or b.practitioner_id = private.current_practitioner_id()
        )
    )
  );

-- ============================================================================
-- payments: read-only. The owning client and admins may read; all writes are
-- performed server-side by the service role.
-- ============================================================================
create policy payments_select on public.payments
  for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and b.client_id = private.current_client_id()
    )
  );

-- ============================================================================
-- refunds: read-only for the owning client (via the payment's booking) and
-- admins. Writes are service-role only.
-- ============================================================================
create policy refunds_select on public.refunds
  for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1
      from public.payments p
      join public.bookings b on b.id = p.booking_id
      where p.id = payment_id
        and b.client_id = private.current_client_id()
    )
  );

-- ============================================================================
-- payment_webhook_events: no policies — service role only (deny all others).
-- ============================================================================

-- ============================================================================
-- intake_forms — MEDICAL RECORD PROTECTION
-- Visible to: the owning client, the practitioner assigned to the booking,
-- and admins. The client may fill in their own form while it is not yet
-- completed; practitioners have read-only access.
-- ============================================================================
create policy intake_forms_select on public.intake_forms
  for select to authenticated
  using (
    private.is_admin()
    or client_id = private.current_client_id()
    or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and b.practitioner_id = private.current_practitioner_id()
    )
  );

create policy intake_forms_insert on public.intake_forms
  for insert to authenticated
  with check (
    private.is_staff()
    or client_id = private.current_client_id()
  );

create policy intake_forms_update on public.intake_forms
  for update to authenticated
  using (
    private.is_admin()
    or (
      client_id = private.current_client_id()
      and status in ('pending', 'in_progress')
    )
  )
  with check (
    private.is_admin()
    or client_id = private.current_client_id()
  );

-- ============================================================================
-- consent_records — signed, immutable legal evidence.
-- Readable by the owning client, the assigned practitioner, and admins.
-- Insertable by the client or staff. Only admins may amend (corrections).
-- ============================================================================
create policy consent_records_select on public.consent_records
  for select to authenticated
  using (
    private.is_admin()
    or client_id = private.current_client_id()
    or (
      booking_id is not null
      and exists (
        select 1 from public.bookings b
        where b.id = booking_id
          and b.practitioner_id = private.current_practitioner_id()
      )
    )
  );

create policy consent_records_insert on public.consent_records
  for insert to authenticated
  with check (
    private.is_staff()
    or client_id = private.current_client_id()
  );

create policy consent_records_update_admin on public.consent_records
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());

-- ============================================================================
-- notification_queue / notifications: admin read only; all writes are
-- service-role only.
-- ============================================================================
create policy notification_queue_select_admin on public.notification_queue
  for select to authenticated
  using (private.is_admin());

create policy notifications_select_admin on public.notifications
  for select to authenticated
  using (private.is_admin());

-- ============================================================================
-- audit_logs: admin read only. Rows are written solely by the record_audit
-- trigger (SECURITY DEFINER); no INSERT/UPDATE policy exists.
-- ============================================================================
create policy audit_logs_select_admin on public.audit_logs
  for select to authenticated
  using (private.is_admin());
