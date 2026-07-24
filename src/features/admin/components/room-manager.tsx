'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { adminUpsertRoom } from '@/features/admin/actions/admin';
import type { AdminRoom } from '@/features/admin/types';

type Draft = {
  roomId?: string;
  name: string;
  description: string;
  capacity: number;
  features: string;
  isActive: boolean;
};

const emptyDraft: Draft = {
  name: '',
  description: '',
  capacity: 1,
  features: '',
  isActive: true,
};

export function RoomManager({ rooms }: { rooms: AdminRoom[] }) {
  const router = useRouter();
  const [draft, setDraft] = useState<Draft | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, start] = useTransition();

  function set<K extends keyof Draft>(k: K, v: Draft[K]) {
    setDraft((d) => (d ? { ...d, [k]: v } : d));
  }

  function save() {
    if (!draft) return;
    setError(null);
    start(async () => {
      const result = await adminUpsertRoom({
        roomId: draft.roomId,
        name: draft.name,
        description: draft.description || undefined,
        capacity: draft.capacity,
        features: draft.features
          .split(',')
          .map((f) => f.trim())
          .filter(Boolean),
        isActive: draft.isActive,
      });
      if (result.ok) {
        setDraft(null);
        router.refresh();
      } else {
        setError(result.error.message);
      }
    });
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-end">
        <Button onClick={() => setDraft({ ...emptyDraft })}>New room</Button>
      </div>

      {draft && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              {draft.roomId ? 'Edit room' : 'New room'}
            </CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input
                value={draft.name}
                onChange={(e) => set('name', e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Capacity</Label>
              <Input
                type="number"
                value={draft.capacity}
                onChange={(e) => set('capacity', Number(e.target.value))}
              />
            </div>
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Description</Label>
              <Input
                value={draft.description}
                onChange={(e) => set('description', e.target.value)}
              />
            </div>
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Features (comma-separated)</Label>
              <Input
                value={draft.features}
                onChange={(e) => set('features', e.target.value)}
              />
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={draft.isActive}
                onChange={(e) => set('isActive', e.target.checked)}
                className="size-4"
              />
              Active
            </label>
            <div className="col-span-full flex items-center gap-3">
              <Button onClick={save} disabled={isPending}>
                Save
              </Button>
              <Button variant="ghost" onClick={() => setDraft(null)}>
                Cancel
              </Button>
              {error && (
                <span className="text-sm text-destructive">{error}</span>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Capacity</TableHead>
            <TableHead>Features</TableHead>
            <TableHead>Status</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {rooms.map((r) => (
            <TableRow key={r.room_id}>
              <TableCell className="font-medium">{r.name}</TableCell>
              <TableCell>{r.capacity}</TableCell>
              <TableCell>{r.features.join(', ') || '—'}</TableCell>
              <TableCell>
                {r.is_active ? (
                  <Badge variant="success">Active</Badge>
                ) : (
                  <Badge variant="secondary">Inactive</Badge>
                )}
              </TableCell>
              <TableCell className="text-right">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    setDraft({
                      roomId: r.room_id,
                      name: r.name,
                      description: r.description ?? '',
                      capacity: r.capacity,
                      features: r.features.join(', '),
                      isActive: r.is_active,
                    })
                  }
                >
                  Edit
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
