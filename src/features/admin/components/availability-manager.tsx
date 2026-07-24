'use client';

import { useState, useTransition } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatDateTime } from '@/lib/format';
import {
  adminAddAvailabilityBlock,
  adminListAvailability,
} from '@/features/admin/actions/admin';
import type {
  AdminPractitioner,
  AvailabilityData,
} from '@/features/admin/types';

const DAYS = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

export function AvailabilityManager({
  practitioners,
}: {
  practitioners: AdminPractitioner[];
}) {
  const [selected, setSelected] = useState<string>('');
  const [data, setData] = useState<AvailabilityData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, start] = useTransition();
  const [block, setBlock] = useState({ startsAt: '', endsAt: '', reason: '' });

  function load(practitionerId: string) {
    setSelected(practitionerId);
    setData(null);
    setError(null);
    if (!practitionerId) return;
    start(async () => {
      const result = await adminListAvailability(practitionerId);
      if (result.ok) setData(result.data);
      else setError(result.error.message);
    });
  }

  function addBlock() {
    if (!selected || !block.startsAt || !block.endsAt) {
      setError('Select a practitioner and a start/end time.');
      return;
    }
    setError(null);
    start(async () => {
      const result = await adminAddAvailabilityBlock({
        practitionerId: selected,
        startsAt: new Date(block.startsAt).toISOString(),
        endsAt: new Date(block.endsAt).toISOString(),
        reason: block.reason || undefined,
      });
      if (result.ok) {
        setBlock({ startsAt: '', endsAt: '', reason: '' });
        const refreshed = await adminListAvailability(selected);
        if (refreshed.ok) setData(refreshed.data);
      } else {
        setError(result.error.message);
      }
    });
  }

  return (
    <div className="space-y-6">
      <div className="max-w-sm space-y-1.5">
        <Label htmlFor="prac">Practitioner</Label>
        <select
          id="prac"
          value={selected}
          onChange={(e) => load(e.target.value)}
          className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
        >
          <option value="">Select a practitioner…</option>
          {practitioners.map((p) => (
            <option key={p.practitioner_id} value={p.practitioner_id}>
              {p.name}
            </option>
          ))}
        </select>
      </div>

      {error && <p className="text-sm text-destructive">{error}</p>}
      {isPending && <p className="text-sm text-muted-foreground">Loading…</p>}

      {data && (
        <div className="grid gap-6 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Weekly schedule</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1 text-sm">
              {data.schedule.length === 0 ? (
                <p className="text-muted-foreground">No working hours set.</p>
              ) : (
                data.schedule.map((s) => (
                  <div key={s.id} className="flex justify-between">
                    <span>{DAYS[s.day_of_week]}</span>
                    <span className="font-mono">
                      {s.start_time.slice(0, 5)}–{s.end_time.slice(0, 5)}
                    </span>
                  </div>
                ))
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Time off &amp; blocks</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm">
              {data.blocks.length === 0 ? (
                <p className="text-muted-foreground">No upcoming blocks.</p>
              ) : (
                data.blocks.map((b) => (
                  <div key={b.id}>
                    <p className="font-medium capitalize">
                      {b.block_type.replace('_', ' ')}
                    </p>
                    <p className="text-muted-foreground">
                      {formatDateTime(b.starts_at)} →{' '}
                      {formatDateTime(b.ends_at)}
                    </p>
                  </div>
                ))
              )}

              <div className="space-y-2 border-t pt-3">
                <Label>Add a block</Label>
                <Input
                  type="datetime-local"
                  value={block.startsAt}
                  onChange={(e) =>
                    setBlock((b) => ({ ...b, startsAt: e.target.value }))
                  }
                />
                <Input
                  type="datetime-local"
                  value={block.endsAt}
                  onChange={(e) =>
                    setBlock((b) => ({ ...b, endsAt: e.target.value }))
                  }
                />
                <Input
                  placeholder="Reason (optional)"
                  value={block.reason}
                  onChange={(e) =>
                    setBlock((b) => ({ ...b, reason: e.target.value }))
                  }
                />
                <Button size="sm" onClick={addBlock} disabled={isPending}>
                  Add block
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
