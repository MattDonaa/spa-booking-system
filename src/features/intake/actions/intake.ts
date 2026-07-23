'use server';

import { createClient } from '@/lib/supabase/server';
import { logger } from '@/lib/logger';
import { err, ok, type AppErrorCode, type Result } from '@/lib/result';
import type { IntakeForm, IntakeResponses } from '@/features/intake/types';

/**
 * Unwrap the standard `{ ok, data | error }` JSON envelope returned by the
 * intake RPCs into the app's `Result<T>`.
 */
function unwrap<T>(
  data: unknown,
  rpcError: { message: string } | null,
): Result<T> {
  if (rpcError) {
    logger.error('Intake RPC error', rpcError);
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

/** Load an intake form (with schema and decrypted responses if permitted). */
export async function getIntakeForm(
  intakeFormId: string,
): Promise<Result<IntakeForm>> {
  const supabase = await createClient();
  const { data, error: rpcError } = await supabase.rpc('get_intake_form', {
    p_intake_form_id: intakeFormId,
  } as never);
  return unwrap<IntakeForm>(data, rpcError);
}

/** Autosave partial responses (no validation). */
export async function autosaveIntake(
  intakeFormId: string,
  responses: IntakeResponses,
): Promise<
  Result<{ intake_form_id: string; status: string; saved_at: string }>
> {
  const supabase = await createClient();
  const { data, error: rpcError } = await supabase.rpc('save_intake_response', {
    p_intake_form_id: intakeFormId,
    p_responses: responses,
  } as never);
  return unwrap(data, rpcError);
}

/** Validate and finalize an intake form submission. */
export async function submitIntake(
  intakeFormId: string,
  responses: IntakeResponses,
): Promise<Result<{ intake_form_id: string; status: string }>> {
  const supabase = await createClient();
  const { data, error: rpcError } = await supabase.rpc('submit_intake_form', {
    p_intake_form_id: intakeFormId,
    p_responses: responses,
  } as never);
  return unwrap(data, rpcError);
}

/** Record a signed, versioned consent entry. */
export async function recordConsent(input: {
  templateId: string;
  consentGiven: boolean;
  bookingId?: string;
  signature?: string;
}): Promise<Result<{ consent_id: string; template_version: number }>> {
  const supabase = await createClient();
  const { data, error: rpcError } = await supabase.rpc('record_consent', {
    p_template_id: input.templateId,
    p_consent_given: input.consentGiven,
    p_booking_id: input.bookingId ?? null,
    p_signature: input.signature ?? null,
  } as never);
  return unwrap(data, rpcError);
}
