// ============================================================================
// Edge Function: notifications-dispatch
// ----------------------------------------------------------------------------
// The delivery worker. Invoked on a schedule (pg_cron -> pg_net) or manually.
// Claims due notifications, renders the per-channel template, sends via the
// channel provider, and reports success/failure (which drives retry/backoff).
//
// verify_jwt = false (invoked by cron), but the endpoint requires the service
// role key in the Authorization header, so it cannot be triggered anonymously.
// ============================================================================
import { getSender } from '../_shared/notify/senders.ts';
import { render } from '../_shared/notify/render.ts';
import type {
  NotificationChannel,
  QueuedNotification,
  RenderedMessage,
} from '../_shared/notify/types.ts';
import { requireEnv } from '../_shared/http.ts';
import { serviceClient } from '../_shared/supabase.ts';

Deno.serve(async (req: Request): Promise<Response> => {
  // Authorize: only the service role key (or an equal shared secret) may run.
  const auth = req.headers.get('Authorization') ?? '';
  const serviceKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  if (auth !== `Bearer ${serviceKey}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const limit = Number(new URL(req.url).searchParams.get('limit') ?? '20');
  const supabase = serviceClient();

  const { data: claimed, error: claimError } = await supabase.rpc(
    'claim_due_notifications',
    { p_limit: Number.isFinite(limit) ? limit : 20 },
  );

  if (claimError) {
    console.error('claim_due_notifications failed', claimError);
    return new Response(JSON.stringify({ error: claimError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const notifications = (claimed ?? []) as QueuedNotification[];
  let sent = 0;
  let failed = 0;

  for (const n of notifications) {
    try {
      const message = await buildMessage(supabase, n);
      const result = await getSender(n.channel).send(message);

      if (result.success) {
        await supabase.rpc('mark_notification_sent', {
          p_notification_id: n.id,
          p_provider: result.provider,
          p_provider_message_id: result.providerMessageId,
          p_response: result.response,
        });
        sent++;
      } else {
        await supabase.rpc('mark_notification_failed', {
          p_notification_id: n.id,
          p_error: result.error ?? 'Unknown send error',
          p_provider: result.provider,
          p_response: result.response,
        });
        failed++;
      }
    } catch (e) {
      await supabase.rpc('mark_notification_failed', {
        p_notification_id: n.id,
        p_error: (e as Error).message,
        p_provider: null,
        p_response: null,
      });
      failed++;
    }
  }

  return new Response(
    JSON.stringify({ ok: true, claimed: notifications.length, sent, failed }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});

/** Fetch the channel template and render the outbound message. */
async function buildMessage(
  supabase: ReturnType<typeof serviceClient>,
  n: QueuedNotification,
): Promise<RenderedMessage> {
  const { data: template, error } = await supabase
    .from('notification_templates')
    .select('subject, body_template')
    .eq('notification_type', n.notification_type)
    .eq('channel', n.channel)
    .eq('locale', 'en')
    .eq('is_active', true)
    .is('deleted_at', null)
    .single();

  if (error || !template) {
    throw new Error(
      `No active template for ${n.notification_type}/${n.channel}`,
    );
  }

  const to = recipientFor(n.channel, n.payload);
  if (!to) {
    throw new Error(`No recipient address for channel ${n.channel}`);
  }

  return {
    to,
    subject: template.subject ? render(template.subject, n.payload) : null,
    body: render(template.body_template, n.payload),
  };
}

function recipientFor(
  channel: NotificationChannel,
  payload: Record<string, unknown>,
): string | null {
  if (channel === 'email') return (payload.recipient_email as string) ?? null;
  return (payload.recipient_phone as string) ?? null;
}
