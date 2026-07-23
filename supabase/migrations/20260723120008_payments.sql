-- ============================================================================
-- Migration: Payments, Refunds & Webhook Events
-- ----------------------------------------------------------------------------
-- Payments are idempotent (unique idempotency_key) and never trusted from the
-- client — status transitions are driven by verified provider webhooks. The
-- payment_webhook_events table guarantees each provider event is processed at
-- most once.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- payments
-- ----------------------------------------------------------------------------
create table public.payments (
  id uuid primary key default extensions.gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete restrict,
  provider public.payment_provider not null,
  payment_type public.payment_type not null default 'deposit',
  status public.payment_status not null default 'pending',
  amount_cents integer not null,
  currency char(3) not null default 'ZAR',
  -- Application-generated key guaranteeing idempotent creation/processing.
  idempotency_key text not null,
  -- Provider's own transaction / payment reference, populated on completion.
  provider_reference text,
  -- Raw provider payload for reconciliation and audit (no card data stored).
  provider_payload jsonb,
  paid_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint payments_amount_positive_chk check (amount_cents > 0),
  constraint payments_currency_format_chk check (currency ~ '^[A-Z]{3}$')
);

create unique index payments_idempotency_key_unique_idx
  on public.payments (idempotency_key);

create unique index payments_provider_reference_unique_idx
  on public.payments (provider, provider_reference)
  where provider_reference is not null;

create index payments_booking_idx on public.payments (booking_id);
create index payments_status_idx on public.payments (status) where deleted_at is null;

comment on table public.payments is
  'Payment attempts and outcomes. Idempotent via idempotency_key; amounts in cents.';

-- ----------------------------------------------------------------------------
-- refunds
-- ----------------------------------------------------------------------------
create table public.refunds (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_id uuid not null references public.payments (id) on delete restrict,
  status public.refund_status not null default 'pending',
  amount_cents integer not null,
  reason text,
  idempotency_key text not null,
  provider_reference text,
  provider_payload jsonb,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint refunds_amount_positive_chk check (amount_cents > 0)
);

create unique index refunds_idempotency_key_unique_idx
  on public.refunds (idempotency_key);

create index refunds_payment_idx on public.refunds (payment_id);

comment on table public.refunds is
  'Refunds issued against a payment. Idempotent via idempotency_key.';

-- ----------------------------------------------------------------------------
-- payment_webhook_events: at-most-once processing of provider callbacks.
-- The unique (provider, event_id) index makes redelivery a no-op.
-- ----------------------------------------------------------------------------
create table public.payment_webhook_events (
  id uuid primary key default extensions.gen_random_uuid(),
  provider public.payment_provider not null,
  event_id text not null,
  payment_id uuid references public.payments (id) on delete set null,
  signature_verified boolean not null default false,
  payload jsonb not null,
  processed_at timestamptz,
  processing_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index payment_webhook_events_unique_idx
  on public.payment_webhook_events (provider, event_id);

create index payment_webhook_events_payment_idx
  on public.payment_webhook_events (payment_id);

comment on table public.payment_webhook_events is
  'Verified provider webhook deliveries. Unique per (provider, event_id) for idempotency.';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.payments
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.refunds
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.payment_webhook_events
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.payments
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.refunds
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.payment_webhook_events
  for each row execute function public.prevent_hard_delete();

create trigger record_audit
  after insert or update or delete on public.payments
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.refunds
  for each row execute function public.record_audit();
