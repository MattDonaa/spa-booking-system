// ============================================================================
// Ozow gateway implementation.
// ----------------------------------------------------------------------------
// Docs: https://hub.ozow.com / https://ozow.com/integrations
//   * Redirect: a form POST whose fields include a SHA-512 HashCheck.
//   * Notification: Ozow POSTs the result with a SHA-512 Hash to verify.
//   * Refunds: authenticated call to the Ozow API using the ApiKey.
// Hashes are SHA-512 over the concatenated, lowercased field values with the
// private key appended.
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

function sha512(input: string): string {
  return createHash('sha512').update(input, 'utf8').digest('hex');
}

/** Ozow rule: concatenate values, lowercase the whole string, then SHA-512. */
function ozowHash(values: string[], privateKey: string): string {
  return sha512((values.join('') + privateKey).toLowerCase());
}

function mapStatus(raw: string | undefined): PaymentStatus {
  switch ((raw ?? '').toLowerCase()) {
    case 'complete':
      return 'succeeded';
    case 'cancelled':
      return 'cancelled';
    case 'error':
    case 'abandoned':
      return 'failed';
    case 'pending':
    case 'pendinginvestigation':
      return 'processing';
    default:
      return 'processing';
  }
}

export class OzowGateway implements PaymentGateway {
  readonly provider = 'ozow' as const;

  private readonly isTest = Deno.env.get('OZOW_IS_TEST') !== 'false';
  private readonly siteCode = requireEnv('OZOW_SITE_CODE');
  private readonly privateKey = requireEnv('OZOW_PRIVATE_KEY');
  private readonly apiKey = Deno.env.get('OZOW_API_KEY') || '';

  private get payUrl(): string {
    return this.isTest
      ? 'https://stagingpay.ozow.com/'
      : 'https://pay.ozow.com/';
  }

  buildRedirect(init: PaymentInitiation): Promise<RedirectInstruction> {
    const amount = (init.amountCents / 100).toFixed(2);
    const isTest = this.isTest ? 'true' : 'false';

    const fields: Record<string, string> = {
      SiteCode: this.siteCode,
      CountryCode: 'ZA',
      CurrencyCode: init.currency,
      Amount: amount,
      TransactionReference: init.reference,
      BankReference: init.itemName.slice(0, 20),
      CancelUrl: init.cancelUrl,
      ErrorUrl: init.cancelUrl,
      SuccessUrl: init.returnUrl,
      NotifyUrl: init.notifyUrl,
      IsTest: isTest,
    };

    // HashCheck input order per Ozow's request specification.
    const hash = ozowHash(
      [
        fields.SiteCode,
        fields.CountryCode,
        fields.CurrencyCode,
        fields.Amount,
        fields.TransactionReference,
        fields.BankReference,
        fields.CancelUrl,
        fields.ErrorUrl,
        fields.SuccessUrl,
        fields.NotifyUrl,
        fields.IsTest,
      ],
      this.privateKey,
    );
    fields.HashCheck = hash;

    return Promise.resolve({ method: 'POST', url: this.payUrl, fields });
  }

  verifyWebhook(_req: Request, rawBody: string): Promise<WebhookResult> {
    const data = parseFormEncoded(rawBody);
    const provided = (data.Hash ?? '').toLowerCase();

    // Response hash input order per Ozow's notification specification.
    const expected = ozowHash(
      [
        data.SiteCode ?? '',
        data.TransactionId ?? '',
        data.TransactionReference ?? '',
        data.Amount ?? '',
        data.Status ?? '',
        data.Optional1 ?? '',
        data.Optional2 ?? '',
        data.Optional3 ?? '',
        data.Optional4 ?? '',
        data.Optional5 ?? '',
        data.CurrencyCode ?? '',
        data.IsTest ?? '',
        data.StatusMessage ?? '',
      ],
      this.privateKey,
    );

    const verified = provided.length > 0 && provided === expected;

    return Promise.resolve({
      verified,
      eventId:
        data.TransactionId || data.TransactionReference || crypto.randomUUID(),
      paymentId: data.TransactionReference ?? null,
      providerReference: data.TransactionId ?? null,
      status: mapStatus(data.Status),
      raw: data,
    });
  }

  async refund(req: RefundRequest): Promise<RefundResult> {
    const base = this.isTest ? 'https://api.ozow.com' : 'https://api.ozow.com';
    const res = await fetch(`${base}/refunds`, {
      method: 'POST',
      headers: {
        ApiKey: this.apiKey,
        SiteCode: this.siteCode,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        TransactionId: req.providerReference,
        Amount: (req.amountCents / 100).toFixed(2),
        IsTest: this.isTest,
        Reason: req.reason ?? 'Refund',
      }),
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
