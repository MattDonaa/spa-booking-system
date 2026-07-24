# Production Readiness Checklist

Work top to bottom before go-live. Items marked 🔒 are security/compliance
critical.

## Backend (Supabase)

- [ ] Project created; region chosen close to customers (South Africa/EU).
- [ ] Extensions enabled: `pgcrypto`, `btree_gist`, `pg_cron`, `pg_net`.
- [ ] All migrations applied (`supabase db push`) with no drift.
- [ ] Seed applied (business settings singleton row present).
- [ ] 🔒 `intake_encryption_key` set in Vault (medical data encryption).
- [ ] 🔒 RLS enabled + forced on all tables (verified — it is, by migration).
- [ ] Custom access token hook enabled (`user_role` claim).
- [ ] pg_cron jobs present: `expire-booking-holds`, `enqueue-due-reminders`.
- [ ] `private.setup_notification_dispatch(...)` run with real URL + service key.

## Payments 🔒

- [ ] PayFast + Ozow live credentials set via `supabase secrets`.
- [ ] `PAYFAST_SANDBOX=false`, `OZOW_IS_TEST=false`.
- [ ] Webhook URLs registered with both providers (per `?provider=`).
- [ ] Test a full deposit payment end-to-end (initiate → provider → webhook →
      booking confirmed).
- [ ] Test a refund end-to-end.

## Notifications

- [ ] Email/WhatsApp/SMS provider credentials set.
- [ ] `EMAIL_FROM_ADDRESS` verified with the email provider (SPF/DKIM).
- [ ] Send a test of each channel; confirm delivery-log rows.

## Web app

- [ ] `NEXT_PUBLIC_*` and `SUPABASE_SERVICE_ROLE_KEY` configured in the host.
- [ ] 🔒 Service role key is server-only (never in `NEXT_PUBLIC_*`).
- [ ] `npm run validate-env` passes in the deploy environment.
- [ ] Production build succeeds; `/api/health` returns `200`.
- [ ] Custom domain + HTTPS configured; `NEXT_PUBLIC_APP_URL`/`APP_URL` match.
- [ ] Security headers present (set in `next.config.mjs`).

## Quality gates

- [ ] `npm run lint`, `npm run typecheck`, `npm test` green in CI.
- [ ] pgTAP suite green (`supabase test db`).
- [ ] Playwright e2e green.
- [ ] Accessibility scan (axe) shows no serious/critical violations.

## Compliance (POPIA) 🔒

- [ ] Medical intake + consent are RLS-restricted to owner/assigned
      practitioner/admin (verified).
- [ ] Private storage buckets (`intake-documents`, `consent-documents`) are not
      public.
- [ ] Consent records capture signature, version, IP, and timestamp.
- [ ] Privacy policy and data-retention policy published.
- [ ] Audit logging active on all mutable business tables (it is, by trigger).

## Operations

- [ ] Backups scheduled (Supabase automated + `scripts/backup.sh` off-platform).
- [ ] Uptime monitor on `/api/health`.
- [ ] Error tracking + alerting configured (see `MONITORING.md`).
- [ ] Runbook: how to reprocess a failed webhook, retry notifications, and
      restore from backup.
- [ ] Rollback plan for a bad migration or deploy.
