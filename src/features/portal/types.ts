/** Client portal read-model types (shapes returned by the portal RPCs). */

export type BookingStatus =
  | 'pending_hold'
  | 'pending_payment'
  | 'pending_intake'
  | 'confirmed'
  | 'checked_in'
  | 'in_progress'
  | 'completed'
  | 'expired'
  | 'cancelled'
  | 'refunded'
  | 'no_show';

export type PaymentStatus =
  | 'pending'
  | 'processing'
  | 'succeeded'
  | 'failed'
  | 'cancelled'
  | 'refunded'
  | 'partially_refunded';

export interface NamedRef {
  id: string;
  name: string;
}

export interface BookingSummary {
  booking_id: string;
  status: BookingStatus;
  starts_at: string;
  ends_at: string;
  price_cents: number;
  deposit_cents: number;
  currency: string;
  service: NamedRef;
  practitioner: NamedRef;
}

export interface BookingPayment {
  payment_id: string;
  status: PaymentStatus;
  amount_cents: number;
  currency: string;
  payment_type: string;
  provider: string;
  paid_at: string | null;
  created_at: string;
}

export interface BookingIntakeForm {
  intake_form_id: string;
  status: 'pending' | 'in_progress' | 'completed';
  is_medical: boolean;
  template_name: string;
}

export interface BookingDetail {
  booking_id: string;
  status: BookingStatus;
  starts_at: string;
  ends_at: string;
  price_cents: number;
  deposit_cents: number;
  currency: string;
  notes: string | null;
  service: NamedRef & { duration_minutes: number };
  practitioner: NamedRef;
  can_cancel: boolean;
  can_reschedule: boolean;
  payments: BookingPayment[];
  intake_forms: BookingIntakeForm[];
}

export interface PaymentRow {
  payment_id: string;
  booking_id: string;
  status: PaymentStatus;
  amount_cents: number;
  currency: string;
  payment_type: string;
  provider: string;
  paid_at: string | null;
  created_at: string;
  service_name: string;
  starts_at: string;
}

export interface IntakeFormRow {
  intake_form_id: string;
  booking_id: string;
  status: 'pending' | 'in_progress' | 'completed';
  is_medical: boolean;
  template_name: string;
  starts_at: string;
  service_name: string;
}

export interface ClientProfile {
  profile_id: string;
  role: string;
  email: string;
  full_name: string;
  phone: string | null;
  avatar_url: string | null;
  client: {
    client_id: string;
    date_of_birth: string | null;
    emergency_contact_name: string | null;
    emergency_contact_phone: string | null;
    marketing_opt_in: boolean;
  } | null;
}
