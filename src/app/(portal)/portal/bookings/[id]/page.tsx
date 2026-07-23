import Link from 'next/link';
import { notFound } from 'next/navigation';

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { formatDateTime, formatMoney } from '@/lib/format';
import { BookingActions } from '@/features/portal/components/booking-actions';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { getMyBooking } from '@/features/portal/actions/portal';

export const metadata = { title: 'Booking' };

export default async function BookingDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const result = await getMyBooking(id);

  if (!result.ok) {
    if (
      result.error.code === 'NOT_FOUND' ||
      result.error.code === 'FORBIDDEN'
    ) {
      notFound();
    }
    return <p className="text-sm text-destructive">{result.error.message}</p>;
  }

  const b = result.data;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">{b.service.name}</h1>
          <p className="text-muted-foreground">with {b.practitioner.name}</p>
        </div>
        <StatusBadge status={b.status} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Appointment</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <Row label="When" value={formatDateTime(b.starts_at)} />
          <Row label="Duration" value={`${b.service.duration_minutes} min`} />
          <Row label="Price" value={formatMoney(b.price_cents, b.currency)} />
          <Row
            label="Deposit"
            value={formatMoney(b.deposit_cents, b.currency)}
          />
          {b.notes && <Row label="Notes" value={b.notes} />}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Intake forms</CardTitle>
          <CardDescription>
            Complete required forms before your visit.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {b.intake_forms.length === 0 ? (
            <p className="text-muted-foreground">No forms required.</p>
          ) : (
            b.intake_forms.map((f) => (
              <div
                key={f.intake_form_id}
                className="flex items-center justify-between"
              >
                <Link
                  href={`/portal/forms/${f.intake_form_id}`}
                  className="text-primary hover:underline"
                >
                  {f.template_name}
                </Link>
                <StatusBadge status={f.status} kind="intake" />
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Payments</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {b.payments.length === 0 ? (
            <p className="text-muted-foreground">No payments yet.</p>
          ) : (
            b.payments.map((p) => (
              <div
                key={p.payment_id}
                className="flex items-center justify-between"
              >
                <Link
                  href={`/portal/payments/${p.payment_id}`}
                  className="text-primary hover:underline"
                >
                  {formatMoney(p.amount_cents, p.currency)} · {p.payment_type}
                </Link>
                <StatusBadge status={p.status} kind="payment" />
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Manage</CardTitle>
        </CardHeader>
        <CardContent>
          <BookingActions
            bookingId={b.booking_id}
            canCancel={b.can_cancel}
            canReschedule={b.can_reschedule}
          />
        </CardContent>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right font-medium">{value}</span>
    </div>
  );
}
