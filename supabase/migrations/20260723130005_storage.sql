-- ============================================================================
-- Migration: Storage Buckets & Policies
-- ----------------------------------------------------------------------------
-- Three buckets:
--   * avatars           — public read; each user manages files under their own
--                         profile-id folder.
--   * intake-documents  — PRIVATE. Attachments to medical intake forms.
--   * consent-documents — PRIVATE. Signed consent PDFs / images.
--
-- Path convention for the private buckets: `<profile_uid>/<...>`. Ownership is
-- established by matching the first path segment to auth.uid(). Staff
-- (practitioner/admin) may read private files; only admins may delete them.
-- Nothing in the private buckets is ever publicly accessible (POPIA).
-- ============================================================================

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('intake-documents', 'intake-documents', false),
  ('consent-documents', 'consent-documents', false)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- avatars (public bucket)
-- ----------------------------------------------------------------------------
create policy "avatars: public read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'avatars');

create policy "avatars: owner insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- intake-documents (private bucket) — medical protection
-- ----------------------------------------------------------------------------
create policy "intake-documents: read owner or staff"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'intake-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  );

create policy "intake-documents: owner or staff insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'intake-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  );

create policy "intake-documents: owner or staff update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'intake-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  )
  with check (
    bucket_id = 'intake-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  );

create policy "intake-documents: admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'intake-documents' and private.is_admin());

-- ----------------------------------------------------------------------------
-- consent-documents (private bucket)
-- ----------------------------------------------------------------------------
create policy "consent-documents: read owner or staff"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'consent-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  );

create policy "consent-documents: owner or staff insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'consent-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_staff()
    )
  );

create policy "consent-documents: admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'consent-documents' and private.is_admin());
