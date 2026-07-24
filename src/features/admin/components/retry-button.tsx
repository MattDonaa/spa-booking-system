'use client';

import { useRouter } from 'next/navigation';
import { useTransition } from 'react';

import { Button } from '@/components/ui/button';
import { adminRetryNotification } from '@/features/admin/actions/admin';

export function RetryButton({ id }: { id: string }) {
  const router = useRouter();
  const [isPending, start] = useTransition();

  return (
    <Button
      size="sm"
      variant="outline"
      disabled={isPending}
      onClick={() =>
        start(async () => {
          await adminRetryNotification(id);
          router.refresh();
        })
      }
    >
      Retry
    </Button>
  );
}
