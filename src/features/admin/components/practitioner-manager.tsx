'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { adminUpdatePractitioner } from '@/features/admin/actions/admin';
import type { AdminPractitioner } from '@/features/admin/types';

export function PractitionerManager({
  practitioners,
}: {
  practitioners: AdminPractitioner[];
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<string | null>(null);
  const [isPending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState({
    title: '',
    bio: '',
    specialties: '',
    isActive: true,
  });

  function beginEdit(p: AdminPractitioner) {
    setError(null);
    setEditing(p.practitioner_id);
    setForm({
      title: p.title ?? '',
      bio: p.bio ?? '',
      specialties: p.specialties.join(', '),
      isActive: p.is_active,
    });
  }

  function save(id: string) {
    setError(null);
    start(async () => {
      const result = await adminUpdatePractitioner({
        practitionerId: id,
        title: form.title || undefined,
        bio: form.bio || undefined,
        specialties: form.specialties
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean),
        isActive: form.isActive,
      });
      if (result.ok) {
        setEditing(null);
        router.refresh();
      } else {
        setError(result.error.message);
      }
    });
  }

  return (
    <div className="space-y-4">
      {practitioners.map((p) => (
        <Card key={p.practitioner_id}>
          <CardHeader className="flex-row items-center justify-between space-y-0">
            <div>
              <CardTitle className="text-base">{p.name}</CardTitle>
              <p className="text-sm text-muted-foreground">{p.email}</p>
            </div>
            <div className="flex items-center gap-3">
              {p.is_active ? (
                <Badge variant="success">Active</Badge>
              ) : (
                <Badge variant="secondary">Inactive</Badge>
              )}
              <Button
                size="sm"
                variant="outline"
                onClick={() =>
                  editing === p.practitioner_id
                    ? setEditing(null)
                    : beginEdit(p)
                }
              >
                {editing === p.practitioner_id ? 'Close' : 'Edit'}
              </Button>
            </div>
          </CardHeader>

          {editing === p.practitioner_id && (
            <CardContent className="space-y-4">
              <div className="space-y-1.5">
                <Label>Title</Label>
                <Input
                  value={form.title}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, title: e.target.value }))
                  }
                />
              </div>
              <div className="space-y-1.5">
                <Label>Bio</Label>
                <Textarea
                  value={form.bio}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, bio: e.target.value }))
                  }
                />
              </div>
              <div className="space-y-1.5">
                <Label>Specialties (comma-separated)</Label>
                <Input
                  value={form.specialties}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, specialties: e.target.value }))
                  }
                />
              </div>
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.isActive}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, isActive: e.target.checked }))
                  }
                  className="size-4"
                />
                Active
              </label>
              <div className="flex items-center gap-3">
                <Button
                  size="sm"
                  onClick={() => save(p.practitioner_id)}
                  disabled={isPending}
                >
                  Save
                </Button>
                {error && (
                  <span className="text-sm text-destructive">{error}</span>
                )}
              </div>
            </CardContent>
          )}
        </Card>
      ))}
    </div>
  );
}
