# Project Status

Project

Day Spa & Wellness Booking System

---

Current Phase

Payments Complete

---

Current Milestone

Milestone 5 – Payments (Complete)

---

Overall Progress

42%

---

Milestone Status

| Milestone      | Status      |
| -------------- | ----------- |
| Foundation     | ✅ Complete |
| Database       | ✅ Complete |
| Authentication | ✅ Complete |
| Booking Engine | ✅ Complete |
| Payments       | ✅ Complete |
| Intake Forms   | Pending     |
| Notifications  | Pending     |
| Client Portal  | Pending     |
| Admin Portal   | Pending     |
| Analytics      | Pending     |
| Testing        | Pending     |
| Deployment     | Pending     |

---

Milestone 1 Deliverables

- ✅ Next.js (App Router) + React 19 + TypeScript (strict, `noUncheckedIndexedAccess`)
- ✅ Tailwind CSS + design tokens (light/dark) via CSS variables
- ✅ Shadcn UI (Button, Card) + `components.json`
- ✅ ESLint (flat config: next + typescript + prettier) — passes clean
- ✅ Prettier + `prettier-plugin-tailwindcss`
- ✅ Husky + lint-staged (pre-commit hook)
- ✅ Environment configuration with Zod validation (`src/lib/env.ts`) + `.env.example`
- ✅ Supabase clients: browser, server, admin (service-role, `server-only`), middleware session refresh
- ✅ Feature-first folder architecture (`src/features/*`) + service/repository conventions
- ✅ Server actions configured (health-check example following the standard pattern)
- ✅ Root middleware (session refresh)
- ✅ Structured logger (`src/lib/logger.ts`)
- ✅ Error boundaries (`error.tsx`, `global-error.tsx`), `not-found.tsx`, `loading.tsx`
- ✅ Fonts (Inter via `next/font`) + theme provider/toggle (`next-themes`)
- ✅ Reusable UI components + `Result<T>` / `AppError` contract
- ✅ README + installation instructions + security headers

---

Milestone 2 Deliverables

Schema delivered as ordered SQL migrations under `supabase/migrations/` plus
`supabase/config.toml` and `supabase/seed.sql`.

- ✅ Extensions: `pgcrypto` (UUIDs), `btree_gist` (exclusion constraints)
- ✅ Enum types: roles, booking status, booking event type, payment provider/type/status, refund status, notification channel/type/status, form type, intake status, availability block type, audit action
- ✅ Identity: `profiles` (1:1 auth.users), `clients`, `practitioners`
- ✅ Catalog: `service_categories`, `services`, `rooms`, `practitioner_services`, `business_settings` (singleton)
- ✅ Availability: `practitioner_availability` (recurring), `availability_blocks` (time off / holidays / maintenance)
- ✅ Bookings: `bookings` with GiST **exclusion constraints preventing overlapping bookings per practitioner and per room** (buffers included), full state-machine status enum, hold-expiry index
- ✅ Booking events: append-only `booking_events`, written automatically by trigger on creation and every status change
- ✅ Payments: `payments` (idempotency key, provider reference), `refunds`, `payment_webhook_events` (at-most-once via unique `(provider, event_id)`)
- ✅ Intake: `form_templates` (versioned JSON schema), `intake_forms` (medical-flagged), `consent_records` (signed, versioned)
- ✅ Notifications: `notification_queue` (retry/scheduling, dedupe) + `notifications` (per-attempt delivery log)
- ✅ Audit: central append-only `audit_logs` with before/after JSON, populated by trigger on all mutable business tables
- ✅ Cross-cutting: every table has `id`, `created_at`, `updated_at` (trigger-maintained), `deleted_at` (soft delete); hard deletes blocked on business tables via `prevent_hard_delete`; indexes, FKs, and check constraints throughout
- ✅ RLS enabled and forced (deny-by-default) on all 21 tables — policies come in Milestone 3
- ✅ Seed: singleton `business_settings` row only (no demo data)

---

Milestone 3 Deliverables

Security model delivered as SQL migrations `20260723130001`–`20260723130005`.

- ✅ Auth helpers (`private` schema, SECURITY DEFINER, RLS-safe): `current_app_role`, `is_admin`, `is_practitioner`, `is_staff`, `current_client_id`, `current_practitioner_id`
- ✅ Roles & permissions: anon (public catalog only), authenticated (row-scoped), client, practitioner, admin, and service-role separation
- ✅ New-user provisioning trigger (`handle_new_user`) creating a profile (+ client row) on `auth.users` insert
- ✅ Role-change guard trigger — only admins may change a profile's role
- ✅ JWT handling: `custom_access_token_hook` injecting a `user_role` claim, wired in `config.toml`
- ✅ RLS policies on **all 21 tables** — SELECT/INSERT/UPDATE, no DELETE (soft-delete only)
- ✅ Medical record protection: `intake_forms` / `consent_records` visible only to the owning client, the assigned practitioner, and admins (POPIA)
- ✅ Service-role separation: payments, refunds, webhook events, notifications, and audit logs are written only by the service role (no write policies); webhook events have no read policy either
- ✅ RPC permissions: `EXECUTE` revoked from `anon`/`authenticated`/`public` on functions plus default privileges locked, so future RPCs must opt in explicitly (Milestone 4)
- ✅ Storage: `avatars` (public), `intake-documents` & `consent-documents` (private) buckets with owner/staff/admin `storage.objects` policies; private medical buckets never publicly accessible

---

Milestone 4 Deliverables

Booking engine implemented entirely in PostgreSQL (migrations `20260723140001`–
`20260723140002`); the frontend never inserts bookings directly.

- ✅ State machine: `is_valid_booking_transition(from, to)` — pure, exhaustive
- ✅ Availability engine: `get_available_slots(service, from, to, practitioner?, step?)` honouring working hours, buffer times, existing bookings, blocks/holidays, room availability, lead time, and the max future window
- ✅ `create_booking(...)` RPC — transactional hold with `pg_advisory_xact_lock` per practitioner/room, `FOR UPDATE SKIP LOCKED` room auto-assignment, full validation, deposit calculation, and structured JSON responses; the GiST exclusion constraints are the final backstop
- ✅ `transition_booking(...)` — state-machine-validated status changes with `FOR UPDATE` row locking
- ✅ `cancel_booking(...)` — enforces the client cancellation window (staff/admin bypass)
- ✅ `reschedule_booking(...)` — re-validates availability under a lock, preserves identity, records a `rescheduled` event
- ✅ `expire_booking_holds()` — hold-expiry sweep (service-role only; wired to pg_cron in a later milestone)
- ✅ Buffer times, working hours, blocked dates, holiday support, lead times, and max booking window all enforced
- ✅ Structured `{ ok, data | error:{code,message} }` responses mirroring the app's `Result<T>`
- ✅ RPC permissions: `EXECUTE` granted explicitly to `authenticated`/`service_role` per function; the expiry sweep is service-role only
- ✅ Tests: pgTAP suites in `supabase/tests/` — 16 state-machine assertions + 12 engine assertions (create, double-book conflict, lead-time, transitions, hold expiry, availability re-offer)

---

Milestone 5 Deliverables

Payments only. SQL RPC (`20260723150001`) + Supabase Edge Functions under
`supabase/functions/`.

- ✅ Payment engine RPCs (state in Postgres, never trusted from client): `initiate_payment` (idempotent, amount computed server-side), `record_payment_event` (verified webhook applied exactly once, advances booking), `initiate_refund`, `record_refund_event`
- ✅ Idempotency: payment/refund `idempotency_key` uniqueness + at-most-once webhook processing via unique `(provider, event_id)`
- ✅ Gateway abstraction: single `PaymentGateway` interface (`buildRedirect`, `verifyWebhook`, `refund`) + factory; Edge Functions are provider-agnostic
- ✅ PayFast gateway: MD5-signed redirect, ITN signature verification, refund API call
- ✅ Ozow gateway: SHA-512 HashCheck redirect, notification hash verification, refund API call
- ✅ Signature verification: enforced in each gateway; unverified webhooks recorded (forensics) and rejected
- ✅ Edge Functions: `payments-initiate` (JWT, user-scoped RPC), `payments-webhook` (public, signature-verified, service role), `payments-refund` (JWT, staff/admin)
- ✅ Retry logic: webhook returns 5xx on transient/DB errors (provider re-delivers), 4xx on permanent failures (no retry), 200 on success/already-processed
- ✅ Audit logging: automatic via the `record_audit` triggers on `payments`/`refunds`
- ✅ Service-role separation: webhook appliers are service-role only; JWT verification configured per function in `config.toml`

---

Verification

- Milestone 1: `typecheck`, `lint`, `build` all pass. After M5, `typecheck` and
  `lint` still pass (the Deno `supabase/` tree is excluded from the app
  toolchain and linted separately with Deno).
- Milestones 2–5: all 20 SQL migrations + seed + both pgTAP test files parse
  cleanly against the PostgreSQL grammar (via `libpg-query`). Full execution
  (`supabase db reset`, `supabase test db`, `supabase functions serve`) requires
  Docker/the Supabase CLI, which is not installed in this environment — see
  Blockers.

---

Known Issues

- 3 high-severity npm advisories remain, all in dependencies bundled **inside**
  Next.js (`postcss`, `sharp`). They cannot be resolved without a Next.js patch
  release; npm's suggested "fix" downgrades Next to 9.x and is not applicable.
  The critical Next.js advisories from the initial pin were resolved by
  upgrading Next `15.1.4` → `15.5.21`.

---

Technical Debt

- `src/lib/supabase/types.ts` is still a placeholder `Database` type. It must be
  regenerated against a live project once the schema is applied:
  `npx supabase gen types typescript --local > src/lib/supabase/types.ts`.

---

Current Blockers

- No local PostgreSQL/Docker/Supabase CLI is available in this environment, so
  migrations were validated by parsing (syntax) rather than by execution. They
  should be run end-to-end with `supabase db reset` before deployment to confirm
  runtime semantics (extension operator classes, trigger behaviour, exclusion
  constraints). This does not block Milestone 3.

---

Last Review

Milestone 5 – Payments — SQL RPCs, gateway abstraction, and Edge Functions
authored; SQL syntax-validated via `libpg-query`; app `typecheck`/`lint` pass.
Deno function execution pending a Supabase/Docker environment.

---

Next Action

Await approval, then begin Milestone 6 – Intake Forms (dynamic forms, consent,
versioning, medical forms).

---

Notes

This file is maintained by Claude Code.

Update after the successful completion of every milestone.

Never manually modify milestone progress unless instructed.
