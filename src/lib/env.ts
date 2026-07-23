import { z } from 'zod';

/**
 * Centralized, validated environment configuration.
 *
 * Environment variables are validated once at module load. Missing or
 * malformed values fail fast with a descriptive error instead of surfacing
 * as obscure runtime bugs deep inside the app.
 *
 * Public (client-safe) variables MUST be prefixed with `NEXT_PUBLIC_`.
 * Server-only secrets are validated lazily and must never be imported into
 * client components.
 */

const clientSchema = z.object({
  NEXT_PUBLIC_APP_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
});

const serverSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'production', 'test'])
    .default('development'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
});

/**
 * Client-safe environment. Values here are inlined at build time by Next.js,
 * so they must be referenced statically (not via dynamic keys).
 */
const clientEnv = clientSchema.safeParse({
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
});

if (!clientEnv.success) {
  throw new Error(
    `Invalid public environment configuration:\n${clientEnv.error.errors
      .map((e) => `  - ${e.path.join('.')}: ${e.message}`)
      .join('\n')}`,
  );
}

export const env = clientEnv.data;

/**
 * Server-only environment. Call this from server-side code only. It throws if
 * invoked in a browser context to prevent accidental secret exposure.
 */
export function getServerEnv() {
  if (typeof window !== 'undefined') {
    throw new Error('getServerEnv() must not be called on the client.');
  }

  const parsed = serverSchema.safeParse({
    NODE_ENV: process.env.NODE_ENV,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  });

  if (!parsed.success) {
    throw new Error(
      `Invalid server environment configuration:\n${parsed.error.errors
        .map((e) => `  - ${e.path.join('.')}: ${e.message}`)
        .join('\n')}`,
    );
  }

  return parsed.data;
}
