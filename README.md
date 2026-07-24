# Serenity — Day Spa & Wellness Booking System

A production-grade online booking platform for day spas and wellness clinics.
Clients can discover services, book appointments, complete intake forms, pay
deposits, and manage bookings without staff intervention.

> **Version 1.0 — MVP.** This repository is built as a commercial SaaS product,
> not a prototype. See [`Project_Spec.md`](./Project_Spec.md),
> [`Roadmap.md`](./Roadmap.md), and [`CLAUDE.md`](./CLAUDE.md) for the full
> specification, milestone plan, and engineering constitution.

---

## Tech Stack

| Layer         | Technology                                          |
| ------------- | --------------------------------------------------- |
| Framework     | Next.js (App Router), React 19, TypeScript (strict) |
| Styling       | Tailwind CSS, Shadcn UI, `next-themes`              |
| Backend       | Supabase (PostgreSQL, Auth, Edge Functions, RLS)    |
| Validation    | Zod                                                 |
| Payments      | PayFast, Ozow _(added in later milestones)_         |
| Notifications | WhatsApp, Email _(added in later milestones)_       |
| Tooling       | ESLint, Prettier, Husky, lint-staged                |

---

## Prerequisites

- **Node.js** `>= 20`
- **npm** `>= 10`
- A **Supabase** project (free tier is fine for development)

---

## Getting Started

### 1. Install dependencies

```bash
npm install
```

### 2. Configure environment variables

Copy the example file and fill in your Supabase credentials:

```bash
cp .env.example .env.local
```

At minimum, set the following (found in your Supabase project's API settings):

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — **server-only, never expose to the client**

Environment variables are validated at startup (see
[`src/lib/env.ts`](./src/lib/env.ts)). The app fails fast with a descriptive
error if any required value is missing or malformed.

### 3. Run the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## Available Scripts

| Script                 | Description                                |
| ---------------------- | ------------------------------------------ |
| `npm run dev`          | Start the development server               |
| `npm run build`        | Create a production build                  |
| `npm run start`        | Run the production build                   |
| `npm run lint`         | Run ESLint                                 |
| `npm run lint:fix`     | Run ESLint with autofix                    |
| `npm run format`       | Format all files with Prettier             |
| `npm run format:check` | Check formatting without writing           |
| `npm run typecheck`    | Type-check the project with `tsc --noEmit` |
| `npm run validate-env` | Verify required environment variables      |
| `npm test`             | Unit, component, and accessibility tests   |
| `npm run test:e2e`     | Playwright end-to-end tests                |

---

## Testing

- **Unit / component / a11y** — Vitest + Testing Library + `vitest-axe`
  (`npm test`).
- **Database (RPC / webhook / RLS / concurrency)** — pgTAP in `supabase/tests/`
  (`supabase test db`).
- **End-to-end + accessibility** — Playwright in `e2e/` (`npm run test:e2e`).
- **Performance** — k6 script in `perf/`.

## Deployment

Production build emits a standalone server (`output: 'standalone'`) for a slim
Docker image; a `Dockerfile` and `docker-compose.yml` are included. CI/CD runs
via GitHub Actions (`.github/workflows/`). See the guides:

- [`docs/DEPLOYMENT.md`](./docs/DEPLOYMENT.md) — full deployment reference
- [`docs/LAUNCH_GUIDE.md`](./docs/LAUNCH_GUIDE.md) — step-by-step go-live
- [`docs/PRODUCTION_CHECKLIST.md`](./docs/PRODUCTION_CHECKLIST.md) — readiness gate
- [`docs/MONITORING.md`](./docs/MONITORING.md) — health checks & observability

Health endpoint: `GET /api/health`.

---

## Project Structure

```
src/
  app/                 # Next.js App Router (routes, layouts, error/loading UI)
  components/
    ui/                # Shadcn UI primitives
    theme-provider.tsx # next-themes provider
    theme-toggle.tsx   # Light/dark toggle
  features/            # Feature-first vertical slices (see features/README.md)
    <feature>/
      components/
      actions/         # 'use server' entry points
      services/        # Business logic
      repositories/    # Data access (Supabase)
      schemas/         # Zod validation
  lib/
    env.ts             # Validated environment config
    logger.ts          # Structured logger (never console.log directly)
    result.ts          # Result<T> / AppError contract
    utils.ts           # cn() Tailwind helper
    supabase/
      client.ts        # Browser client (anon key, RLS-enforced)
      server.ts        # Server client (anon key, RLS-enforced)
      admin.ts         # Service-role client (server-only, bypasses RLS)
      middleware.ts    # Session refresh
      types.ts         # Generated DB types (placeholder until Milestone 2)
middleware.ts          # Root middleware (session refresh)
```

---

## Architecture Principles

- **The database is the source of truth.** Critical business rules (booking,
  payments) are enforced in PostgreSQL via constraints, RPC functions, and RLS.
- **The frontend is a presentation layer.** Server actions are thin; business
  logic lives in the service layer and the database.
- **Never trust the client** — especially for payments.
- **Security by default** — Row Level Security on all sensitive tables; medical
  data is never publicly accessible; the app is built to comply with POPIA.
- **Everything is auditable** — booking state changes and mutations produce
  audit records (added in later milestones).

See [`CLAUDE.md`](./CLAUDE.md) for the complete engineering constitution.

---

## Development Workflow

Git hooks are managed by **Husky**. On every commit, **lint-staged** runs ESLint
and Prettier against staged files, so committed code is always linted and
formatted. Run `npm install` once to activate the hooks (via the `prepare`
script).

---

## Roadmap

Development proceeds in 12 milestones — see [`Roadmap.md`](./Roadmap.md). The
current status is tracked in [`Status.md`](./Status.md).

1. **Project Foundation** ✅
2. Database
3. Authentication & Security
4. Booking Engine
5. Payments
6. Intake Forms
7. Notification Engine
8. Client Portal
9. Admin Portal
10. Analytics
11. Testing
12. Deployment
