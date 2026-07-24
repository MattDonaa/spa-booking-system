# Project Status

Project

Day Spa & Wellness Booking System

---

Current Phase

Analytics Complete

---

Current Milestone

Milestone 10 – Analytics (Complete)

---

Overall Progress

83%

---

Milestone Status

| Milestone      | Status      |
| -------------- | ----------- |
| Foundation     | ✅ Complete |
| Database       | ✅ Complete |
| Authentication | ✅ Complete |
| Booking Engine | ✅ Complete |
| Payments       | ✅ Complete |
| Intake Forms   | ✅ Complete |
| Notifications  | ✅ Complete |
| Client Portal  | ✅ Complete |
| Admin Portal   | ✅ Complete |
| Analytics      | ✅ Complete |
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

Milestone 6 Deliverables

Intake engine in PostgreSQL (`20260723160001`–`20260723160002`) plus a compiling
`src/features/intake` feature module.

- ✅ Dynamic templates: JSON field-schema templates rendered by a generic form renderer (`DynamicIntakeForm` + `FieldRenderer`) supporting text/textarea/number/date/select/radio/checkbox/boolean
- ✅ Versioning: `create_template_version` publishes a new version per slug (admin)
- ✅ Medical questionnaires: `is_medical` templates and form instances
- ✅ Encrypted storage (POPIA): medical responses encrypted at rest with pgcrypto PGP symmetric cipher, key from Supabase Vault; decryption only inside authorization-checked RPCs
- ✅ Practitioner-only access: `can_access_intake` limits reads to the owning client, the assigned practitioner, and admins (on top of RLS)
- ✅ Submission flow: `instantiate_intake_forms` → autosave (`save_intake_response`) → `submit_intake_form`
- ✅ Validation: server-side required-field validation (`validate_intake`) mirrored client-side via a dynamically built Zod validator
- ✅ Autosave: debounced `useAutosave` hook + partial-merge autosave RPC, with save status indicator
- ✅ Electronic signatures & consent tracking: canvas `SignaturePad` + `record_consent` (versioned, captures signature/IP/user-agent)

---

Milestone 7 Deliverables

Notification engine in PostgreSQL (`20260723170001`–`20260723170004`) + the
`notifications-dispatch` Edge Function.

- ✅ SMS channel added to the `notification_channel` enum (email + WhatsApp + SMS)
- ✅ Notification queue (from M2) driven by RPCs: `enqueue_notification` (dedupe), `claim_due_notifications` (worker claim via FOR UPDATE SKIP LOCKED), `mark_notification_sent`, `mark_notification_failed`
- ✅ Workers: `notifications-dispatch` Edge Function claims, renders, sends, and reports outcomes; authorized by the service-role key header
- ✅ Retries: exponential backoff (2^attempts min, capped at 60) up to `max_attempts`, then terminal failure
- ✅ Templates: versioned, per-channel `notification_templates` table with `{{placeholder}}` interpolation + seeded English defaults for all channels
- ✅ Channel senders (gateway abstraction): Email (Resend), WhatsApp (Meta Cloud API), SMS (generic HTTP gateway)
- ✅ Reminder scheduler: `schedule_booking_notifications` (confirmation + 24h reminder) and `enqueue_due_reminders` (cron sweep)
- ✅ Review requests (post-visit) and rebooking reminders (~6 weeks later), deduplicated
- ✅ Delivery logs: every attempt recorded in the `notifications` table
- ✅ Scheduling: guarded pg_cron jobs (hold expiry + reminder sweep) and `private.setup_notification_dispatch` for the pg_net HTTP dispatch job

---

Milestone 8 Deliverables

Client portal (`src/app/(portal)`, `src/features/{auth,portal}`) on client-scoped
read RPCs (`20260723180001`). Nothing admin.

- ✅ Auth: email/password sign in/up/out server actions; `/login` + `/signup`; middleware guards `/portal` and bounces signed-in users off the auth pages; new accounts provisioned via the M3 signup trigger
- ✅ Dashboard: upcoming-appointment and pending-form counts + next appointments
- ✅ Bookings: upcoming/past tabs; detail page with appointment, intake forms, and payments
- ✅ Reschedule & Cancel: client actions calling the M4 RPCs (cancellation window + availability enforced server-side)
- ✅ Payments & Invoices: payment history list + per-payment invoice view
- ✅ Forms: list of the client's intake forms + fill flow reusing the M6 `DynamicIntakeForm`
- ✅ History: past bookings tab
- ✅ Profile: view/edit name, phone, DOB, emergency contact, marketing opt-in
- ✅ Client-portal read RPCs: `get_my_profile`, `update_my_profile`, `list_my_bookings`, `get_my_booking`, `list_my_payments`, `list_my_intake_forms` (all client-scoped, JSON envelopes)
- ✅ New shared UI/util: `Badge`, `Input`, `Label`, `Textarea`, money/date formatters, RPC unwrap helper

---

Milestone 9 Deliverables

Admin portal (`src/app/(admin)`, `src/features/admin`) on admin-guarded RPCs
(`20260723190001`). Admin-only: the layout redirects non-admins to `/portal`.

- ✅ Dashboard: today's/upcoming bookings, pending payments, month revenue, active practitioners, pending forms
- ✅ Calendar: 14-day schedule grouped by day
- ✅ Bookings: filterable list with client/practitioner/service/room
- ✅ Practitioners: edit title/bio/specialties and activate/deactivate
- ✅ Services: create/edit/toggle (duration, buffers, price, deposit, room/intake flags)
- ✅ Rooms: create/edit/toggle (capacity, features)
- ✅ Availability: per-practitioner schedule + blocks, with add-block
- ✅ Payments: 30-day payment list
- ✅ Forms: versioned template inventory
- ✅ Reports: bookings/revenue/refunds summary (deeper analytics in M10)
- ✅ Notification centre: queue + delivery status with retry for failed messages
- ✅ Audit logs: 100 most recent mutations
- ✅ Settings: full business-settings editor
- ✅ Admin RPCs: dashboard, list bookings/payments/audit/notifications/templates, practitioner update, service/room upsert, availability list + add block, settings get/update, reports, notification retry — all `is_admin`/`is_staff`-gated
- ✅ New shared UI: `Table` primitive

---

Milestone 10 Deliverables

Analytics (`/admin/analytics`) on admin-gated aggregate RPCs (`20260723200001`).

- ✅ Revenue: daily revenue column chart + total; refunds
- ✅ Conversion: created→confirmed conversion rate
- ✅ Abandoned bookings: expired-hold count
- ✅ Occupancy / practitioner utilisation: booked vs available minutes from the recurring schedule, per practitioner
- ✅ Popular treatments: bookings + revenue per service (bar list)
- ✅ No-shows and cancellation trends: booking-outcome breakdown
- ✅ Average booking value: mean completed-booking price
- ✅ Lifetime value: average LTV + top clients by spend
- ✅ Analytics RPCs: `analytics_overview`, `analytics_services`, `analytics_practitioners`, `analytics_clients`
- ✅ Lightweight, dependency-free, theme-aware charts (`StatTile`, `BarList`, `ColumnChart`)

---

Verification

- App `typecheck`, `lint`, and `build` all pass — **25 routes** (14 admin + 9
  portal + home + auth); admin/portal server-rendered on demand.
- Milestones 2–10: all 29 SQL migrations + seed + both pgTAP test files parse
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

Milestone 10 – Analytics — aggregate RPCs and the analytics dashboard authored.
SQL syntax-validated via `libpg-query`; app `typecheck`, `lint`, and `build` all
pass (25 routes).

---

Next Action

Await approval, then begin Milestone 11 – Testing (unit, integration, Playwright,
concurrency tests).

---

Notes

This file is maintained by Claude Code.

Update after the successful completion of every milestone.

Never manually modify milestone progress unless instructed.
