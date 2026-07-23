import Link from 'next/link';
import { notFound } from 'next/navigation';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatDate, formatDateTime, formatMoney } from '@/lib/format';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { listMyPayments } from '@/features/portal/actions/portal';

export const metadata = { title: 'Invoice' };

export default async function InvoicePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const result = await listMyPayments();
  const payment = result.ok
    ? result.data.find((p) => p.payment_id === id)
    : undefined;

  if (!payment) notFound();

  return (
    <div className="mx-auto max-w-xl">
      <Card>
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle>Invoice</CardTitle>
          <StatusBadge status={payment.status} kind="payment" />
        </CardHeader>
        <CardContent className="space-y-4 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Invoice reference</span>
            <span className="font-mono">{payment.payment_id.slice(0, 8)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Date</span>
            <span>{formatDate(payment.created_at)}</span>
          </div>

          <hr className="border-border" />

          <div className="flex justify-between">
            <span>{payment.service_name}</span>
            <span>{formatMoney(payment.amount_cents, payment.currency)}</span>
          </div>
          <p className="text-xs text-muted-foreground">
            Appointment: {formatDateTime(payment.starts_at)}
          </p>

          <hr className="border-border" />

          <div className="flex justify-between text-base font-semibold">
            <span>Total ({payment.payment_type})</span>
            <span>{formatMoney(payment.amount_cents, payment.currency)}</span>
          </div>
          {payment.paid_at && (
            <p className="text-xs text-muted-foreground">
              Paid on {formatDateTime(payment.paid_at)} via {payment.provider}.
            </p>
          )}

          <Link
            href={`/portal/bookings/${payment.booking_id}`}
            className="inline-block text-sm text-primary hover:underline"
          >
            View booking
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}
