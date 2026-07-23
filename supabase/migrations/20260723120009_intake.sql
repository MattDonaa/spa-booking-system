-- ============================================================================
-- Migration: Intake Forms, Templates & Consent
-- ----------------------------------------------------------------------------
-- Form templates are versioned. Intake form instances capture a client's
-- responses (including sensitive medical data) and consent records capture
-- signed agreements. Access to medical data is restricted to the assigned
-- practitioner and admins via Row Level Security (Milestone 3) — these tables
-- must never be publicly readable (POPIA).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- form_templates: versioned form definitions. The field schema is stored as
-- JSON so forms can be authored without migrations. (name, version) is unique.
-- ----------------------------------------------------------------------------
create table public.form_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  slug text not null,
  description text,
  form_type public.form_type not null default 'general_intake',
  version integer not null default 1,
  -- Array of field definitions (label, key, type, required, options, ...).
  schema jsonb not null default '[]',
  -- Whether this template collects sensitive medical information.
  is_medical boolean not null default false,
  is_active boolean not null default true,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint form_templates_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint form_templates_version_positive_chk check (version > 0),
  constraint form_templates_schema_is_array_chk
    check (jsonb_typeof(schema) = 'array')
);

create unique index form_templates_name_version_unique_idx
  on public.form_templates (slug, version)
  where deleted_at is null;

create index form_templates_type_idx on public.form_templates (form_type)
  where deleted_at is null;

comment on table public.form_templates is
  'Versioned form definitions (JSON schema of fields). Unique per (slug, version).';

-- ----------------------------------------------------------------------------
-- intake_forms: a client's instance of a template, tied to a booking.
-- Responses may contain sensitive medical information.
-- ----------------------------------------------------------------------------
create table public.intake_forms (
  id uuid primary key default extensions.gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete restrict,
  template_id uuid not null references public.form_templates (id) on delete restrict,
  status public.intake_status not null default 'pending',
  -- Submitted answers keyed by the template field keys. Sensitive.
  responses jsonb not null default '{}',
  is_medical boolean not null default false,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index intake_forms_booking_template_unique_idx
  on public.intake_forms (booking_id, template_id)
  where deleted_at is null;

create index intake_forms_client_idx on public.intake_forms (client_id);
create index intake_forms_status_idx on public.intake_forms (status)
  where deleted_at is null;

comment on table public.intake_forms is
  'Client intake form instances. Responses may hold medical data; RLS-restricted.';

-- ----------------------------------------------------------------------------
-- consent_records: signed consent, versioned against the template used.
-- ----------------------------------------------------------------------------
create table public.consent_records (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  booking_id uuid references public.bookings (id) on delete set null,
  template_id uuid not null references public.form_templates (id) on delete restrict,
  template_version integer not null,
  consent_given boolean not null,
  -- Electronic signature captured at signing time (e.g. typed name / image).
  signature text,
  signed_at timestamptz not null default now(),
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint consent_records_version_positive_chk check (template_version > 0)
);

create index consent_records_client_idx on public.consent_records (client_id);
create index consent_records_booking_idx on public.consent_records (booking_id);

comment on table public.consent_records is
  'Signed consent records, versioned against the template. Immutable legal evidence.';

-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
create trigger set_updated_at before update on public.form_templates
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.intake_forms
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.consent_records
  for each row execute function public.set_updated_at();

create trigger prevent_hard_delete before delete on public.form_templates
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.intake_forms
  for each row execute function public.prevent_hard_delete();
create trigger prevent_hard_delete before delete on public.consent_records
  for each row execute function public.prevent_hard_delete();

create trigger record_audit
  after insert or update or delete on public.form_templates
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.intake_forms
  for each row execute function public.record_audit();
create trigger record_audit
  after insert or update or delete on public.consent_records
  for each row execute function public.record_audit();
