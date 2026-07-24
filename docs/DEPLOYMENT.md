# Deployment Guide

This guide covers deploying the Day Spa & Wellness Booking System to production:
the Supabase backend and the Next.js web app.

---

## Architecture

- **Web app** — Next.js (standalone output). Deploy to Vercel or as the provided
  Docker image behind a reverse proxy.
- **Backend** — Supabase (PostgreSQL, Auth, Storage, Edge Functions, pg_cron).
- **Payments** — PayFast & Ozow via Edge Functions + verified webhooks.
- **Notifications** — Email/WhatsApp/SMS via the `notifications-dispatch` Edge
  Function, driven by pg_cron.

---

## 1. Provision Supabase

1. Create a project at [supabase.com](https://supabase.com). Note the project
   ref, URL, anon key, and service-role key.
2. Install the CLI and link:
   ```bash
   supabase link --project-ref <ref>
   ```
3. Enable required extensions (created by migrations): `pgcrypto`, `btree_gist`,
   plus `pg_cron` and `pg_net` for scheduling (enable in Dashboard → Database →
   Extensions if not already on).
4. Create the intake encryption secret in **Vault**:
   - Dashboard → Project Settings → Vault → add secret
     `intake_encryption_key` with a strong random value.

## 2. Apply the database

```bash
supabase db push          # applies supabase/migrations in order
```

Then configure runtime pieces that need real values:

```sql
-- Schedule the notification dispatch worker (run once, as the postgres role):
select private.setup_notification_dispatch(
  'https://<ref>.functions.supabase.co',   -- functions base URL
  '<service-role-key>'                       -- service role key
);
```

Enable the **custom access token hook** (Dashboard → Authentication → Hooks) →
`private.custom_access_token_hook` (also declared in `supabase/config.toml`).

## 3. Configure secrets (Edge Functions)

```bash
supabase secrets set \
  APP_URL=https://app.example.com \
  PAYFAST_MERCHANT_ID=... PAYFAST_MERCHANT_KEY=... PAYFAST_PASSPHRASE=... PAYFAST_SANDBOX=false \
  OZOW_SITE_CODE=... OZOW_PRIVATE_KEY=... OZOW_API_KEY=... OZOW_IS_TEST=false \
  EMAIL_API_KEY=... EMAIL_FROM_ADDRESS="Serenity <no-reply@example.com>" \
  WHATSAPP_API_TOKEN=... WHATSAPP_PHONE_NUMBER_ID=... \
  SMS_API_URL=... SMS_API_KEY=...
```

Deploy the functions (verify_jwt settings come from `config.toml`; the deploy
workflow passes `--no-verify-jwt` for the webhook and dispatcher):

```bash
supabase functions deploy payments-initiate
supabase functions deploy payments-webhook --no-verify-jwt
supabase functions deploy payments-refund
supabase functions deploy notifications-dispatch --no-verify-jwt
```

Register the webhook URLs with PayFast/Ozow:
`https://<ref>.functions.supabase.co/payments-webhook?provider=payfast` (and
`...?provider=ozow`).

## 4. Deploy the web app

Set these environment variables in your host:

| Variable                        | Scope        |
| ------------------------------- | ------------ |
| `NEXT_PUBLIC_APP_URL`           | build + run  |
| `NEXT_PUBLIC_SUPABASE_URL`      | build + run  |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | build + run  |
| `SUPABASE_SERVICE_ROLE_KEY`     | run (secret) |

### Option A — Vercel

Import the repo, set the env vars, and deploy. The `Deploy` workflow automates
this on push to the default branch.

### Option B — Docker

```bash
docker build \
  --build-arg NEXT_PUBLIC_APP_URL=https://app.example.com \
  --build-arg NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co \
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key> \
  -t spa-booking-system .

docker run -p 3000:3000 \
  -e SUPABASE_SERVICE_ROLE_KEY=<service-key> \
  -e NEXT_PUBLIC_APP_URL=https://app.example.com \
  -e NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co \
  -e NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key> \
  spa-booking-system
```

Or `docker compose up --build` with a local `.env`.

---

## CI/CD

- **`.github/workflows/ci.yml`** — on every push/PR: env validation, lint,
  typecheck, unit/component tests, build; a local Supabase + pgTAP job; and a
  Playwright e2e job.
- **`.github/workflows/deploy.yml`** — on push to the default branch: push DB
  migrations, deploy Edge Functions, deploy the app, then a post-deploy health
  check.

Required deploy secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`,
`SUPABASE_DB_PASSWORD`, `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`,
and a `PRODUCTION_URL` variable.

---

## Health checks & monitoring

- **Health endpoint:** `GET /api/health` → `200 {"status":"ok"}` when the app
  and database are reachable, `503` otherwise. Used by the container
  `HEALTHCHECK`, load balancers, and the post-deploy smoke test.
- **Logs:** the app emits structured JSON via `src/lib/logger.ts` (stdout →
  your platform's log aggregation). Supabase provides database, auth, and
  function logs in the Dashboard.
- **Recommended add-ons:** an uptime monitor on `/api/health`; error tracking
  (e.g. Sentry) wired into the logger; Supabase log drains for retention.

See [`MONITORING.md`](./MONITORING.md) for details.

---

## Backups

Supabase provides automated daily backups and PITR (Pro+). For an additional
off-platform copy, schedule [`scripts/backup.sh`](../scripts/backup.sh) (logical
`pg_dump`). Restore with `pg_restore`.
