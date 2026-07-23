import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

import { env } from '@/lib/env';
import type { Database } from '@/lib/supabase/types';

/**
 * Refreshes the Supabase auth session on every request and keeps auth cookies
 * synchronized between the browser and server.
 *
 * This must run in middleware so that Server Components always observe a valid,
 * up-to-date session. Do not add data access here — its sole job is session
 * management.
 */
export async function updateSession(
  request: NextRequest,
): Promise<NextResponse> {
  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(
          cookiesToSet: {
            name: string;
            value: string;
            options: CookieOptions;
          }[],
        ) {
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value);
          });
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    },
  );

  // Touching the user refreshes the session token if needed. Never remove.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Protect the client portal: unauthenticated visitors are sent to login.
  const { pathname } = request.nextUrl;
  if (!user && pathname.startsWith('/portal')) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = '/login';
    loginUrl.searchParams.set('redirectTo', pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Keep authenticated users out of the auth pages.
  if (user && (pathname === '/login' || pathname === '/signup')) {
    const portalUrl = request.nextUrl.clone();
    portalUrl.pathname = '/portal';
    portalUrl.search = '';
    return NextResponse.redirect(portalUrl);
  }

  return response;
}
