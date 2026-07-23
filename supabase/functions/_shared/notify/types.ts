// ============================================================================
// Notification channel abstraction — shared types.
// ----------------------------------------------------------------------------
// A single `ChannelSender` interface implemented by the email, WhatsApp, and
// SMS providers, so the dispatch worker is channel-agnostic.
// ============================================================================

export type NotificationChannel = 'email' | 'whatsapp' | 'sms';

/** A queued notification row, as returned by claim_due_notifications. */
export interface QueuedNotification {
  id: string;
  recipient_profile_id: string | null;
  booking_id: string | null;
  channel: NotificationChannel;
  notification_type: string;
  payload: Record<string, unknown>;
  attempts: number;
  max_attempts: number;
}

/** A rendered message ready to send on a channel. */
export interface RenderedMessage {
  to: string;
  subject: string | null;
  body: string;
}

export interface SendResult {
  success: boolean;
  provider: string;
  providerMessageId: string | null;
  response: Record<string, unknown>;
  error?: string;
}

export interface ChannelSender {
  readonly channel: NotificationChannel;
  send(message: RenderedMessage): Promise<SendResult>;
}
