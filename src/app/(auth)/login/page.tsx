import type { Metadata } from 'next';

import { AuthForm } from '@/features/auth/components/auth-form';

export const metadata: Metadata = { title: 'Sign in' };

export default function LoginPage() {
  return (
    <main className="flex min-h-dvh items-center justify-center px-4 py-12">
      <AuthForm mode="signin" />
    </main>
  );
}
