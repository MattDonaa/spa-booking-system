-- ============================================================================
-- Migration: Enum Types
-- ----------------------------------------------------------------------------
-- Domain enumerations. Using native enum types keeps invalid states
-- unrepresentable at the database level (the source of truth).
-- ============================================================================

-- Account role. A profile has exactly one primary role.
create type public.user_role as enum (
  'client',
  'practitioner',
  'admin'
);

-- Booking lifecycle. Mirrors the state machine in the project specification.
-- 'available' is a property of a time slot, not a persisted booking, and is
-- therefore intentionally absent.
create type public.booking_status as enum (
  'pending_hold',
  'pending_payment',
  'pending_intake',
  'confirmed',
  'checked_in',
  'in_progress',
  'completed',
  'expired',
  'cancelled',
  'refunded',
  'no_show'
);

-- Category of a booking lifecycle event (for the append-only event log).
create type public.booking_event_type as enum (
  'created',
  'status_changed',
  'rescheduled',
  'hold_extended',
  'note_added'
);

-- Supported payment providers.
create type public.payment_provider as enum (
  'payfast',
  'ozow'
);

-- What a payment represents.
create type public.payment_type as enum (
  'deposit',
  'balance',
  'full',
  'refund'
);

-- Payment lifecycle.
create type public.payment_status as enum (
  'pending',
  'processing',
  'succeeded',
  'failed',
  'cancelled',
  'refunded',
  'partially_refunded'
);

-- Refund lifecycle.
create type public.refund_status as enum (
  'pending',
  'processing',
  'succeeded',
  'failed'
);

-- Delivery channel for a notification.
create type public.notification_channel as enum (
  'email',
  'whatsapp'
);

-- Business meaning of a notification.
create type public.notification_type as enum (
  'booking_confirmation',
  'payment_reminder',
  'payment_receipt',
  'appointment_reminder',
  'booking_cancelled',
  'booking_rescheduled',
  'intake_reminder',
  'review_request',
  'rebooking_reminder'
);

-- Queue state for an outbound notification.
create type public.notification_status as enum (
  'queued',
  'processing',
  'sent',
  'failed',
  'cancelled'
);

-- Purpose of a form template.
create type public.form_type as enum (
  'medical_intake',
  'consent',
  'general_intake'
);

-- Completion state of a client's intake form instance.
create type public.intake_status as enum (
  'pending',
  'in_progress',
  'completed'
);

-- Category of a scheduling block (non-bookable time).
create type public.availability_block_type as enum (
  'time_off',
  'break',
  'holiday',
  'maintenance'
);

-- Mutating action recorded in the audit trail.
create type public.audit_action as enum (
  'insert',
  'update',
  'delete',
  'soft_delete',
  'restore'
);
