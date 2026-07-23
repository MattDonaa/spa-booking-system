// ============================================================================
// Edge Function: payments-initiate
// ----------------------------------------------------------------------------
// Authenticated. Creates (idempotently) a pending payment for a booking via the
// initiate_payment RPC — which enforces ownership and computes the amount from
// the database (never trusting a client-supplied amount) — then returns the
// provider redirect instruction the client uses to hand off to the gateway.
//
// verify_jwt = true (see config.toml).
// ============================================================================
import { error, ok, requireEnv } from '../_shared/http.ts';
import { getGateway, isPaymentProvider } from '../_shared/gateway.ts';
import { userClient } from '../_shared/supabase.ts';

interface InitiateBody {
  bookingId?: string;
  provider?: string;
  paymentType?: 'deposit' | 'balance' | 'full';
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return error('VALIDATION', 'Method not allowed.', 405);
  }

  let body: InitiateBody;
  try {
    body = (await req.json()) as InitiateBody;
  } catch {
    return error('VALIDATION', 'Invalid JSON body.');
  }

  const { bookingId, provider, paymentType = 'deposit' } = body;
  if (!bookingId || !provider) {
    return error('VALIDATION', 'bookingId and provider are required.');
  }
  if (!isPaymentProvider(provider)) {
    return error('VALIDATION', `Unsupported provider: ${provider}`);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return error('UNAUTHENTICATED', 'Missing Authorization header.', 401);
  }

  const supabase = userClient(authHeader);

  // The RPC enforces authorization and computes the amount server-side.
  const { data, error: rpcError } = await supabase.rpc('initiate_payment', {
    p_booking_id: bookingId,
    p_provider: provider,
    p_payment_type: paymentType,
  });

  if (rpcError) {
    return error('INTERNAL', rpcError.message, 500);
  }
  if (!data?.ok) {
    const code = data?.error?.code ?? 'INTERNAL';
    const status =
      code === 'FORBIDDEN' ? 403 : code === 'NOT_FOUND' ? 404 : 400;
    return error(
      code,
      data?.error?.message ?? 'Payment could not be started.',
      status,
    );
  }

  const payment = data.data;
  const appUrl = requireEnv('APP_URL');
  const functionsUrl = `${requireEnv('SUPABASE_URL')}/functions/v1`;

  let redirect;
  try {
    const gateway = getGateway(provider);
    redirect = await gateway.buildRedirect({
      paymentId: payment.payment_id,
      amountCents: payment.amount_cents,
      currency: payment.currency,
      itemName: `Booking ${payment.booking_id}`,
      reference: payment.payment_id,
      returnUrl: `${appUrl}/bookings/${payment.booking_id}?payment=return`,
      cancelUrl: `${appUrl}/bookings/${payment.booking_id}?payment=cancel`,
      notifyUrl: `${functionsUrl}/payments-webhook?provider=${provider}`,
    });
  } catch (e) {
    return error('INTERNAL', `Gateway error: ${(e as Error).message}`, 500);
  }

  return ok({
    paymentId: payment.payment_id,
    provider,
    amountCents: payment.amount_cents,
    currency: payment.currency,
    redirect,
  });
});
