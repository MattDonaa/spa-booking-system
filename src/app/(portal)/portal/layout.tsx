import type { Metadata } from 'next';

import { ThemeToggle } from '@/components/theme-toggle';
import { PortalNav } from '@/features/portal/components/portal-nav';
import { SignOutButton } from '@/features/portal/components/sign-out-button';
import { getMyProfile } from '@/features/portal/actions/portal';

export const metadata: Metadata = {
  title: { default: 'My Portal', template: '%s | My Portal' },
};

export default async function PortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const profile = await getMyProfile();
  const name = profile.ok ? profile.data.full_name : 'there';

  return (
    <div className="min-h-dvh">
      <header className="border-b">
        <div className="container flex h-16 items-center justify-between gap-4">
          <span className="text-lg font-semibold tracking-tight">Serenity</span>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <SignOutButton />
          </div>
        </div>
        <div className="container pb-3">
          <PortalNav />
        </div>
      </header>

      <div className="container py-8">
        <p className="mb-6 text-sm text-muted-foreground">
          Welcome back,{' '}
          <span className="font-medium text-foreground">{name}</span>.
        </p>
        {children}
      </div>
    </div>
  );
}
