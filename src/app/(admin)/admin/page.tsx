import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatMoney } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { adminDashboard } from '@/features/admin/actions/admin';

export default async function AdminDashboardPage() {
  const result = await adminDashboard();
  const m = result.ok ? result.data : null;

  const cards = m
    ? [
        { label: "Today's bookings", value: String(m.today_bookings) },
        { label: 'Upcoming bookings', value: String(m.upcoming_bookings) },
        { label: 'Pending payments', value: String(m.pending_payments) },
        {
          label: 'Revenue (month)',
          value: formatMoney(m.revenue_month_cents),
        },
        {
          label: 'Active practitioners',
          value: String(m.active_practitioners),
        },
        { label: 'Pending forms', value: String(m.pending_forms) },
      ]
    : [];

  return (
    <div>
      <PageHeader title="Dashboard" description="Operational overview." />
      {!m ? (
        <p className="text-sm text-destructive">
          {result.ok ? 'No data.' : result.error.message}
        </p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {cards.map((c) => (
            <Card key={c.label}>
              <CardHeader>
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {c.label}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-3xl font-semibold">
                {c.value}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
