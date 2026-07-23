import { type NextRequest } from 'next/server';

import { updateSession } from '@/lib/supabase/middleware';

/**
 * Root middleware. Refreshes the Supabase auth session on each request.
 * Route-level authorization is added in later milestones.
 */
export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    /*
     * Match all request paths except static assets and image optimization
     * files, for which session refresh is unnecessary.
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
