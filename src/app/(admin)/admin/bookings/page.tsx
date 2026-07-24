import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDateTime, formatMoney } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { adminListBookings } from '@/features/admin/actions/admin';

export const metadata = { title: 'Bookings' };

export default async function AdminBookingsPage() {
  const result = await adminListBookings();
  const rows = result.ok ? result.data : [];

  return (
    <div>
      <PageHeader
        title="Bookings"
        description="Bookings from the last 7 days to the next 30."
      />
      {rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No bookings in range.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>When</TableHead>
              <TableHead>Client</TableHead>
              <TableHead>Service</TableHead>
              <TableHead>Practitioner</TableHead>
              <TableHead>Room</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">Price</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((b) => (
              <TableRow key={b.booking_id}>
                <TableCell>{formatDateTime(b.starts_at)}</TableCell>
                <TableCell>{b.client_name}</TableCell>
                <TableCell>{b.service_name}</TableCell>
                <TableCell>{b.practitioner_name}</TableCell>
                <TableCell>{b.room_name ?? '—'}</TableCell>
                <TableCell>
                  <StatusBadge status={b.status} />
                </TableCell>
                <TableCell className="text-right">
                  {formatMoney(b.price_cents, b.currency)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
