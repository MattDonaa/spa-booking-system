// ============================================================================
// Edge Function: payments-webhook
// ----------------------------------------------------------------------------
// Public endpoint hit by the payment providers (PayFast ITN / Ozow
// notification). Verifies the signature/hash, then applies the result exactly
// once via record_payment_event (service role). Idempotency is guaranteed by
// the unique (provider, event_id) constraint in the database.
//
// Retry logic: on a transient/internal failure we return HTTP 5xx so the
// provider re-delivers; on a bad request or invalid signature we return the
// appropriate 4xx (no retry). Successful and already-processed events return
// 200 so the provider stops retrying.
//
// verify_jwt = false (see config.toml) — providers do not send a Supabase JWT.
// ============================================================================
import { getGateway, isPaymentProvider } from '../_shared/gateway.ts';
import { readRawBody } from '../_shared/http.ts';
import { serviceClient } from '../_shared/supabase.ts';

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const url = new URL(req.url);
  const provider = url.searchParams.get('provider') ?? '';
  if (!isPaymentProvider(provider)) {
    return new Response('Unknown provider', { status: 400 });
  }

  const rawBody = await readRawBody(req);

  let result;
  try {
    const gateway = getGateway(provider);
    result = await gateway.verifyWebhook(req, rawBody);
  } catch (e) {
    console.error('Webhook verification error', e);
    // Internal error — ask the provider to retry.
    return new Response('Verification error', { status: 500 });
  }

  if (!result.paymentId) {
    // Nothing we can correlate — do not ask for a retry.
    return new Response('Missing payment reference', { status: 400 });
  }

  const supabase = serviceClient();
  const { data, error: rpcError } = await supabase.rpc('record_payment_event', {
    p_provider: provider,
    p_event_id: result.eventId,
    p_payment_id: result.paymentId,
    p_status: result.status,
    p_provider_reference: result.providerReference,
    p_signature_verified: result.verified,
    p_payload: result.raw,
  });

  if (rpcError) {
    console.error('record_payment_event failed', rpcError);
    // Transient/DB error — allow the provider to retry.
    return new Response('Processing error', { status: 500 });
  }

  if (!data?.ok) {
    const code = data?.error?.code ?? 'INTERNAL';
    // Invalid signature is a permanent failure: acknowledge without retry.
    const status =
      code === 'FORBIDDEN' ? 400 : code === 'NOT_FOUND' ? 404 : 400;
    return new Response(data?.error?.message ?? 'Rejected', { status });
  }

  return new Response('OK', { status: 200 });
});
