import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDateTime, humanizeStatus } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { adminListAuditLogs } from '@/features/admin/actions/admin';

export const metadata = { title: 'Audit' };

export default async function AuditPage() {
  const result = await adminListAuditLogs();
  const rows = result.ok ? result.data : [];

  return (
    <div>
      <PageHeader
        title="Audit log"
        description="The 100 most recent recorded mutations."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No audit entries.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>When</TableHead>
              <TableHead>Action</TableHead>
              <TableHead>Entity</TableHead>
              <TableHead>Entity ID</TableHead>
              <TableHead>Actor</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((a) => (
              <TableRow key={a.id}>
                <TableCell>{formatDateTime(a.created_at)}</TableCell>
                <TableCell>
                  <Badge variant="secondary">{humanizeStatus(a.action)}</Badge>
                </TableCell>
                <TableCell>{a.entity_type}</TableCell>
                <TableCell className="font-mono text-xs">
                  {a.entity_id.slice(0, 8)}
                </TableCell>
                <TableCell className="font-mono text-xs">
                  {a.actor_profile_id
                    ? a.actor_profile_id.slice(0, 8)
                    : 'system'}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
