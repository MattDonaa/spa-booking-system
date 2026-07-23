# Features

Feature-first architecture. Each feature is a self-contained vertical slice and
owns its own UI, server actions, services, repositories, validation schemas, and
types. Features never import from each other's internals — shared logic belongs
in `src/lib` or `src/components`.

## Standard feature layout

```
features/<feature>/
  components/     # Feature-scoped React components
  actions/        # 'use server' entry points (thin; validate + delegate)
  services/       # Business logic orchestration (the service layer)
  repositories/   # Data access (Supabase queries; the only DB touch point)
  schemas/        # Zod validation schemas
  types.ts        # Feature-local types
```

## Rules

- **Server actions are thin.** They validate input with a Zod schema and
  delegate to a service. No business logic inline.
- **Services hold business logic.** They orchestrate repositories and enforce
  rules. They return `Result<T>` (see `src/lib/result.ts`), never throw across
  boundaries.
- **Repositories are the only place that talks to the database.** Swappable and
  independently testable.
- **The database is the source of truth.** Critical booking and payment rules
  live in PostgreSQL (RPC functions, constraints, RLS), added in later
  milestones. The service layer coordinates; it does not replace DB guarantees.

Planned features: `auth`, `services` (catalog), `booking`, `availability`,
`payments`, `intake`, `notifications`, `client-portal`, `admin`, `analytics`.
