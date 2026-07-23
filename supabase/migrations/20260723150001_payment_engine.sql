-- ============================================================================
-- Migration: Payment Engine (RPCs)
-- ----------------------------------------------------------------------------
-- Payment state lives in PostgreSQL and is never trusted from the client. Edge
-- Functions handle provider I/O and signature verification; these RPCs own the
-- idempotent state transitions and drive the booking forward on success.
--
--   * initiate_payment      — create (or return, idempotently) a pending payment
--                             for a booking. Callable by the owning client,
--                             staff, or the service role.
--   * record_payment_event  — apply a verified provider webhook exactly once,
--                             updating the payment and advancing the booking.
--                             Service role only.
--   * initiate_refund       — create (or return) a pending refund. Staff/admin
--                             or service role.
--   * record_refund_event   — apply a verified refund result exactly once.
--                             Service role only.
--
-- Audit rows are written automatically by the record_audit triggers installed
-- on payments and refunds in Milestone 2.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- initiate_payment
-- ----------------------------------------------------------------------------
create or replace function public.initiate_payment(
  p_booking_id uuid,
  p_provider public.payment_provider,
  p_payment_type public.payment_type default 'deposit',
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_amount integer;
  v_key text;
  v_payment public.payments;
begin
  if v_uid is null and not private.is_service_role() then
    return private.rpc_err('UNAUTHENTICATED', 'Authentication required.');
  end if;

  if p_payment_type = 'refund' then
    return private.rpc_err('VALIDATION',
      'Use initiate_refund for refunds.');
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and deleted_at is null;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  -- Authorization: owning client, staff, or service role.
  if not private.is_service_role()
     and not private.is_staff()
     and v_booking.client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN',
      'You may only pay for your own bookings.');
  end if;

  -- Amount owed for this payment type (minor units).
  v_amount := case p_payment_type
    when 'deposit' then v_booking.deposit_cents
    when 'balance' then v_booking.price_cents - v_booking.deposit_cents
    when 'full' then v_booking.price_cents
    else 0
  end;

  if v_amount <= 0 then
    return private.rpc_err('VALIDATION',
      'There is nothing to pay for this booking.');
  end if;

  v_key := coalesce(
    nullif(p_idempotency_key, ''),
    'pay_' || p_booking_id::text || '_' || p_payment_type::text
  );

  -- Idempotent: return the existing payment for this key if present.
  select * into v_payment from public.payments where idempotency_key = v_key;

  if not found then
    insert into public.payments (
      booking_id, provider, payment_type, status,
      amount_cents, currency, idempotency_key
    )
    values (
      p_booking_id, p_provider, p_payment_type, 'pending',
      v_amount, v_booking.currency, v_key
    )
    returning * into v_payment;
  end if;

  return private.rpc_ok(jsonb_build_object(
    'payment_id', v_payment.id,
    'booking_id', v_payment.booking_id,
    'provider', v_payment.provider,
    'payment_type', v_payment.payment_type,
    'status', v_payment.status,
    'amount_cents', v_payment.amount_cents,
    'currency', v_payment.currency,
    'idempotency_key', v_payment.idempotency_key
  ));
end;
$$;

comment on function public.initiate_payment is
  'Creates or returns (idempotently) a pending payment for a booking.';

-- ----------------------------------------------------------------------------
-- record_payment_event
-- Applies a verified provider webhook exactly once. Service role only.
-- ----------------------------------------------------------------------------
create or replace function public.record_payment_event(
  p_provider public.payment_provider,
  p_event_id text,
  p_payment_id uuid,
  p_status public.payment_status,
  p_provider_reference text,
  p_signature_verified boolean,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_event_id uuid;
  v_payment public.payments;
  v_booking public.bookings;
  v_requires_intake boolean;
  v_target public.booking_status;
begin
  if not private.is_service_role() then
    return private.rpc_err('FORBIDDEN', 'Service role required.');
  end if;

  -- Idempotency: at most one processing per (provider, event_id).
  insert into public.payment_webhook_events (
    provider, event_id, payment_id, signature_verified, payload, processed_at
  )
  values (
    p_provider, p_event_id, p_payment_id, p_signature_verified, p_payload, now()
  )
  on conflict (provider, event_id) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    return private.rpc_ok(jsonb_build_object(
      'already_processed', true, 'payment_id', p_payment_id));
  end if;

  -- Reject unverified signatures (event is recorded for forensics).
  if not p_signature_verified then
    update public.payment_webhook_events
    set processing_error = 'signature_verification_failed'
    where id = v_event_id;
    return private.rpc_err('FORBIDDEN', 'Webhook signature invalid.');
  end if;

  select * into v_payment
  from public.payments where id = p_payment_id and deleted_at is null
  for update;

  if not found then
    update public.payment_webhook_events
    set processing_error = 'payment_not_found'
    where id = v_event_id;
    return private.rpc_err('NOT_FOUND', 'Payment not found.');
  end if;

  update public.payments
  set status = p_status,
      provider_reference = coalesce(p_provider_reference, provider_reference),
      provider_payload = p_payload,
      paid_at = case when p_status = 'succeeded' then now() else paid_at end,
      failed_at = case when p_status = 'failed' then now() else failed_at end
  where id = p_payment_id;

  -- On success, advance the booking out of the pending states.
  if p_status = 'succeeded' then
    select * into v_booking
    from public.bookings where id = v_payment.booking_id for update;

    if found and v_booking.status in ('pending_hold', 'pending_payment') then
      select s.requires_intake into v_requires_intake
      from public.services s where s.id = v_booking.service_id;

      v_target := case
        when coalesce(v_requires_intake, false) then 'pending_intake'
        else 'confirmed'
      end;

      perform public.transition_booking(v_booking.id, v_target, 'payment_succeeded');
    end if;
  end if;

  return private.rpc_ok(jsonb_build_object(
    'payment_id', p_payment_id, 'status', p_status));
end;
$$;

comment on function public.record_payment_event is
  'Idempotently applies a verified payment webhook and advances the booking.';

-- ----------------------------------------------------------------------------
-- initiate_refund
-- ----------------------------------------------------------------------------
create or replace function public.initiate_refund(
  p_payment_id uuid,
  p_amount_cents integer default null,
  p_reason text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_payment public.payments;
  v_amount integer;
  v_key text;
  v_refund public.refunds;
begin
  if not private.is_service_role() and not private.is_staff() then
    return private.rpc_err('FORBIDDEN',
      'Only staff may issue refunds.');
  end if;

  select * into v_payment
  from public.payments where id = p_payment_id and deleted_at is null;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Payment not found.');
  end if;

  if v_payment.status not in ('succeeded', 'partially_refunded') then
    return private.rpc_err('CONFLICT',
      'Only settled payments can be refunded.');
  end if;

  v_amount := coalesce(p_amount_cents, v_payment.amount_cents);
  if v_amount <= 0 or v_amount > v_payment.amount_cents then
    return private.rpc_err('VALIDATION', 'Invalid refund amount.');
  end if;

  v_key := coalesce(
    nullif(p_idempotency_key, ''),
    'refund_' || p_payment_id::text || '_' || v_amount::text
  );

  select * into v_refund from public.refunds where idempotency_key = v_key;

  if not found then
    insert into public.refunds (
      payment_id, status, amount_cents, reason, idempotency_key
    )
    values (p_payment_id, 'pending', v_amount, p_reason, v_key)
    returning * into v_refund;
  end if;

  return private.rpc_ok(jsonb_build_object(
    'refund_id', v_refund.id,
    'payment_id', v_refund.payment_id,
    'status', v_refund.status,
    'amount_cents', v_refund.amount_cents,
    'idempotency_key', v_refund.idempotency_key
  ));
end;
$$;

comment on function public.initiate_refund is
  'Creates or returns (idempotently) a pending refund against a settled payment.';

-- ----------------------------------------------------------------------------
-- record_refund_event
-- Applies a verified refund result exactly once. Service role only.
-- ----------------------------------------------------------------------------
create or replace function public.record_refund_event(
  p_refund_id uuid,
  p_status public.refund_status,
  p_provider_reference text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_refund public.refunds;
  v_payment public.payments;
  v_total_refunded integer;
  v_new_payment_status public.payment_status;
begin
  if not private.is_service_role() then
    return private.rpc_err('FORBIDDEN', 'Service role required.');
  end if;

  select * into v_refund
  from public.refunds where id = p_refund_id and deleted_at is null
  for update;

  if not found then
    return private.rpc_err('NOT_FOUND', 'Refund not found.');
  end if;

  -- Idempotent: do not reprocess a terminal refund.
  if v_refund.status in ('succeeded', 'failed') then
    return private.rpc_ok(jsonb_build_object(
      'already_processed', true, 'refund_id', p_refund_id));
  end if;

  update public.refunds
  set status = p_status,
      provider_reference = coalesce(p_provider_reference, provider_reference),
      provider_payload = p_payload,
      refunded_at = case when p_status = 'succeeded' then now() else refunded_at end
  where id = p_refund_id;

  if p_status = 'succeeded' then
    select * into v_payment
    from public.payments where id = v_refund.payment_id for update;

    select coalesce(sum(amount_cents), 0) into v_total_refunded
    from public.refunds
    where payment_id = v_refund.payment_id
      and status = 'succeeded' and deleted_at is null;

    v_new_payment_status := case
      when v_total_refunded >= v_payment.amount_cents then 'refunded'
      else 'partially_refunded'
    end;

    update public.payments
    set status = v_new_payment_status
    where id = v_refund.payment_id;
  end if;

  return private.rpc_ok(jsonb_build_object(
    'refund_id', p_refund_id, 'status', p_status));
end;
$$;

comment on function public.record_refund_event is
  'Idempotently applies a verified refund result and updates the payment.';

-- ----------------------------------------------------------------------------
-- Grants (RPC permissions)
-- ----------------------------------------------------------------------------
grant execute on function
  public.initiate_payment(uuid, public.payment_provider, public.payment_type, text),
  public.initiate_refund(uuid, integer, text, text)
to authenticated, service_role;

-- Webhook appliers are server-side only.
grant execute on function
  public.record_payment_event(
    public.payment_provider, text, uuid, public.payment_status, text, boolean, jsonb),
  public.record_refund_event(uuid, public.refund_status, text, jsonb)
to service_role;
