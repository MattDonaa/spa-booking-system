'use server';

import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';
import { logger } from '@/lib/logger';

export interface AuthActionState {
  error?: string;
  message?: string;
}

/** Sign in with email and password, then enter the portal. */
export async function signIn(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');

  if (!email || !password) {
    return { error: 'Email and password are required.' };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    return { error: 'Invalid email or password.' };
  }

  redirect('/portal');
}

/** Register a new client account. */
export async function signUp(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const fullName = String(formData.get('full_name') ?? '').trim();

  if (!email || !password || !fullName) {
    return { error: 'All fields are required.' };
  }
  if (password.length < 8) {
    return { error: 'Password must be at least 8 characters.' };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName, role: 'client' } },
  });

  if (error) {
    logger.error('Sign-up failed', error);
    return { error: 'Could not create your account. Please try again.' };
  }

  // If email confirmation is required, there is no active session yet.
  if (!data.session) {
    return {
      message: 'Check your email to confirm your account, then sign in.',
    };
  }

  redirect('/portal');
}

/** Sign out and return to the login page. */
export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/login');
}
