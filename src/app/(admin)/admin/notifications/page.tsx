import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDateTime } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { RetryButton } from '@/features/admin/components/retry-button';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { adminListNotifications } from '@/features/admin/actions/admin';

export const metadata = { title: 'Notifications' };

export default async function NotificationsPage() {
  const result = await adminListNotifications();
  const rows = result.ok ? result.data : [];

  return (
    <div>
      <PageHeader
        title="Notification centre"
        description="Outbound queue and delivery status."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No notifications.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Created</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Channel</TableHead>
              <TableHead>Attempts</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Last error</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((n) => (
              <TableRow key={n.id}>
                <TableCell>{formatDateTime(n.created_at)}</TableCell>
                <TableCell>{n.notification_type}</TableCell>
                <TableCell className="capitalize">{n.channel}</TableCell>
                <TableCell>
                  {n.attempts}/{n.max_attempts}
                </TableCell>
                <TableCell>
                  <StatusBadge status={n.status} kind="intake" />
                </TableCell>
                <TableCell className="max-w-48 truncate text-xs text-muted-foreground">
                  {n.last_error ?? '—'}
                </TableCell>
                <TableCell className="text-right">
                  {n.status === 'failed' && <RetryButton id={n.id} />}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
