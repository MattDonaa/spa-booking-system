// ============================================================================
// Payment gateway abstraction — shared types.
// ----------------------------------------------------------------------------
// A single interface (`PaymentGateway`) that PayFast and Ozow implement, so the
// Edge Functions are provider-agnostic. Providers differ only in how they sign
// redirects, verify webhooks, and issue refunds.
// ============================================================================

export type PaymentProvider = 'payfast' | 'ozow';

// Mirrors the public.payment_status enum in the database.
export type PaymentStatus =
  | 'pending'
  | 'processing'
  | 'succeeded'
  | 'failed'
  | 'cancelled'
  | 'refunded'
  | 'partially_refunded';

export type RefundStatus = 'pending' | 'processing' | 'succeeded' | 'failed';

/** Inputs required to start a hosted-payment redirect. */
export interface PaymentInitiation {
  paymentId: string;
  amountCents: number;
  currency: string;
  itemName: string;
  reference: string;
  returnUrl: string;
  cancelUrl: string;
  notifyUrl: string;
  buyerEmail?: string;
}

/**
 * How the client should hand the user off to the provider. For providers that
 * require a signed form POST, `fields` carries the form body.
 */
export interface RedirectInstruction {
  method: 'GET' | 'POST';
  url: string;
  fields: Record<string, string>;
}

/** Normalised outcome of verifying and parsing a provider webhook. */
export interface WebhookResult {
  /** True only if the cryptographic signature/hash checks out. */
  verified: boolean;
  /** Provider-unique event identifier, for idempotency. */
  eventId: string;
  /** Our payment id, echoed back by the provider. */
  paymentId: string | null;
  /** The provider's own transaction reference. */
  providerReference: string | null;
  /** Mapped payment status. */
  status: PaymentStatus;
  /** The raw parsed payload, stored for audit/forensics. */
  raw: Record<string, unknown>;
}

export interface RefundRequest {
  providerReference: string;
  amountCents: number;
  currency: string;
  reason?: string;
}

export interface RefundResult {
  providerReference: string | null;
  status: RefundStatus;
  raw: Record<string, unknown>;
}

/** The provider-agnostic contract implemented by each gateway. */
export interface PaymentGateway {
  readonly provider: PaymentProvider;
  buildRedirect(init: PaymentInitiation): Promise<RedirectInstruction>;
  verifyWebhook(req: Request, rawBody: string): Promise<WebhookResult>;
  refund(req: RefundRequest): Promise<RefundResult>;
}
