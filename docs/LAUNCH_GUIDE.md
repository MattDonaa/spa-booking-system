# Launch Guide

A step-by-step path from an empty Supabase project to a live booking platform.
For deeper reference see [`DEPLOYMENT.md`](./DEPLOYMENT.md) and the
[`PRODUCTION_CHECKLIST.md`](./PRODUCTION_CHECKLIST.md).

---

## Day 0 — Backend up

1. Create the Supabase project; enable `pgcrypto`, `btree_gist`, `pg_cron`,
   `pg_net`.
2. `supabase link --project-ref <ref>` then `supabase db push`.
3. Add the Vault secret `intake_encryption_key`.
4. Enable the access-token hook; run `private.setup_notification_dispatch(...)`.
5. Set Edge Function secrets and `supabase functions deploy` all four functions.

## Day 0 — App up

6. Configure env vars on the host (Vercel/Docker).
7. Deploy; confirm `GET /api/health` → `200`.
8. Point the custom domain at the app; set `NEXT_PUBLIC_APP_URL`/`APP_URL`.

## Day 0 — Seed the business

The database seeds only the singleton business settings row. Populate the rest
through the **Admin portal** (`/admin`) — the first admin is created by signing
up and then setting that profile's `role` to `admin` (via SQL or Supabase
Studio, since only an existing admin can promote others):

```sql
update public.profiles set role = 'admin' where email = 'you@example.com';
```

Then, as admin:

1. **Settings** — business name, timezone, currency, deposit %, hold duration,
   lead time, booking window, cancellation window, contact details.
2. **Rooms** — add treatment rooms.
3. **Services** — add the service catalogue (duration, buffers, price, deposit,
   room/intake requirements).
4. **Practitioners** — have practitioners sign up (role `practitioner`), then
   edit their profiles and set weekly availability.
5. **Forms** — publish the medical intake and consent templates
   (`create_template_version`).

## Day 1 — Verify the golden path

Run one real booking through the whole lifecycle:

1. As a client: browse → book a slot → hold created.
2. Pay the deposit (PayFast/Ozow sandbox first, then live) → webhook confirms.
3. Complete the intake form; sign consent.
4. Receive confirmation (email/WhatsApp).
5. As practitioner/admin: check in → in progress → completed.
6. Confirm the review request is queued; confirm audit + booking events.

## Day 1 — Turn on the lights

- Verify pg_cron is expiring holds and enqueuing reminders.
- Confirm the notification dispatcher is sending (Notification Centre).
- Enable uptime monitoring and alerting.
- Take a first off-platform backup (`scripts/backup.sh`).

## Go / No-go

Use the [Production Readiness Checklist](./PRODUCTION_CHECKLIST.md). Do not go
live with sandbox payment credentials or a missing `intake_encryption_key`.

---

## Rollback

- **App:** redeploy the previous build (Vercel keeps immutable deployments; for
  Docker, run the prior image tag).
- **Database:** migrations are forward-only. To reverse, write a new corrective
  migration. For a catastrophic failure, restore from the latest backup /
  Supabase PITR, then reconcile.
