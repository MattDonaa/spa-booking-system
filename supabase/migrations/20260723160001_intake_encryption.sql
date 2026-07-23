-- ============================================================================
-- Migration: Intake — Encryption at Rest (POPIA)
-- ----------------------------------------------------------------------------
-- Medical intake responses are sensitive personal information and are stored
-- encrypted at rest, in addition to the RLS access controls from Milestone 3.
--
-- Encryption uses pgcrypto's PGP symmetric cipher. The key is sourced from
-- Supabase Vault (secret name `intake_encryption_key`), falling back to the
-- `app.intake_encryption_key` GUC for local/dev. Decryption is only ever
-- performed inside SECURITY DEFINER RPCs that first enforce authorization, so
-- plaintext never crosses an RLS boundary.
-- ============================================================================

-- Encrypted payload for medical intake responses. Non-medical responses remain
-- in the plain `responses` jsonb column.
alter table public.intake_forms
  add column if not exists responses_encrypted bytea,
  add column if not exists encrypted_at timestamptz;

comment on column public.intake_forms.responses_encrypted is
  'PGP-symmetric-encrypted JSON of medical responses (POPIA). Decrypt only via RPC.';

-- ----------------------------------------------------------------------------
-- private.intake_encryption_key: resolve the symmetric key.
-- ----------------------------------------------------------------------------
create or replace function private.intake_encryption_key()
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_key text;
begin
  -- Prefer Supabase Vault when available.
  begin
    execute
      'select decrypted_secret from vault.decrypted_secrets '
      || 'where name = ''intake_encryption_key'' limit 1'
    into v_key;
  exception
    when others then
      v_key := null;
  end;

  v_key := coalesce(
    v_key,
    nullif(current_setting('app.intake_encryption_key', true), '')
  );

  if v_key is null or length(v_key) = 0 then
    raise exception
      'Intake encryption key is not configured (Vault secret intake_encryption_key).'
      using errcode = 'config_file_error';
  end if;

  return v_key;
end;
$$;

-- ----------------------------------------------------------------------------
-- private.encrypt_intake / decrypt_intake
-- ----------------------------------------------------------------------------
create or replace function private.encrypt_intake(p_data jsonb)
returns bytea
language sql
security definer
set search_path = public, extensions
as $$
  select extensions.pgp_sym_encrypt(p_data::text, private.intake_encryption_key());
$$;

create or replace function private.decrypt_intake(p_data bytea)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  select case
    when p_data is null then '{}'::jsonb
    else extensions.pgp_sym_decrypt(p_data, private.intake_encryption_key())::jsonb
  end;
$$;

-- These helpers must never be callable directly by API roles.
revoke execute on function
  private.intake_encryption_key(),
  private.encrypt_intake(jsonb),
  private.decrypt_intake(bytea)
from anon, authenticated, public;
