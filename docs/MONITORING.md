# Monitoring & Observability

## Health checks

- `GET /api/health` returns `200 {"status":"ok","database":"ok",...}` when the
  app and database are reachable, and `503` otherwise.
- Consumed by: the Docker `HEALTHCHECK`, `docker-compose` healthcheck, the
  post-deploy smoke job, and any external uptime monitor.

## Logs

- The application logs through `src/lib/logger.ts` — structured JSON in
  production (level, message, timestamp, context), human-readable in
  development. Never log medical data, secrets, or full payment payloads.
- **Supabase** surfaces Postgres, Auth, Storage, and Edge Function logs in the
  Dashboard; configure a log drain for long-term retention.

## What to watch

| Signal                        | Where                                                              |
| ----------------------------- | ------------------------------------------------------------------ |
| App availability              | `/api/health` uptime monitor                                       |
| Error rate / stack traces     | Log aggregation (+ optional Sentry)                                |
| Payment webhook failures      | `payment_webhook_events.processing_error`, function logs           |
| Notification delivery         | `notifications` / `notification_queue` (admin Notification Centre) |
| Expired holds / cron activity | pg_cron job history, `booking_events`                              |
| Database performance          | Supabase Dashboard → Database → Reports                            |

## Alerts (recommended)

- Uptime monitor on `/api/health` (page on 2 consecutive failures).
- Alert when `notification_queue` has messages in `failed` status.
- Alert when `payment_webhook_events` accumulate `processing_error` rows.
- Supabase resource alerts (CPU, disk, connections).

## Error tracking (optional)

To add Sentry (or similar), initialise it in a Next.js `instrumentation.ts` and
forward `logger.error` calls. Keep DSNs in server-only env vars.
