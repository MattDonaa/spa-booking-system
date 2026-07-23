# Project Status

Project

Day Spa & Wellness Booking System

---

Current Phase

Authentication & Security Complete

---

Current Milestone

Milestone 3 – Authentication & Security (Complete)

---

Overall Progress

25%

---

Milestone Status

| Milestone      | Status      |
| -------------- | ----------- |
| Foundation     | ✅ Complete |
| Database       | ✅ Complete |
| Authentication | ✅ Complete |
| Booking Engine | Pending     |
| Payments       | Pending     |
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

Verification

- Milestone 1: `typecheck`, `lint`, `build` all pass.
- Milestones 2–3: all 17 SQL migrations + seed parse cleanly against the
  PostgreSQL grammar (via `libpg-query`). Full execution (`supabase db reset`)
  requires Docker/the Supabase CLI, which is not installed in this environment
  — see Blockers.

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

Milestone 3 – Authentication & Security — SQL authored and syntax-validated via
`libpg-query`.

---

Next Action

Await approval, then begin Milestone 4 – Booking Engine (RPC booking engine,
availability engine, locking, hold logic, state machine, buffer times).

---

Notes

This file is maintained by Claude Code.

Update after the successful completion of every milestone.

Never manually modify milestone progress unless instructed.
