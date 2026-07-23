'use server';

import { revalidatePath } from 'next/cache';

import { createClient } from '@/lib/supabase/server';
import { unwrapRpc } from '@/lib/rpc';
import type { Result } from '@/lib/result';
import type {
  BookingDetail,
  BookingSummary,
  ClientProfile,
  IntakeFormRow,
  PaymentRow,
} from '@/features/portal/types';

export async function getMyProfile(): Promise<Result<ClientProfile>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('get_my_profile');
  return unwrapRpc<ClientProfile>(data, error);
}

export async function updateMyProfile(input: {
  fullName?: string;
  phone?: string;
  dateOfBirth?: string;
  emergencyContactName?: string;
  emergencyContactPhone?: string;
  marketingOptIn?: boolean;
}): Promise<Result<ClientProfile>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('update_my_profile', {
    p_full_name: input.fullName ?? null,
    p_phone: input.phone ?? null,
    p_date_of_birth: input.dateOfBirth || null,
    p_emergency_contact_name: input.emergencyContactName ?? null,
    p_emergency_contact_phone: input.emergencyContactPhone ?? null,
    p_marketing_opt_in: input.marketingOptIn ?? null,
  } as never);
  revalidatePath('/portal/profile');
  return unwrapRpc<ClientProfile>(data, error);
}

export async function listMyBookings(
  scope: 'upcoming' | 'past' | 'all' = 'all',
): Promise<Result<BookingSummary[]>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('list_my_bookings', {
    p_scope: scope,
  } as never);
  return unwrapRpc<BookingSummary[]>(data, error);
}

export async function getMyBooking(
  bookingId: string,
): Promise<Result<BookingDetail>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('get_my_booking', {
    p_booking_id: bookingId,
  } as never);
  return unwrapRpc<BookingDetail>(data, error);
}

export async function listMyPayments(): Promise<Result<PaymentRow[]>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('list_my_payments');
  return unwrapRpc<PaymentRow[]>(data, error);
}

export async function listMyIntakeForms(): Promise<Result<IntakeFormRow[]>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('list_my_intake_forms');
  return unwrapRpc<IntakeFormRow[]>(data, error);
}

export async function cancelMyBooking(
  bookingId: string,
  reason?: string,
): Promise<Result<unknown>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('cancel_booking', {
    p_booking_id: bookingId,
    p_reason: reason ?? null,
  } as never);
  revalidatePath(`/portal/bookings/${bookingId}`);
  revalidatePath('/portal/bookings');
  return unwrapRpc(data, error);
}

export async function rescheduleMyBooking(
  bookingId: string,
  startsAtIso: string,
): Promise<Result<unknown>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('reschedule_booking', {
    p_booking_id: bookingId,
    p_starts_at: startsAtIso,
    p_practitioner_id: null,
  } as never);
  revalidatePath(`/portal/bookings/${bookingId}`);
  return unwrapRpc(data, error);
}
