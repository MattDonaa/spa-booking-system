import Link from 'next/link';

import { Card, CardContent } from '@/components/ui/card';
import { formatDate, formatMoney } from '@/lib/format';
import { EmptyState } from '@/features/portal/components/empty-state';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { listMyPayments } from '@/features/portal/actions/portal';

export const metadata = { title: 'Payments' };

export default async function PaymentsPage() {
  const result = await listMyPayments();
  const payments = result.ok ? result.data : [];

  if (payments.length === 0) {
    return <EmptyState title="No payments yet" />;
  }

  return (
    <div className="space-y-3">
      {payments.map((p) => (
        <Link key={p.payment_id} href={`/portal/payments/${p.payment_id}`}>
          <Card className="transition-colors hover:bg-muted/50">
            <CardContent className="flex items-center justify-between gap-4 py-4">
              <div>
                <p className="font-medium">{p.service_name}</p>
                <p className="text-sm text-muted-foreground">
                  {formatDate(p.created_at)} · {p.payment_type}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span className="font-medium">
                  {formatMoney(p.amount_cents, p.currency)}
                </span>
                <StatusBadge status={p.status} kind="payment" />
              </div>
            </CardContent>
          </Card>
        </Link>
      ))}
    </div>
  );
}
