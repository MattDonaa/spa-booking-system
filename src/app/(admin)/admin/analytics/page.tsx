import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDate, formatMoney, humanizeStatus } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import {
  BarList,
  ColumnChart,
  StatTile,
} from '@/features/admin/components/charts';
import {
  analyticsClients,
  analyticsOverview,
  analyticsPractitioners,
  analyticsServices,
} from '@/features/admin/actions/analytics';

export const metadata = { title: 'Analytics' };

export default async function AnalyticsPage() {
  const [overviewR, servicesR, practitionersR, clientsR] = await Promise.all([
    analyticsOverview(),
    analyticsServices(),
    analyticsPractitioners(),
    analyticsClients(),
  ]);

  if (!overviewR.ok) {
    return (
      <div>
        <PageHeader title="Analytics" />
        <p className="text-sm text-destructive">{overviewR.error.message}</p>
      </div>
    );
  }

  const o = overviewR.data;
  const services = servicesR.ok ? servicesR.data : [];
  const practitioners = practitionersR.ok ? practitionersR.data : [];
  const clients = clientsR.ok ? clientsR.data : null;

  return (
    <div className="space-y-8">
      <PageHeader
        title="Analytics"
        description={`${formatDate(o.range.from)} – ${formatDate(o.range.to)}`}
      />

      {/* KPI tiles */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile label="Revenue" value={formatMoney(o.kpis.revenue_cents)} />
        <StatTile label="Refunds" value={formatMoney(o.kpis.refunds_cents)} />
        <StatTile
          label="Avg booking value"
          value={formatMoney(o.kpis.avg_booking_value_cents)}
        />
        <StatTile
          label="Conversion"
          value={`${o.kpis.conversion_rate_pct}%`}
          hint={`${o.kpis.bookings_created} bookings created`}
        />
        <StatTile label="Completed" value={String(o.kpis.bookings_completed)} />
        <StatTile label="No-shows" value={String(o.kpis.no_shows)} />
        <StatTile label="Cancellations" value={String(o.kpis.cancellations)} />
        <StatTile
          label="Abandoned"
          value={String(o.kpis.abandoned)}
          hint="Expired holds"
        />
      </div>

      {/* Revenue trend */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Daily revenue</CardTitle>
        </CardHeader>
        <CardContent>
          <ColumnChart
            data={o.revenue_series.map((r) => ({
              label: formatDate(r.day),
              value: r.revenue_cents,
            }))}
            formatValue={(v) => formatMoney(v)}
          />
        </CardContent>
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Popular treatments */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Popular treatments</CardTitle>
          </CardHeader>
          <CardContent>
            <BarList
              items={services.slice(0, 8).map((s) => ({
                label: s.service_name,
                value: s.bookings,
                display: `${s.bookings} · ${formatMoney(s.revenue_cents)}`,
              }))}
            />
          </CardContent>
        </Card>

        {/* Booking status breakdown */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Booking outcomes</CardTitle>
          </CardHeader>
          <CardContent>
            <BarList
              items={o.status_breakdown.map((s) => ({
                label: humanizeStatus(s.status),
                value: s.count,
              }))}
            />
          </CardContent>
        </Card>
      </div>

      {/* Practitioner utilisation */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Practitioner utilisation</CardTitle>
        </CardHeader>
        <CardContent>
          {practitioners.length === 0 ? (
            <p className="text-sm text-muted-foreground">No data.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Practitioner</TableHead>
                  <TableHead className="text-right">Bookings</TableHead>
                  <TableHead className="text-right">Utilisation</TableHead>
                  <TableHead className="text-right">Revenue</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {practitioners.map((p) => (
                  <TableRow key={p.practitioner_name}>
                    <TableCell className="font-medium">
                      {p.practitioner_name}
                    </TableCell>
                    <TableCell className="text-right">{p.bookings}</TableCell>
                    <TableCell className="text-right">
                      {p.utilisation_pct}%
                    </TableCell>
                    <TableCell className="text-right">
                      {formatMoney(p.revenue_cents)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Client lifetime value */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Client lifetime value</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <StatTile
            label="Average lifetime value"
            value={formatMoney(clients?.average_ltv_cents ?? 0)}
          />
          <BarList
            items={(clients?.top ?? []).map((c) => ({
              label: c.client_name,
              value: c.total_cents,
              display: `${formatMoney(c.total_cents)} · ${c.visits} visits`,
            }))}
          />
        </CardContent>
      </Card>
    </div>
  );
}
