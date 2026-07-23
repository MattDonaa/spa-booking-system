'use client';

import { LogOut } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { signOut } from '@/features/auth/actions/auth';

export function SignOutButton() {
  return (
    <form action={signOut}>
      <Button type="submit" variant="ghost" size="sm">
        <LogOut className="size-4" aria-hidden />
        Sign out
      </Button>
    </form>
  );
}
