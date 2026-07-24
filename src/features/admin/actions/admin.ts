'use server';

import { revalidatePath } from 'next/cache';

import { createClient } from '@/lib/supabase/server';
import { unwrapRpc } from '@/lib/rpc';
import type { Result } from '@/lib/result';
import type {
  AdminBookingRow,
  AdminPaymentRow,
  AdminPractitioner,
  AdminRoom,
  AdminService,
  AdminTemplateRow,
  AuditLogRow,
  AvailabilityData,
  BusinessSettings,
  DashboardMetrics,
  NotificationRow,
  ReportSummary,
} from '@/features/admin/types';

async function rpc<T>(
  fn: string,
  args?: Record<string, unknown>,
): Promise<Result<T>> {
  const supabase = await createClient();
  const { data, error } = args
    ? await supabase.rpc(fn, args as never)
    : await supabase.rpc(fn);
  return unwrapRpc<T>(data, error);
}

export async function adminDashboard(): Promise<Result<DashboardMetrics>> {
  return rpc<DashboardMetrics>('admin_dashboard');
}

export async function adminListBookings(
  from?: string,
  to?: string,
  status?: string,
): Promise<Result<AdminBookingRow[]>> {
  return rpc<AdminBookingRow[]>('admin_list_bookings', {
    p_from: from ?? null,
    p_to: to ?? null,
    p_status: status ?? null,
  });
}

export async function adminListPractitioners(): Promise<
  Result<AdminPractitioner[]>
> {
  return rpc<AdminPractitioner[]>('admin_list_practitioners');
}

export async function adminUpdatePractitioner(input: {
  practitionerId: string;
  title?: string;
  bio?: string;
  specialties?: string[];
  isActive?: boolean;
}): Promise<Result<unknown>> {
  const result = await rpc('admin_update_practitioner', {
    p_practitioner_id: input.practitionerId,
    p_title: input.title ?? null,
    p_bio: input.bio ?? null,
    p_specialties: input.specialties ?? null,
    p_is_active: input.isActive ?? null,
  });
  revalidatePath('/admin/practitioners');
  return result;
}

export async function adminListServices(): Promise<Result<AdminService[]>> {
  return rpc<AdminService[]>('admin_list_services');
}

export async function adminUpsertService(input: {
  serviceId?: string;
  name: string;
  slug: string;
  durationMinutes: number;
  priceCents: number;
  description?: string;
  bufferBeforeMinutes?: number;
  bufferAfterMinutes?: number;
  depositCents?: number;
  requiresRoom?: boolean;
  requiresIntake?: boolean;
  isActive?: boolean;
}): Promise<Result<unknown>> {
  const result = await rpc('admin_upsert_service', {
    p_name: input.name,
    p_slug: input.slug,
    p_duration_minutes: input.durationMinutes,
    p_price_cents: input.priceCents,
    p_service_id: input.serviceId ?? null,
    p_description: input.description ?? null,
    p_buffer_before_minutes: input.bufferBeforeMinutes ?? 0,
    p_buffer_after_minutes: input.bufferAfterMinutes ?? 0,
    p_deposit_cents: input.depositCents ?? 0,
    p_requires_room: input.requiresRoom ?? true,
    p_requires_intake: input.requiresIntake ?? false,
    p_is_active: input.isActive ?? true,
  });
  revalidatePath('/admin/services');
  return result;
}

export async function adminListRooms(): Promise<Result<AdminRoom[]>> {
  return rpc<AdminRoom[]>('admin_list_rooms');
}

export async function adminUpsertRoom(input: {
  roomId?: string;
  name: string;
  description?: string;
  capacity?: number;
  features?: string[];
  isActive?: boolean;
}): Promise<Result<unknown>> {
  const result = await rpc('admin_upsert_room', {
    p_name: input.name,
    p_room_id: input.roomId ?? null,
    p_description: input.description ?? null,
    p_capacity: input.capacity ?? 1,
    p_features: input.features ?? [],
    p_is_active: input.isActive ?? true,
  });
  revalidatePath('/admin/rooms');
  return result;
}

export async function adminListAvailability(
  practitionerId: string,
): Promise<Result<AvailabilityData>> {
  return rpc<AvailabilityData>('admin_list_availability', {
    p_practitioner_id: practitionerId,
  });
}

export async function adminAddAvailabilityBlock(input: {
  practitionerId: string;
  startsAt: string;
  endsAt: string;
  blockType?: string;
  reason?: string;
}): Promise<Result<unknown>> {
  const result = await rpc('admin_add_availability_block', {
    p_practitioner_id: input.practitionerId,
    p_starts_at: input.startsAt,
    p_ends_at: input.endsAt,
    p_block_type: input.blockType ?? 'time_off',
    p_reason: input.reason ?? null,
  });
  revalidatePath('/admin/availability');
  return result;
}

export async function adminListPayments(
  from?: string,
  to?: string,
  status?: string,
): Promise<Result<AdminPaymentRow[]>> {
  return rpc<AdminPaymentRow[]>('admin_list_payments', {
    p_from: from ?? null,
    p_to: to ?? null,
    p_status: status ?? null,
  });
}

export async function adminListTemplates(): Promise<
  Result<AdminTemplateRow[]>
> {
  return rpc<AdminTemplateRow[]>('admin_list_templates');
}

export async function getBusinessSettings(): Promise<Result<BusinessSettings>> {
  return rpc<BusinessSettings>('get_business_settings');
}

export async function updateBusinessSettings(
  input: Partial<BusinessSettings>,
): Promise<Result<BusinessSettings>> {
  const result = await rpc<BusinessSettings>('update_business_settings', {
    p_business_name: input.business_name ?? null,
    p_timezone: input.timezone ?? null,
    p_currency: input.currency ?? null,
    p_default_deposit_percentage: input.default_deposit_percentage ?? null,
    p_hold_duration_minutes: input.hold_duration_minutes ?? null,
    p_min_booking_lead_minutes: input.min_booking_lead_minutes ?? null,
    p_max_booking_lead_days: input.max_booking_lead_days ?? null,
    p_cancellation_window_hours: input.cancellation_window_hours ?? null,
    p_contact_email: input.contact_email ?? null,
    p_contact_phone: input.contact_phone ?? null,
  });
  revalidatePath('/admin/settings');
  return result;
}

export async function adminListAuditLogs(
  entityType?: string,
): Promise<Result<AuditLogRow[]>> {
  return rpc<AuditLogRow[]>('admin_list_audit_logs', {
    p_limit: 100,
    p_entity_type: entityType ?? null,
  });
}

export async function adminListNotifications(
  status?: string,
): Promise<Result<NotificationRow[]>> {
  return rpc<NotificationRow[]>('admin_list_notifications', {
    p_status: status ?? null,
    p_limit: 100,
  });
}

export async function adminRetryNotification(
  id: string,
): Promise<Result<unknown>> {
  const result = await rpc('admin_retry_notification', {
    p_notification_id: id,
  });
  revalidatePath('/admin/notifications');
  return result;
}

export async function adminReports(
  from?: string,
  to?: string,
): Promise<Result<ReportSummary>> {
  return rpc<ReportSummary>('admin_reports', {
    p_from: from ?? null,
    p_to: to ?? null,
  });
}
