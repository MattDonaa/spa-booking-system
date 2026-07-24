import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { ThemeToggle } from '@/components/theme-toggle';
import { AdminNav } from '@/features/admin/components/admin-nav';
import { SignOutButton } from '@/features/portal/components/sign-out-button';
import { getMyProfile } from '@/features/portal/actions/portal';

export const metadata: Metadata = {
  title: { default: 'Admin', template: '%s | Admin' },
};

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // Middleware guarantees authentication; here we enforce the admin role.
  const profile = await getMyProfile();
  if (!profile.ok || profile.data.role !== 'admin') {
    redirect('/portal');
  }

  return (
    <div className="min-h-dvh">
      <header className="border-b">
        <div className="container flex h-16 items-center justify-between gap-4">
          <span className="text-lg font-semibold tracking-tight">
            Serenity Admin
          </span>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <SignOutButton />
          </div>
        </div>
        <div className="container pb-3">
          <AdminNav />
        </div>
      </header>

      <main className="container py-8">{children}</main>
    </div>
  );
}
