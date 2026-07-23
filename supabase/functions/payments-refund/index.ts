// ============================================================================
// Edge Function: payments-refund
// ----------------------------------------------------------------------------
// Authenticated (staff/admin, enforced by the initiate_refund RPC). Creates an
// idempotent pending refund, calls the provider's refund API through the
// gateway abstraction, then records the outcome via record_refund_event
// (service role). The database remains the source of truth for refund state.
//
// verify_jwt = true (see config.toml).
// ============================================================================
import { error, ok } from '../_shared/http.ts';
import { getGateway, isPaymentProvider } from '../_shared/gateway.ts';
import { serviceClient, userClient } from '../_shared/supabase.ts';

interface RefundBody {
  paymentId?: string;
  amountCents?: number;
  reason?: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return error('VALIDATION', 'Method not allowed.', 405);
  }

  let body: RefundBody;
  try {
    body = (await req.json()) as RefundBody;
  } catch {
    return error('VALIDATION', 'Invalid JSON body.');
  }

  const { paymentId, amountCents, reason } = body;
  if (!paymentId) {
    return error('VALIDATION', 'paymentId is required.');
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return error('UNAUTHENTICATED', 'Missing Authorization header.', 401);
  }

  // Create/return the pending refund with the caller's privileges (staff/admin
  // enforced inside the RPC).
  const asUser = userClient(authHeader);
  const { data: initData, error: initError } = await asUser.rpc(
    'initiate_refund',
    {
      p_payment_id: paymentId,
      p_amount_cents: amountCents ?? null,
      p_reason: reason ?? null,
    },
  );

  if (initError) return error('INTERNAL', initError.message, 500);
  if (!initData?.ok) {
    const code = initData?.error?.code ?? 'INTERNAL';
    const status =
      code === 'FORBIDDEN' ? 403 : code === 'NOT_FOUND' ? 404 : 400;
    return error(code, initData?.error?.message ?? 'Refund rejected.', status);
  }

  const refund = initData.data;
  const admin = serviceClient();

  // Look up the payment's provider + reference (service role; RLS-exempt).
  const { data: payment, error: payErr } = await admin
    .from('payments')
    .select('provider, provider_reference, currency')
    .eq('id', refund.payment_id)
    .single();

  if (payErr || !payment) {
    return error('NOT_FOUND', 'Payment not found for refund.', 404);
  }
  if (!isPaymentProvider(payment.provider) || !payment.provider_reference) {
    return error(
      'CONFLICT',
      'Payment cannot be refunded (no provider reference).',
    );
  }

  let refundResult;
  try {
    const gateway = getGateway(payment.provider);
    refundResult = await gateway.refund({
      providerReference: payment.provider_reference,
      amountCents: refund.amount_cents,
      currency: payment.currency,
      reason,
    });
  } catch (e) {
    return error(
      'INTERNAL',
      `Gateway refund error: ${(e as Error).message}`,
      500,
    );
  }

  // Record the (in-flight) result. The provider webhook confirms 'succeeded'.
  const { error: recErr } = await admin.rpc('record_refund_event', {
    p_refund_id: refund.refund_id,
    p_status: refundResult.status,
    p_provider_reference: refundResult.providerReference,
    p_payload: refundResult.raw,
  });

  if (recErr) return error('INTERNAL', recErr.message, 500);

  return ok({
    refundId: refund.refund_id,
    status: refundResult.status,
    amountCents: refund.amount_cents,
  });
});
