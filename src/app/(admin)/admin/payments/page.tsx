import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDate, formatMoney } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { adminListPayments } from '@/features/admin/actions/admin';

export const metadata = { title: 'Payments' };

export default async function AdminPaymentsPage() {
  const result = await adminListPayments();
  const rows = result.ok ? result.data : [];

  return (
    <div>
      <PageHeader
        title="Payments"
        description="Payments over the last 30 days."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No payments in range.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Client</TableHead>
              <TableHead>Service</TableHead>
              <TableHead>Provider</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">Amount</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((p) => (
              <TableRow key={p.payment_id}>
                <TableCell>{formatDate(p.created_at)}</TableCell>
                <TableCell>{p.client_name}</TableCell>
                <TableCell>{p.service_name}</TableCell>
                <TableCell className="capitalize">{p.provider}</TableCell>
                <TableCell className="capitalize">{p.payment_type}</TableCell>
                <TableCell>
                  <StatusBadge status={p.status} kind="payment" />
                </TableCell>
                <TableCell className="text-right">
                  {formatMoney(p.amount_cents, p.currency)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
