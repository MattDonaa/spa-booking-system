import Link from 'next/link';

import { cn } from '@/lib/utils';
import { BookingCard } from '@/features/portal/components/booking-card';
import { EmptyState } from '@/features/portal/components/empty-state';
import { listMyBookings } from '@/features/portal/actions/portal';

export const metadata = { title: 'Bookings' };

type Tab = 'upcoming' | 'past';

export default async function BookingsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const { tab } = await searchParams;
  const active: Tab = tab === 'past' ? 'past' : 'upcoming';

  const result = await listMyBookings(active);
  const bookings = result.ok ? result.data : [];

  return (
    <div className="space-y-6">
      <div className="flex gap-2">
        {(['upcoming', 'past'] as const).map((t) => (
          <Link
            key={t}
            href={`/portal/bookings?tab=${t}`}
            className={cn(
              'rounded-md px-3 py-1.5 text-sm font-medium capitalize',
              active === t
                ? 'bg-secondary text-secondary-foreground'
                : 'text-muted-foreground hover:bg-muted',
            )}
          >
            {t}
          </Link>
        ))}
      </div>

      {bookings.length === 0 ? (
        <EmptyState title={`No ${active} bookings`} />
      ) : (
        <div className="grid gap-4">
          {bookings.map((b) => (
            <BookingCard key={b.booking_id} booking={b} />
          ))}
        </div>
      )}
    </div>
  );
}
