/** Admin portal read-model types. */

export interface DashboardMetrics {
  today_bookings: number;
  upcoming_bookings: number;
  pending_payments: number;
  revenue_month_cents: number;
  active_practitioners: number;
  pending_forms: number;
}

export interface AdminBookingRow {
  booking_id: string;
  status: string;
  starts_at: string;
  ends_at: string;
  price_cents: number;
  currency: string;
  client_name: string;
  practitioner_name: string;
  service_name: string;
  room_name: string | null;
}

export interface AdminPractitioner {
  practitioner_id: string;
  name: string;
  email: string;
  title: string | null;
  bio: string | null;
  specialties: string[];
  is_active: boolean;
}

export interface AdminService {
  service_id: string;
  name: string;
  slug: string;
  description: string | null;
  duration_minutes: number;
  buffer_before_minutes: number;
  buffer_after_minutes: number;
  price_cents: number;
  deposit_cents: number;
  currency: string;
  requires_room: boolean;
  requires_intake: boolean;
  is_active: boolean;
}

export interface AdminRoom {
  room_id: string;
  name: string;
  description: string | null;
  capacity: number;
  features: string[];
  is_active: boolean;
}

export interface AvailabilitySlot {
  id: string;
  day_of_week: number;
  start_time: string;
  end_time: string;
}

export interface AvailabilityBlock {
  id: string;
  block_type: string;
  starts_at: string;
  ends_at: string;
  reason: string | null;
}

export interface AvailabilityData {
  schedule: AvailabilitySlot[];
  blocks: AvailabilityBlock[];
}

export interface AdminPaymentRow {
  payment_id: string;
  status: string;
  amount_cents: number;
  currency: string;
  provider: string;
  payment_type: string;
  created_at: string;
  paid_at: string | null;
  client_name: string;
  service_name: string;
}

export interface AdminTemplateRow {
  template_id: string;
  name: string;
  slug: string;
  form_type: string;
  version: number;
  is_medical: boolean;
  is_active: boolean;
  field_count: number;
}

export interface BusinessSettings {
  business_name: string;
  timezone: string;
  currency: string;
  default_deposit_percentage: number;
  hold_duration_minutes: number;
  min_booking_lead_minutes: number;
  max_booking_lead_days: number;
  cancellation_window_hours: number;
  contact_email: string | null;
  contact_phone: string | null;
}

export interface AuditLogRow {
  id: string;
  action: string;
  entity_type: string;
  entity_id: string;
  actor_profile_id: string | null;
  created_at: string;
}

export interface NotificationRow {
  id: string;
  channel: string;
  notification_type: string;
  status: string;
  attempts: number;
  max_attempts: number;
  scheduled_for: string;
  sent_at: string | null;
  last_error: string | null;
  created_at: string;
}

export interface ReportSummary {
  range: { from: string; to: string };
  bookings_total: number;
  bookings_completed: number;
  bookings_cancelled: number;
  revenue_cents: number;
  refunds_cents: number;
}
