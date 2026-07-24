import { Card, CardContent } from '@/components/ui/card';
import { formatDate, formatMoney } from '@/lib/format';
import { PageHeader } from '@/features/admin/components/page-header';
import { StatusBadge } from '@/features/portal/components/status-badge';
import { adminListBookings } from '@/features/admin/actions/admin';
import type { AdminBookingRow } from '@/features/admin/types';

export const metadata = { title: 'Calendar' };

function timeOf(iso: string): string {
  return new Intl.DateTimeFormat('en-ZA', { timeStyle: 'short' }).format(
    new Date(iso),
  );
}

export default async function CalendarPage() {
  const now = new Date();
  const to = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
  const result = await adminListBookings(now.toISOString(), to.toISOString());
  const rows = result.ok ? result.data : [];

  // Group by calendar day.
  const groups = new Map<string, AdminBookingRow[]>();
  for (const b of rows) {
    const day = new Date(b.starts_at).toDateString();
    const list = groups.get(day) ?? [];
    list.push(b);
    groups.set(day, list);
  }

  return (
    <div>
      <PageHeader
        title="Calendar"
        description="Schedule for the next 14 days."
      />
      {groups.size === 0 ? (
        <p className="text-sm text-muted-foreground">No upcoming bookings.</p>
      ) : (
        <div className="space-y-6">
          {[...groups.entries()].map(([day, list]) => (
            <section key={day}>
              <h2 className="mb-2 text-sm font-semibold text-muted-foreground">
                {formatDate(new Date(day))}
              </h2>
              <div className="space-y-2">
                {list.map((b) => (
                  <Card key={b.booking_id}>
                    <CardContent className="flex items-center justify-between gap-4 py-3 text-sm">
                      <div className="flex items-center gap-4">
                        <span className="font-mono">{timeOf(b.starts_at)}</span>
                        <span className="font-medium">{b.service_name}</span>
                        <span className="text-muted-foreground">
                          {b.client_name} · {b.practitioner_name}
                        </span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span>{formatMoney(b.price_cents, b.currency)}</span>
                        <StatusBadge status={b.status} />
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
