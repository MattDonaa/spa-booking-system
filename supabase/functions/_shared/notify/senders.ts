// ============================================================================
// Channel senders: Email, WhatsApp, SMS.
// ----------------------------------------------------------------------------
// Each implements the same ChannelSender interface. Provider credentials come
// from environment secrets. The concrete HTTP calls target common providers
// (Resend for email, Meta WhatsApp Cloud API, and a generic SMS HTTP gateway);
// swap the endpoints/payloads to match your chosen providers.
// ============================================================================
import type {
  ChannelSender,
  NotificationChannel,
  RenderedMessage,
  SendResult,
} from './types.ts';

function env(name: string): string | undefined {
  return Deno.env.get(name);
}

async function parseResponse(res: Response): Promise<Record<string, unknown>> {
  const text = await res.text();
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return { response: text };
  }
}

// ----------------------------------------------------------------------------
// Email (Resend-compatible HTTP API).
// ----------------------------------------------------------------------------
class EmailSender implements ChannelSender {
  readonly channel = 'email' as const;

  async send(message: RenderedMessage): Promise<SendResult> {
    const apiKey = env('EMAIL_API_KEY');
    const from = env('EMAIL_FROM_ADDRESS');
    if (!apiKey || !from) {
      return fail('email', 'Email provider is not configured.');
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: message.to,
        subject: message.subject ?? '(no subject)',
        text: message.body,
      }),
    });

    const body = await parseResponse(res);
    return {
      success: res.ok,
      provider: 'resend',
      providerMessageId: (body.id as string) ?? null,
      response: body,
      error: res.ok ? undefined : `Email send failed (${res.status})`,
    };
  }
}

// ----------------------------------------------------------------------------
// WhatsApp (Meta WhatsApp Cloud API).
// ----------------------------------------------------------------------------
class WhatsAppSender implements ChannelSender {
  readonly channel = 'whatsapp' as const;

  async send(message: RenderedMessage): Promise<SendResult> {
    const token = env('WHATSAPP_API_TOKEN');
    const phoneNumberId = env('WHATSAPP_PHONE_NUMBER_ID');
    if (!token || !phoneNumberId) {
      return fail('whatsapp', 'WhatsApp provider is not configured.');
    }

    const res = await fetch(
      `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: message.to,
          type: 'text',
          text: { body: message.body },
        }),
      },
    );

    const body = await parseResponse(res);
    const messages = body.messages as Array<{ id?: string }> | undefined;
    return {
      success: res.ok,
      provider: 'whatsapp_cloud',
      providerMessageId: messages?.[0]?.id ?? null,
      response: body,
      error: res.ok ? undefined : `WhatsApp send failed (${res.status})`,
    };
  }
}

// ----------------------------------------------------------------------------
// SMS (generic HTTP gateway).
// ----------------------------------------------------------------------------
class SmsSender implements ChannelSender {
  readonly channel = 'sms' as const;

  async send(message: RenderedMessage): Promise<SendResult> {
    const apiUrl = env('SMS_API_URL');
    const apiKey = env('SMS_API_KEY');
    if (!apiUrl || !apiKey) {
      return fail('sms', 'SMS provider is not configured.');
    }

    const res = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ to: message.to, body: message.body }),
    });

    const body = await parseResponse(res);
    return {
      success: res.ok,
      provider: 'sms_gateway',
      providerMessageId: (body.id as string) ?? null,
      response: body,
      error: res.ok ? undefined : `SMS send failed (${res.status})`,
    };
  }
}

function fail(provider: string, error: string): SendResult {
  return {
    success: false,
    provider,
    providerMessageId: null,
    response: {},
    error,
  };
}

const senders: Record<NotificationChannel, ChannelSender> = {
  email: new EmailSender(),
  whatsapp: new WhatsAppSender(),
  sms: new SmsSender(),
};

export function getSender(channel: NotificationChannel): ChannelSender {
  return senders[channel];
}
