-- ============================================================================
-- Migration: Notification Templates
-- ----------------------------------------------------------------------------
-- Versioned, per-channel message templates. Bodies use `{{placeholder}}` tokens
-- interpolated from the notification payload by the dispatch worker. One active
-- template per (notification_type, channel, locale).
-- ============================================================================

create table public.notification_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  notification_type public.notification_type not null,
  channel public.notification_channel not null,
  locale text not null default 'en',
  -- Subject line (email only; ignored for SMS/WhatsApp).
  subject text,
  body_template text not null,
  version integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint notification_templates_body_not_blank_chk
    check (length(btrim(body_template)) > 0),
  constraint notification_templates_version_positive_chk check (version > 0)
);

create unique index notification_templates_active_unique_idx
  on public.notification_templates (notification_type, channel, locale)
  where is_active and deleted_at is null;

comment on table public.notification_templates is
  'Versioned per-channel message templates with {{placeholder}} interpolation.';

create trigger set_updated_at before update on public.notification_templates
  for each row execute function public.set_updated_at();
create trigger prevent_hard_delete before delete on public.notification_templates
  for each row execute function public.prevent_hard_delete();
create trigger record_audit
  after insert or update or delete on public.notification_templates
  for each row execute function public.record_audit();

-- RLS: readable by staff; writable by admins. Enabled + forced (deny-by-default).
alter table public.notification_templates enable row level security;
alter table public.notification_templates force row level security;

create policy notification_templates_select_staff on public.notification_templates
  for select to authenticated
  using (private.is_staff());
create policy notification_templates_insert_admin on public.notification_templates
  for insert to authenticated with check (private.is_admin());
create policy notification_templates_update_admin on public.notification_templates
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

grant select, insert, update on public.notification_templates to authenticated;

-- ----------------------------------------------------------------------------
-- Seed default templates (English). Placeholders: {{client_name}},
-- {{service_name}}, {{starts_at}}, {{business_name}}, {{amount}}, {{booking_url}}.
-- ----------------------------------------------------------------------------
insert into public.notification_templates
  (notification_type, channel, subject, body_template)
values
  ('booking_confirmation', 'email',
   'Your booking is confirmed',
   E'Hi {{client_name}},\n\nYour {{service_name}} appointment on {{starts_at}} is confirmed.\n\nSee you soon,\n{{business_name}}'),
  ('booking_confirmation', 'whatsapp', null,
   'Hi {{client_name}}, your {{service_name}} appointment on {{starts_at}} is confirmed. — {{business_name}}'),
  ('booking_confirmation', 'sms', null,
   '{{business_name}}: your {{service_name}} on {{starts_at}} is confirmed.'),

  ('payment_reminder', 'email',
   'Complete your booking payment',
   E'Hi {{client_name}},\n\nYour {{service_name}} booking is being held. Please pay {{amount}} to confirm: {{booking_url}}'),
  ('payment_reminder', 'whatsapp', null,
   'Hi {{client_name}}, please pay {{amount}} to confirm your {{service_name}} booking: {{booking_url}}'),

  ('appointment_reminder', 'email',
   'Reminder: your appointment tomorrow',
   E'Hi {{client_name}},\n\nThis is a reminder for your {{service_name}} appointment on {{starts_at}}.\n\n{{business_name}}'),
  ('appointment_reminder', 'whatsapp', null,
   'Reminder: your {{service_name}} appointment is on {{starts_at}}. — {{business_name}}'),
  ('appointment_reminder', 'sms', null,
   '{{business_name}} reminder: {{service_name}} on {{starts_at}}.'),

  ('booking_cancelled', 'email',
   'Your booking has been cancelled',
   E'Hi {{client_name}},\n\nYour {{service_name}} appointment on {{starts_at}} has been cancelled.\n\n{{business_name}}'),
  ('booking_cancelled', 'whatsapp', null,
   'Your {{service_name}} appointment on {{starts_at}} has been cancelled. — {{business_name}}'),

  ('review_request', 'email',
   'How was your visit?',
   E'Hi {{client_name}},\n\nThank you for visiting {{business_name}}. We would love your feedback on your {{service_name}}: {{booking_url}}'),
  ('review_request', 'whatsapp', null,
   'Thanks for visiting {{business_name}}! We''d love your feedback: {{booking_url}}'),

  ('rebooking_reminder', 'email',
   'Time for your next visit?',
   E'Hi {{client_name}},\n\nIt has been a while since your last {{service_name}}. Ready to rebook? {{booking_url}}'),
  ('rebooking_reminder', 'whatsapp', null,
   'Hi {{client_name}}, ready to rebook your {{service_name}}? {{booking_url}}');
