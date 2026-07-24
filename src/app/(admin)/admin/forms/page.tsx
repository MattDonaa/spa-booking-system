import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { humanizeStatus } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { adminListTemplates } from '@/features/admin/actions/admin';

export const metadata = { title: 'Forms' };

export default async function AdminFormsPage() {
  const result = await adminListTemplates();
  const rows = result.ok ? result.data : [];

  return (
    <div>
      <PageHeader
        title="Form templates"
        description="Versioned intake and consent templates."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">No templates.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Version</TableHead>
              <TableHead>Fields</TableHead>
              <TableHead>Medical</TableHead>
              <TableHead>Active</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((t) => (
              <TableRow key={t.template_id}>
                <TableCell className="font-medium">{t.name}</TableCell>
                <TableCell>{humanizeStatus(t.form_type)}</TableCell>
                <TableCell>v{t.version}</TableCell>
                <TableCell>{t.field_count}</TableCell>
                <TableCell>
                  {t.is_medical ? (
                    <Badge variant="warning">Medical</Badge>
                  ) : (
                    '—'
                  )}
                </TableCell>
                <TableCell>
                  {t.is_active ? (
                    <Badge variant="success">Active</Badge>
                  ) : (
                    <Badge variant="secondary">Inactive</Badge>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
