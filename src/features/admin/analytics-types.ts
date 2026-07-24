/** Analytics read-model types. */

export interface AnalyticsOverview {
  range: { from: string; to: string };
  kpis: {
    revenue_cents: number;
    refunds_cents: number;
    bookings_created: number;
    bookings_completed: number;
    no_shows: number;
    cancellations: number;
    abandoned: number;
    avg_booking_value_cents: number;
    conversion_rate_pct: number;
  };
  revenue_series: { day: string; revenue_cents: number }[];
  status_breakdown: { status: string; count: number }[];
}

export interface ServiceStat {
  service_name: string;
  bookings: number;
  revenue_cents: number;
}

export interface PractitionerStat {
  practitioner_name: string;
  bookings: number;
  booked_minutes: number;
  available_minutes: number;
  utilisation_pct: number;
  revenue_cents: number;
}

export interface ClientAnalytics {
  average_ltv_cents: number;
  top: { client_name: string; visits: number; total_cents: number }[];
}
