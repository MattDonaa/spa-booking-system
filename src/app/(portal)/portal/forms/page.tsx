import Link from 'next/link';

import { Card, CardContent } from '@/components/ui/card';
import { formatDateTime } from '@/lib/format';
import { EmptyState } from '@/features/portal/components/empty-state';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { listMyIntakeForms } from '@/features/portal/actions/portal';

export const metadata = { title: 'Forms' };

export default async function FormsPage() {
  const result = await listMyIntakeForms();
  const forms = result.ok ? result.data : [];

  if (forms.length === 0) {
    return (
      <EmptyState
        title="No forms"
        description="Forms for your bookings appear here."
      />
    );
  }

  return (
    <div className="space-y-3">
      {forms.map((f) => (
        <Link key={f.intake_form_id} href={`/portal/forms/${f.intake_form_id}`}>
          <Card className="transition-colors hover:bg-muted/50">
            <CardContent className="flex items-center justify-between gap-4 py-4">
              <div>
                <p className="font-medium">{f.template_name}</p>
                <p className="text-sm text-muted-foreground">
                  {f.service_name} · {formatDateTime(f.starts_at)}
                </p>
              </div>
              <StatusBadge status={f.status} kind="intake" />
            </CardContent>
          </Card>
        </Link>
      ))}
    </div>
  );
}
