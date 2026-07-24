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
import { formatMoney } from '@/lib/format';
import { adminUpsertService } from '@/features/admin/actions/admin';
import type { AdminService } from '@/features/admin/types';

type Draft = {
  serviceId?: string;
  name: string;
  slug: string;
  durationMinutes: number;
  priceRands: number;
  depositRands: number;
  bufferBeforeMinutes: number;
  bufferAfterMinutes: number;
  requiresRoom: boolean;
  requiresIntake: boolean;
  isActive: boolean;
};

const emptyDraft: Draft = {
  name: '',
  slug: '',
  durationMinutes: 60,
  priceRands: 0,
  depositRands: 0,
  bufferBeforeMinutes: 0,
  bufferAfterMinutes: 0,
  requiresRoom: true,
  requiresIntake: false,
  isActive: true,
};

function toDraft(s: AdminService): Draft {
  return {
    serviceId: s.service_id,
    name: s.name,
    slug: s.slug,
    durationMinutes: s.duration_minutes,
    priceRands: s.price_cents / 100,
    depositRands: s.deposit_cents / 100,
    bufferBeforeMinutes: s.buffer_before_minutes,
    bufferAfterMinutes: s.buffer_after_minutes,
    requiresRoom: s.requires_room,
    requiresIntake: s.requires_intake,
    isActive: s.is_active,
  };
}

export function ServiceManager({ services }: { services: AdminService[] }) {
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
      const result = await adminUpsertService({
        serviceId: draft.serviceId,
        name: draft.name,
        slug: draft.slug,
        durationMinutes: draft.durationMinutes,
        priceCents: Math.round(draft.priceRands * 100),
        depositCents: Math.round(draft.depositRands * 100),
        bufferBeforeMinutes: draft.bufferBeforeMinutes,
        bufferAfterMinutes: draft.bufferAfterMinutes,
        requiresRoom: draft.requiresRoom,
        requiresIntake: draft.requiresIntake,
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
        <Button onClick={() => setDraft({ ...emptyDraft })}>New service</Button>
      </div>

      {draft && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              {draft.serviceId ? 'Edit service' : 'New service'}
            </CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <Field label="Name">
              <Input
                value={draft.name}
                onChange={(e) => set('name', e.target.value)}
              />
            </Field>
            <Field label="Slug">
              <Input
                value={draft.slug}
                onChange={(e) => set('slug', e.target.value)}
              />
            </Field>
            <Field label="Duration (min)">
              <Input
                type="number"
                value={draft.durationMinutes}
                onChange={(e) => set('durationMinutes', Number(e.target.value))}
              />
            </Field>
            <Field label="Price (ZAR)">
              <Input
                type="number"
                value={draft.priceRands}
                onChange={(e) => set('priceRands', Number(e.target.value))}
              />
            </Field>
            <Field label="Deposit (ZAR)">
              <Input
                type="number"
                value={draft.depositRands}
                onChange={(e) => set('depositRands', Number(e.target.value))}
              />
            </Field>
            <Field label="Buffer before (min)">
              <Input
                type="number"
                value={draft.bufferBeforeMinutes}
                onChange={(e) =>
                  set('bufferBeforeMinutes', Number(e.target.value))
                }
              />
            </Field>
            <Field label="Buffer after (min)">
              <Input
                type="number"
                value={draft.bufferAfterMinutes}
                onChange={(e) =>
                  set('bufferAfterMinutes', Number(e.target.value))
                }
              />
            </Field>

            <div className="flex flex-col justify-end gap-2">
              <Checkbox
                label="Requires room"
                checked={draft.requiresRoom}
                onChange={(v) => set('requiresRoom', v)}
              />
              <Checkbox
                label="Requires intake"
                checked={draft.requiresIntake}
                onChange={(v) => set('requiresIntake', v)}
              />
              <Checkbox
                label="Active"
                checked={draft.isActive}
                onChange={(v) => set('isActive', v)}
              />
            </div>

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
            <TableHead>Duration</TableHead>
            <TableHead>Price</TableHead>
            <TableHead>Status</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {services.map((s) => (
            <TableRow key={s.service_id}>
              <TableCell className="font-medium">{s.name}</TableCell>
              <TableCell>{s.duration_minutes} min</TableCell>
              <TableCell>{formatMoney(s.price_cents, s.currency)}</TableCell>
              <TableCell>
                {s.is_active ? (
                  <Badge variant="success">Active</Badge>
                ) : (
                  <Badge variant="secondary">Inactive</Badge>
                )}
              </TableCell>
              <TableCell className="text-right">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setDraft(toDraft(s))}
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

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
    </div>
  );
}

function Checkbox({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 text-sm">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="size-4"
      />
      {label}
    </label>
  );
}
