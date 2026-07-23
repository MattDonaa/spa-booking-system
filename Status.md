# Project Status

Project

Day Spa & Wellness Booking System

---

Current Phase

Database Complete

---

Current Milestone

Milestone 2 – Database (Complete)

---

Overall Progress

16%

---

Milestone Status

| Milestone      | Status      |
| -------------- | ----------- |
| Foundation     | ✅ Complete |
| Database       | ✅ Complete |
| Authentication | Pending     |
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

Verification

- Milestone 1: `typecheck`, `lint`, `build` all pass.
- Milestone 2: all 13 SQL files parse cleanly against the PostgreSQL grammar
  (via `libpg-query`). Full execution (`supabase db reset`) requires Docker/the
  Supabase CLI, which is not installed in this environment — see Blockers.

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

Milestone 2 – Database — SQL authored and syntax-validated via `libpg-query`.

---

Next Action

Await approval, then begin Milestone 3 – Authentication & Security (RLS policies,
roles, storage policies).

---

Notes

This file is maintained by Claude Code.

Update after the successful completion of every milestone.

Never manually modify milestone progress unless instructed.
