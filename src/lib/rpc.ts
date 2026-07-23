import { logger } from '@/lib/logger';
import { err, ok, type AppErrorCode, type Result } from '@/lib/result';

/**
 * Unwrap the standard `{ ok, data | error }` JSON envelope returned by the
 * database RPCs into the app's `Result<T>`.
 */
export function unwrapRpc<T>(
  data: unknown,
  rpcError: { message: string } | null,
): Result<T> {
  if (rpcError) {
    logger.error('RPC error', rpcError);
    return err('INTERNAL', 'The request could not be completed.');
  }

  const envelope = data as
    | { ok: true; data: T }
    | {
        ok: false;
        error: { code: AppErrorCode; message: string; fields?: unknown };
      }
    | null;

  if (!envelope) {
    return err('INTERNAL', 'Empty response from server.');
  }
  if (envelope.ok) {
    return ok(envelope.data);
  }
  return err(
    envelope.error.code,
    envelope.error.message,
    envelope.error.fields as Record<string, string[]> | undefined,
  );
}
