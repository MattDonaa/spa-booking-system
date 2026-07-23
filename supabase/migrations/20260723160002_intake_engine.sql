-- ============================================================================
-- Migration: Intake Engine (RPCs)
-- ----------------------------------------------------------------------------
-- Dynamic, versioned intake forms with autosave, validation, e-signature
-- consent, and medical encryption. All logic lives in PostgreSQL; the frontend
-- calls these RPCs. Medical responses are encrypted at rest and only decrypted
-- inside authorization-checked SECURITY DEFINER functions.
--
--   * validate_intake            — required-field validation against a schema.
--   * instantiate_intake_forms   — create the form instances for a booking.
--   * save_intake_response       — autosave (partial merge).
--   * submit_intake_form         — validate + finalize.
--   * get_intake_form            — read with access control + decryption.
--   * record_consent             — capture signed consent (versioned).
--   * create_template_version    — publish a new template version (admin).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- private.validate_intake: returns a JSON array of {key, message} for every
-- required field missing from the responses. Empty array == valid.
-- ----------------------------------------------------------------------------
create or replace function private.validate_intake(
  p_schema jsonb,
  p_responses jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_field jsonb;
  v_key text;
  v_node jsonb;
begin
  for v_field in
    select value from jsonb_array_elements(coalesce(p_schema, '[]'::jsonb))
  loop
    if coalesce((v_field ->> 'required')::boolean, false) then
      v_key := v_field ->> 'key';
      v_node := p_responses -> v_key;

      if v_node is null
         or (jsonb_typeof(v_node) = 'string' and length(btrim(v_node #>> '{}')) = 0)
         or (jsonb_typeof(v_node) = 'array' and jsonb_array_length(v_node) = 0)
         or (jsonb_typeof(v_node) = 'null')
      then
        v_errors := v_errors || jsonb_build_object(
          'key', v_key,
          'message', coalesce(v_field ->> 'label', v_key) || ' is required.'
        );
      end if;
    end if;
  end loop;

  return v_errors;
end;
$$;

-- ----------------------------------------------------------------------------
-- Internal: does the current caller own or manage this intake form?
-- ----------------------------------------------------------------------------
create or replace function private.can_access_intake(p_form public.intake_forms)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    private.is_service_role()
    or private.is_admin()
    or p_form.client_id = private.current_client_id()
    or exists (
      select 1 from public.bookings b
      where b.id = p_form.booking_id
        and b.practitioner_id = private.current_practitioner_id()
    );
$$;

-- ----------------------------------------------------------------------------
-- instantiate_intake_forms: create the intake form instances for a booking.
-- ----------------------------------------------------------------------------
create or replace function public.instantiate_intake_forms(
  p_booking_id uuid,
  p_template_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_booking public.bookings;
  v_created jsonb := '[]'::jsonb;
  v_tpl record;
begin
  select * into v_booking
  from public.bookings where id = p_booking_id and deleted_at is null;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Booking not found.');
  end if;

  if not private.is_service_role()
     and not private.is_staff()
     and v_booking.client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN', 'Not permitted for this booking.');
  end if;

  for v_tpl in
    select t.id, t.is_medical
    from public.form_templates t
    where t.deleted_at is null
      and t.is_active
      and (
        p_template_ids is not null and t.id = any (p_template_ids)
        or (
          p_template_ids is null
          and t.form_type in ('medical_intake', 'general_intake')
        )
      )
  loop
    insert into public.intake_forms (
      booking_id, client_id, template_id, status, is_medical
    )
    values (
      p_booking_id, v_booking.client_id, v_tpl.id, 'pending', v_tpl.is_medical
    )
    on conflict (booking_id, template_id) where (deleted_at is null)
    do nothing;

    v_created := v_created || to_jsonb(v_tpl.id);
  end loop;

  return private.rpc_ok(jsonb_build_object(
    'booking_id', p_booking_id, 'template_ids', v_created));
end;
$$;

comment on function public.instantiate_intake_forms is
  'Creates intake form instances for a booking from active templates.';

-- ----------------------------------------------------------------------------
-- Internal: persist merged responses, encrypting when the form is medical.
-- ----------------------------------------------------------------------------
create or replace function private.write_intake_responses(
  p_form_id uuid,
  p_is_medical boolean,
  p_merged jsonb,
  p_status public.intake_status,
  p_submitted boolean
)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if p_is_medical then
    update public.intake_forms
    set responses = '{}'::jsonb,
        responses_encrypted = private.encrypt_intake(p_merged),
        encrypted_at = now(),
        status = p_status,
        submitted_at = case when p_submitted then now() else submitted_at end
    where id = p_form_id;
  else
    update public.intake_forms
    set responses = p_merged,
        responses_encrypted = null,
        encrypted_at = null,
        status = p_status,
        submitted_at = case when p_submitted then now() else submitted_at end
    where id = p_form_id;
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- save_intake_response: autosave. Merges partial responses; never validates.
-- ----------------------------------------------------------------------------
create or replace function public.save_intake_response(
  p_intake_form_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_form public.intake_forms;
  v_existing jsonb;
  v_merged jsonb;
begin
  select * into v_form
  from public.intake_forms where id = p_intake_form_id and deleted_at is null
  for update;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Intake form not found.');
  end if;

  if not private.can_access_intake(v_form) then
    return private.rpc_err('FORBIDDEN', 'Not permitted for this form.');
  end if;

  if v_form.status = 'completed' then
    return private.rpc_err('CONFLICT', 'This form has already been submitted.');
  end if;

  v_existing := case
    when v_form.is_medical then private.decrypt_intake(v_form.responses_encrypted)
    else v_form.responses
  end;
  v_merged := coalesce(v_existing, '{}'::jsonb) || coalesce(p_responses, '{}'::jsonb);

  perform private.write_intake_responses(
    v_form.id, v_form.is_medical, v_merged, 'in_progress', false);

  return private.rpc_ok(jsonb_build_object(
    'intake_form_id', v_form.id, 'status', 'in_progress', 'saved_at', now()));
end;
$$;

comment on function public.save_intake_response is
  'Autosave: merges partial intake responses without validation.';

-- ----------------------------------------------------------------------------
-- submit_intake_form: validate required fields, then finalize.
-- ----------------------------------------------------------------------------
create or replace function public.submit_intake_form(
  p_intake_form_id uuid,
  p_responses jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_form public.intake_forms;
  v_schema jsonb;
  v_existing jsonb;
  v_merged jsonb;
  v_errors jsonb;
begin
  select * into v_form
  from public.intake_forms where id = p_intake_form_id and deleted_at is null
  for update;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Intake form not found.');
  end if;

  if not private.can_access_intake(v_form) then
    return private.rpc_err('FORBIDDEN', 'Not permitted for this form.');
  end if;

  if v_form.status = 'completed' then
    return private.rpc_err('CONFLICT', 'This form has already been submitted.');
  end if;

  select t.schema into v_schema
  from public.form_templates t where t.id = v_form.template_id;

  v_existing := case
    when v_form.is_medical then private.decrypt_intake(v_form.responses_encrypted)
    else v_form.responses
  end;
  v_merged := coalesce(v_existing, '{}'::jsonb) || coalesce(p_responses, '{}'::jsonb);

  v_errors := private.validate_intake(v_schema, v_merged);
  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object(
      'ok', false,
      'error', jsonb_build_object(
        'code', 'VALIDATION',
        'message', 'Please complete all required fields.',
        'fields', v_errors));
  end if;

  perform private.write_intake_responses(
    v_form.id, v_form.is_medical, v_merged, 'completed', true);

  return private.rpc_ok(jsonb_build_object(
    'intake_form_id', v_form.id, 'status', 'completed'));
end;
$$;

comment on function public.submit_intake_form is
  'Validates required fields and finalizes an intake form submission.';

-- ----------------------------------------------------------------------------
-- get_intake_form: read a form with its template schema and (decrypted)
-- responses, subject to access control.
-- ----------------------------------------------------------------------------
create or replace function public.get_intake_form(
  p_intake_form_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  v_form public.intake_forms;
  v_template public.form_templates;
  v_responses jsonb;
begin
  select * into v_form
  from public.intake_forms where id = p_intake_form_id and deleted_at is null;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Intake form not found.');
  end if;

  if not private.can_access_intake(v_form) then
    return private.rpc_err('FORBIDDEN', 'Not permitted for this form.');
  end if;

  select * into v_template
  from public.form_templates where id = v_form.template_id;

  v_responses := case
    when v_form.is_medical then private.decrypt_intake(v_form.responses_encrypted)
    else v_form.responses
  end;

  return private.rpc_ok(jsonb_build_object(
    'intake_form_id', v_form.id,
    'booking_id', v_form.booking_id,
    'status', v_form.status,
    'is_medical', v_form.is_medical,
    'submitted_at', v_form.submitted_at,
    'template', jsonb_build_object(
      'id', v_template.id,
      'name', v_template.name,
      'slug', v_template.slug,
      'version', v_template.version,
      'form_type', v_template.form_type,
      'schema', v_template.schema),
    'responses', coalesce(v_responses, '{}'::jsonb)));
end;
$$;

comment on function public.get_intake_form is
  'Returns an intake form with schema and access-controlled, decrypted responses.';

-- ----------------------------------------------------------------------------
-- record_consent: capture a signed consent record, versioned to the template.
-- ----------------------------------------------------------------------------
create or replace function public.record_consent(
  p_template_id uuid,
  p_consent_given boolean,
  p_booking_id uuid default null,
  p_signature text default null,
  p_ip inet default null,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_template public.form_templates;
  v_client_id uuid;
  v_consent_id uuid;
begin
  select * into v_template
  from public.form_templates
  where id = p_template_id and deleted_at is null and is_active;
  if not found then
    return private.rpc_err('NOT_FOUND', 'Consent template not found.');
  end if;

  -- Resolve the client: from the booking if given, else the caller.
  if p_booking_id is not null then
    select client_id into v_client_id
    from public.bookings where id = p_booking_id and deleted_at is null;
    if v_client_id is null then
      return private.rpc_err('NOT_FOUND', 'Booking not found.');
    end if;
  else
    v_client_id := private.current_client_id();
  end if;

  if v_client_id is null then
    return private.rpc_err('VALIDATION', 'A client is required.');
  end if;

  if not private.is_service_role()
     and not private.is_staff()
     and v_client_id is distinct from private.current_client_id() then
    return private.rpc_err('FORBIDDEN', 'Not permitted to sign for this client.');
  end if;

  insert into public.consent_records (
    client_id, booking_id, template_id, template_version,
    consent_given, signature, ip_address, user_agent
  )
  values (
    v_client_id, p_booking_id, p_template_id, v_template.version,
    p_consent_given, p_signature, p_ip, p_user_agent
  )
  returning id into v_consent_id;

  return private.rpc_ok(jsonb_build_object(
    'consent_id', v_consent_id,
    'template_version', v_template.version,
    'consent_given', p_consent_given));
end;
$$;

comment on function public.record_consent is
  'Records a versioned, signed consent entry for a client.';

-- ----------------------------------------------------------------------------
-- create_template_version: publish a new version of a form template (admin).
-- ----------------------------------------------------------------------------
create or replace function public.create_template_version(
  p_slug text,
  p_name text,
  p_form_type public.form_type,
  p_schema jsonb,
  p_description text default null,
  p_is_medical boolean default false,
  p_publish boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_version integer;
  v_id uuid;
begin
  if not private.is_admin() and not private.is_service_role() then
    return private.rpc_err('FORBIDDEN', 'Only administrators may edit templates.');
  end if;

  if jsonb_typeof(p_schema) is distinct from 'array' then
    return private.rpc_err('VALIDATION', 'Template schema must be a JSON array.');
  end if;

  select coalesce(max(version), 0) + 1 into v_version
  from public.form_templates where slug = p_slug;

  insert into public.form_templates (
    name, slug, description, form_type, version, schema,
    is_medical, is_active, published_at
  )
  values (
    p_name, p_slug, p_description, p_form_type, v_version, p_schema,
    p_is_medical, p_publish, case when p_publish then now() else null end
  )
  returning id into v_id;

  return private.rpc_ok(jsonb_build_object(
    'template_id', v_id, 'slug', p_slug, 'version', v_version));
end;
$$;

comment on function public.create_template_version is
  'Publishes a new version of a form template (versioning). Admin only.';

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
grant execute on function
  public.instantiate_intake_forms(uuid, uuid[]),
  public.save_intake_response(uuid, jsonb),
  public.submit_intake_form(uuid, jsonb),
  public.get_intake_form(uuid),
  public.record_consent(uuid, boolean, uuid, text, inet, text),
  public.create_template_version(text, text, public.form_type, jsonb, text, boolean, boolean)
to authenticated, service_role;
