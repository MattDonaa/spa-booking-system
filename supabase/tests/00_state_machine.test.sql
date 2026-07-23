-- ============================================================================
-- Tests: Booking state machine (pure function, no data required)
-- Run with: supabase test db
-- ============================================================================
begin;
select plan(16);

-- Valid transitions.
select ok(
  public.is_valid_booking_transition('pending_hold', 'pending_payment'),
  'hold -> pending_payment is allowed');
select ok(
  public.is_valid_booking_transition('pending_payment', 'pending_intake'),
  'pending_payment -> pending_intake is allowed');
select ok(
  public.is_valid_booking_transition('pending_intake', 'confirmed'),
  'pending_intake -> confirmed is allowed');
select ok(
  public.is_valid_booking_transition('confirmed', 'checked_in'),
  'confirmed -> checked_in is allowed');
select ok(
  public.is_valid_booking_transition('checked_in', 'in_progress'),
  'checked_in -> in_progress is allowed');
select ok(
  public.is_valid_booking_transition('in_progress', 'completed'),
  'in_progress -> completed is allowed');
select ok(
  public.is_valid_booking_transition('completed', 'refunded'),
  'completed -> refunded is allowed');
select ok(
  public.is_valid_booking_transition('pending_hold', 'expired'),
  'hold -> expired is allowed');
select ok(
  public.is_valid_booking_transition('confirmed', 'no_show'),
  'confirmed -> no_show is allowed');

-- Invalid transitions.
select ok(
  not public.is_valid_booking_transition('pending_hold', 'completed'),
  'hold -> completed is rejected (must progress through the machine)');
select ok(
  not public.is_valid_booking_transition('completed', 'confirmed'),
  'completed -> confirmed is rejected');
select ok(
  not public.is_valid_booking_transition('cancelled', 'confirmed'),
  'cancelled is terminal');
select ok(
  not public.is_valid_booking_transition('expired', 'confirmed'),
  'expired is terminal');
select ok(
  not public.is_valid_booking_transition('refunded', 'completed'),
  'refunded is terminal');
select ok(
  not public.is_valid_booking_transition('no_show', 'confirmed'),
  'no_show is terminal');
select ok(
  not public.is_valid_booking_transition('confirmed', 'confirmed'),
  'same-status is not a valid transition');

select * from finish();
rollback;
