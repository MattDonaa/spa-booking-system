'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  cancelMyBooking,
  rescheduleMyBooking,
} from '@/features/portal/actions/portal';

interface BookingActionsProps {
  bookingId: string;
  canCancel: boolean;
  canReschedule: boolean;
}

export function BookingActions({
  bookingId,
  canCancel,
  canReschedule,
}: BookingActionsProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [rescheduling, setRescheduling] = useState(false);
  const [newStart, setNewStart] = useState('');

  if (!canCancel && !canReschedule) {
    return (
      <p className="text-sm text-muted-foreground">
        This booking can no longer be changed. Please contact us for assistance.
      </p>
    );
  }

  function handleCancel() {
    setError(null);
    startTransition(async () => {
      const result = await cancelMyBooking(bookingId);
      if (result.ok) {
        router.refresh();
      } else {
        setError(result.error.message);
      }
    });
  }

  function handleReschedule() {
    setError(null);
    if (!newStart) {
      setError('Please choose a new date and time.');
      return;
    }
    // datetime-local yields local time without a zone; convert to ISO.
    const iso = new Date(newStart).toISOString();
    startTransition(async () => {
      const result = await rescheduleMyBooking(bookingId, iso);
      if (result.ok) {
        setRescheduling(false);
        router.refresh();
      } else {
        setError(result.error.message);
      }
    });
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        {canReschedule && (
          <Button
            variant="outline"
            onClick={() => setRescheduling((v) => !v)}
            disabled={isPending}
          >
            Reschedule
          </Button>
        )}
        {canCancel && (
          <Button
            variant="destructive"
            onClick={handleCancel}
            disabled={isPending}
          >
            Cancel booking
          </Button>
        )}
      </div>

      {rescheduling && (
        <div className="space-y-2 rounded-md border p-4">
          <Label htmlFor="new-start">New date &amp; time</Label>
          <Input
            id="new-start"
            type="datetime-local"
            value={newStart}
            onChange={(e) => setNewStart(e.target.value)}
            className="max-w-xs"
          />
          <div>
            <Button onClick={handleReschedule} disabled={isPending} size="sm">
              Confirm new time
            </Button>
          </div>
        </div>
      )}

      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
