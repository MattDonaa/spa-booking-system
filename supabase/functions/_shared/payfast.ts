// ============================================================================
// PayFast gateway implementation.
// ----------------------------------------------------------------------------
// Docs: https://developers.payfast.co.za
//   * Redirect: a signed form POST to the process endpoint.
//   * ITN webhook: PayFast POSTs urlencoded fields including an MD5 signature.
//   * Refunds: authenticated call to the PayFast API.
// Signatures use MD5 over PHP-urlencoded, order-preserving parameter strings,
// with the merchant passphrase appended.
// ============================================================================
import { createHash } from 'node:crypto';

import { parseFormEncoded, requireEnv } from './http.ts';
import type {
  PaymentGateway,
  PaymentInitiation,
  PaymentStatus,
  RedirectInstruction,
  RefundRequest,
  RefundResult,
  WebhookResult,
} from './types.ts';

function md5(input: string): string {
  return createHash('md5').update(input, 'utf8').digest('hex');
}

// PayFast expects PHP urlencode(): spaces as '+', uppercase hex escapes.
function pfEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, '+')
    .replace(
      /[!'()*~]/g,
      (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase(),
    );
}

/** Build the MD5 signature over ordered fields, appending the passphrase. */
function sign(
  fields: Array<[string, string]>,
  passphrase: string | undefined,
): string {
  const parts = fields
    .filter(([, v]) => v !== '' && v !== undefined && v !== null)
    .map(([k, v]) => `${k}=${pfEncode(v)}`);
  if (passphrase) parts.push(`passphrase=${pfEncode(passphrase)}`);
  return md5(parts.join('&'));
}

function mapStatus(raw: string | undefined): PaymentStatus {
  switch ((raw ?? '').toUpperCase()) {
    case 'COMPLETE':
      return 'succeeded';
    case 'FAILED':
      return 'failed';
    case 'CANCELLED':
      return 'cancelled';
    case 'PENDING':
      return 'processing';
    default:
      return 'processing';
  }
}

export class PayfastGateway implements PaymentGateway {
  readonly provider = 'payfast' as const;

  private readonly sandbox = Deno.env.get('PAYFAST_SANDBOX') !== 'false';
  private readonly merchantId = requireEnv('PAYFAST_MERCHANT_ID');
  private readonly merchantKey = requireEnv('PAYFAST_MERCHANT_KEY');
  private readonly passphrase = Deno.env.get('PAYFAST_PASSPHRASE') || undefined;

  private get processUrl(): string {
    return this.sandbox
      ? 'https://sandbox.payfast.co.za/eng/process'
      : 'https://www.payfast.co.za/eng/process';
  }

  buildRedirect(init: PaymentInitiation): Promise<RedirectInstruction> {
    // Field order matters: the signature is computed over this exact order.
    const ordered: Array<[string, string]> = [
      ['merchant_id', this.merchantId],
      ['merchant_key', this.merchantKey],
      ['return_url', init.returnUrl],
      ['cancel_url', init.cancelUrl],
      ['notify_url', init.notifyUrl],
      ['m_payment_id', init.paymentId],
      ['amount', (init.amountCents / 100).toFixed(2)],
      ['item_name', init.itemName],
    ];
    if (init.buyerEmail) ordered.push(['email_address', init.buyerEmail]);

    const signature = sign(ordered, this.passphrase);

    const fields: Record<string, string> = {};
    for (const [k, v] of ordered) fields[k] = v;
    fields.signature = signature;

    return Promise.resolve({ method: 'POST', url: this.processUrl, fields });
  }

  verifyWebhook(_req: Request, rawBody: string): Promise<WebhookResult> {
    const data = parseFormEncoded(rawBody);
    const provided = data.signature ?? '';

    // Recompute the signature over posted fields (in received order) minus the
    // signature field itself.
    const ordered: Array<[string, string]> = Object.entries(data)
      .filter(([k]) => k !== 'signature')
      .map(([k, v]) => [k, v] as [string, string]);
    const expected = sign(ordered, this.passphrase);

    const verified = provided.length > 0 && provided === expected;

    return Promise.resolve({
      verified,
      eventId: data.pf_payment_id || data.m_payment_id || crypto.randomUUID(),
      paymentId: data.m_payment_id ?? null,
      providerReference: data.pf_payment_id ?? null,
      status: mapStatus(data.payment_status),
      raw: data,
    });
  }

  async refund(req: RefundRequest): Promise<RefundResult> {
    // PayFast API refund. Requires the pf transaction id (providerReference).
    const version = 'v1';
    const timestamp = new Date().toISOString();
    const body: Record<string, string> = {
      amount: (req.amountCents / 100).toFixed(2),
      ...(req.reason ? { reason: req.reason } : {}),
    };

    // API signature: alphabetically sorted (headers + body) key=value pairs.
    const signatureFields: Array<[string, string]> = [
      ['merchant-id', this.merchantId],
      ['timestamp', timestamp],
      ['version', version],
      ...Object.entries(body),
    ].sort(([a], [b]) => a.localeCompare(b));
    const apiSignature = sign(signatureFields, this.passphrase);

    const base = this.sandbox
      ? 'https://sandbox.payfast.co.za'
      : 'https://api.payfast.co.za';
    const url = `${base}/refunds/${encodeURIComponent(req.providerReference)}`;

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'merchant-id': this.merchantId,
        version,
        timestamp,
        signature: apiSignature,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams(body).toString(),
    });

    const text = await res.text();
    let raw: Record<string, unknown>;
    try {
      raw = JSON.parse(text);
    } catch {
      raw = { response: text };
    }

    return {
      providerReference: req.providerReference,
      status: res.ok ? 'processing' : 'failed',
      raw,
    };
  }
}
