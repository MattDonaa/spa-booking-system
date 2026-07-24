import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatDate, formatMoney } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { adminReports } from '@/features/admin/actions/admin';

export const metadata = { title: 'Reports' };

export default async function ReportsPage() {
  const result = await adminReports();

  if (!result.ok) {
    return (
      <div>
        <PageHeader title="Reports" />
        <p className="text-sm text-destructive">{result.error.message}</p>
      </div>
    );
  }

  const r = result.data;
  const cards = [
    { label: 'Total bookings', value: String(r.bookings_total) },
    { label: 'Completed', value: String(r.bookings_completed) },
    { label: 'Cancelled / no-show', value: String(r.bookings_cancelled) },
    { label: 'Revenue', value: formatMoney(r.revenue_cents) },
    { label: 'Refunds', value: formatMoney(r.refunds_cents) },
  ];

  return (
    <div>
      <PageHeader
        title="Reports"
        description={`${formatDate(r.range.from)} – ${formatDate(r.range.to)}`}
      />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((c) => (
          <Card key={c.label}>
            <CardHeader>
              <CardTitle className="text-sm font-medium text-muted-foreground">
                {c.label}
              </CardTitle>
            </CardHeader>
            <CardContent className="text-2xl font-semibold">
              {c.value}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
