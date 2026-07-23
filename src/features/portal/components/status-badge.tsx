import { Badge, type BadgeProps } from '@/components/ui/badge';
import { humanizeStatus } from '@/lib/format';

const BOOKING_VARIANT: Record<string, BadgeProps['variant']> = {
  pending_hold: 'warning',
  pending_payment: 'warning',
  pending_intake: 'warning',
  confirmed: 'success',
  checked_in: 'success',
  in_progress: 'success',
  completed: 'secondary',
  expired: 'destructive',
  cancelled: 'destructive',
  refunded: 'secondary',
  no_show: 'destructive',
};

const PAYMENT_VARIANT: Record<string, BadgeProps['variant']> = {
  pending: 'warning',
  processing: 'warning',
  succeeded: 'success',
  failed: 'destructive',
  cancelled: 'destructive',
  refunded: 'secondary',
  partially_refunded: 'secondary',
};

export function StatusBadge({
  status,
  kind = 'booking',
}: {
  status: string;
  kind?: 'booking' | 'payment' | 'intake';
}) {
  const map = kind === 'payment' ? PAYMENT_VARIANT : BOOKING_VARIANT;
  const variant =
    kind === 'intake'
      ? status === 'completed'
        ? 'success'
        : 'warning'
      : (map[status] ?? 'secondary');
  return <Badge variant={variant}>{humanizeStatus(status)}</Badge>;
}
