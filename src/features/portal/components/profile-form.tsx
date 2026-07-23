'use client';

import { useState, useTransition } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { updateMyProfile } from '@/features/portal/actions/portal';
import type { ClientProfile } from '@/features/portal/types';

export function ProfileForm({ profile }: { profile: ClientProfile }) {
  const [isPending, startTransition] = useTransition();
  const [status, setStatus] = useState<'idle' | 'saved' | 'error'>('idle');
  const [message, setMessage] = useState<string | null>(null);

  const [form, setForm] = useState({
    fullName: profile.full_name,
    phone: profile.phone ?? '',
    dateOfBirth: profile.client?.date_of_birth ?? '',
    emergencyContactName: profile.client?.emergency_contact_name ?? '',
    emergencyContactPhone: profile.client?.emergency_contact_phone ?? '',
    marketingOptIn: profile.client?.marketing_opt_in ?? false,
  });

  function set<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('idle');
    setMessage(null);
    startTransition(async () => {
      const result = await updateMyProfile(form);
      if (result.ok) {
        setStatus('saved');
        setMessage('Profile updated.');
      } else {
        setStatus('error');
        setMessage(result.error.message);
      }
    });
  }

  return (
    <form onSubmit={handleSubmit} className="max-w-lg space-y-5">
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input id="email" value={profile.email} disabled />
      </div>

      <div className="space-y-2">
        <Label htmlFor="full_name">Full name</Label>
        <Input
          id="full_name"
          value={form.fullName}
          onChange={(e) => set('fullName', e.target.value)}
          required
        />
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="phone">Phone</Label>
          <Input
            id="phone"
            value={form.phone}
            onChange={(e) => set('phone', e.target.value)}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="dob">Date of birth</Label>
          <Input
            id="dob"
            type="date"
            value={form.dateOfBirth}
            onChange={(e) => set('dateOfBirth', e.target.value)}
          />
        </div>
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="ec_name">Emergency contact</Label>
          <Input
            id="ec_name"
            value={form.emergencyContactName}
            onChange={(e) => set('emergencyContactName', e.target.value)}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="ec_phone">Emergency contact phone</Label>
          <Input
            id="ec_phone"
            value={form.emergencyContactPhone}
            onChange={(e) => set('emergencyContactPhone', e.target.value)}
          />
        </div>
      </div>

      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={form.marketingOptIn}
          onChange={(e) => set('marketingOptIn', e.target.checked)}
          className="size-4"
        />
        Send me offers and news
      </label>

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={isPending}>
          Save changes
        </Button>
        {message && (
          <span
            className={
              status === 'error'
                ? 'text-sm text-destructive'
                : 'text-sm text-primary'
            }
            role="status"
          >
            {message}
          </span>
        )}
      </div>
    </form>
  );
}
