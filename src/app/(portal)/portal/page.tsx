import Link from 'next/link';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { BookingCard } from '@/features/portal/components/booking-card';
import { EmptyState } from '@/features/portal/components/empty-state';
import {
  listMyBookings,
  listMyIntakeForms,
} from '@/features/portal/actions/portal';

export default async function DashboardPage() {
  const [bookingsResult, formsResult] = await Promise.all([
    listMyBookings('upcoming'),
    listMyIntakeForms(),
  ]);

  const upcoming = bookingsResult.ok ? bookingsResult.data : [];
  const pendingForms = formsResult.ok
    ? formsResult.data.filter((f) => f.status !== 'completed')
    : [];

  return (
    <div className="space-y-8">
      <section className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Upcoming appointments</CardTitle>
          </CardHeader>
          <CardContent className="text-3xl font-semibold">
            {upcoming.length}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Forms to complete</CardTitle>
          </CardHeader>
          <CardContent className="text-3xl font-semibold">
            {pendingForms.length}
          </CardContent>
        </Card>
      </section>

      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Next appointments</h2>
          <Link
            href="/portal/bookings"
            className="text-sm text-primary hover:underline"
          >
            View all
          </Link>
        </div>

        {upcoming.length === 0 ? (
          <EmptyState
            title="No upcoming appointments"
            description="When you book, your appointments will appear here."
          />
        ) : (
          <div className="grid gap-4">
            {upcoming.slice(0, 3).map((b) => (
              <BookingCard key={b.booking_id} booking={b} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
