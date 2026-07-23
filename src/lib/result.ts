/**
 * Consistent result and error contract shared across server actions, the
 * service layer, and API responses.
 *
 * Instead of throwing across boundaries, operations return a discriminated
 * `Result` so callers must explicitly handle both success and failure.
 */

export type AppErrorCode =
  | 'VALIDATION'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'RATE_LIMITED'
  | 'INTERNAL';

export interface AppError {
  code: AppErrorCode;
  message: string;
  /** Field-level validation messages, keyed by field path. */
  fields?: Record<string, string[]>;
}

export type Result<T> = { ok: true; data: T } | { ok: false; error: AppError };

export function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

export function err(
  code: AppErrorCode,
  message: string,
  fields?: Record<string, string[]>,
): Result<never> {
  return { ok: false, error: { code, message, fields } };
}
