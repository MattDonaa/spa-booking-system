import Link from 'next/link';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatDateTime, formatMoney } from '@/lib/format';
import { StatusBadge } from '@/features/portal/components/status-badge';
import type { BookingSummary } from '@/features/portal/types';

export function BookingCard({ booking }: { booking: BookingSummary }) {
  return (
    <Link
      href={`/portal/bookings/${booking.booking_id}`}
      className="block rounded-lg outline-none ring-offset-background focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
    >
      <Card className="transition-colors hover:bg-muted/50">
        <CardHeader className="flex-row items-start justify-between gap-4 space-y-0">
          <div>
            <CardTitle className="text-lg">{booking.service.name}</CardTitle>
            <p className="text-sm text-muted-foreground">
              with {booking.practitioner.name}
            </p>
          </div>
          <StatusBadge status={booking.status} />
        </CardHeader>
        <CardContent className="flex items-center justify-between text-sm">
          <span>{formatDateTime(booking.starts_at)}</span>
          <span className="font-medium">
            {formatMoney(booking.price_cents, booking.currency)}
          </span>
        </CardContent>
      </Card>
    </Link>
  );
}
