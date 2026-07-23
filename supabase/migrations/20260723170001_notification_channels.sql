-- ============================================================================
-- Migration: Add SMS notification channel
-- ----------------------------------------------------------------------------
-- Adds 'sms' to the notification_channel enum. This is intentionally a
-- standalone migration: a newly added enum value cannot be used in the same
-- transaction that adds it, so later migrations (templates, engine) may
-- reference it safely.
-- ============================================================================

alter type public.notification_channel add value if not exists 'sms';
