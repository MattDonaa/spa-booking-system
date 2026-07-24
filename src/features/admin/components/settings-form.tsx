'use client';

import { useState, useTransition } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { updateBusinessSettings } from '@/features/admin/actions/admin';
import type { BusinessSettings } from '@/features/admin/types';

export function SettingsForm({ settings }: { settings: BusinessSettings }) {
  const [form, setForm] = useState<BusinessSettings>(settings);
  const [isPending, start] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null,
  );

  function set<K extends keyof BusinessSettings>(k: K, v: BusinessSettings[K]) {
    setForm((f) => ({ ...f, [k]: v }));
  }

  function num(v: string): number {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  function save(e: React.FormEvent) {
    e.preventDefault();
    setMessage(null);
    start(async () => {
      const result = await updateBusinessSettings(form);
      setMessage(
        result.ok
          ? { ok: true, text: 'Settings saved.' }
          : { ok: false, text: result.error.message },
      );
    });
  }

  return (
    <form onSubmit={save} className="max-w-2xl space-y-5">
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Business name">
          <Input
            value={form.business_name}
            onChange={(e) => set('business_name', e.target.value)}
          />
        </Field>
        <Field label="Timezone">
          <Input
            value={form.timezone}
            onChange={(e) => set('timezone', e.target.value)}
          />
        </Field>
        <Field label="Currency">
          <Input
            value={form.currency}
            maxLength={3}
            onChange={(e) => set('currency', e.target.value.toUpperCase())}
          />
        </Field>
        <Field label="Default deposit (%)">
          <Input
            type="number"
            value={form.default_deposit_percentage}
            onChange={(e) =>
              set('default_deposit_percentage', num(e.target.value))
            }
          />
        </Field>
        <Field label="Hold duration (min)">
          <Input
            type="number"
            value={form.hold_duration_minutes}
            onChange={(e) => set('hold_duration_minutes', num(e.target.value))}
          />
        </Field>
        <Field label="Min booking lead (min)">
          <Input
            type="number"
            value={form.min_booking_lead_minutes}
            onChange={(e) =>
              set('min_booking_lead_minutes', num(e.target.value))
            }
          />
        </Field>
        <Field label="Max booking window (days)">
          <Input
            type="number"
            value={form.max_booking_lead_days}
            onChange={(e) => set('max_booking_lead_days', num(e.target.value))}
          />
        </Field>
        <Field label="Cancellation window (hours)">
          <Input
            type="number"
            value={form.cancellation_window_hours}
            onChange={(e) =>
              set('cancellation_window_hours', num(e.target.value))
            }
          />
        </Field>
        <Field label="Contact email">
          <Input
            value={form.contact_email ?? ''}
            onChange={(e) => set('contact_email', e.target.value)}
          />
        </Field>
        <Field label="Contact phone">
          <Input
            value={form.contact_phone ?? ''}
            onChange={(e) => set('contact_phone', e.target.value)}
          />
        </Field>
      </div>

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={isPending}>
          Save settings
        </Button>
        {message && (
          <span
            className={
              message.ok ? 'text-sm text-primary' : 'text-sm text-destructive'
            }
          >
            {message.text}
          </span>
        )}
      </div>
    </form>
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
