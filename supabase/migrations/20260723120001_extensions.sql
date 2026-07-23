-- ============================================================================
-- Migration: Extensions
-- ----------------------------------------------------------------------------
-- Enables the PostgreSQL extensions the schema depends on. Installed into the
-- dedicated `extensions` schema (Supabase convention) to keep `public` clean.
-- ============================================================================

create schema if not exists extensions;

-- gen_random_uuid() for primary keys.
create extension if not exists pgcrypto with schema extensions;

-- GiST support for scalar types, required by the exclusion constraints that
-- prevent overlapping bookings (no double bookings — see bookings migration).
create extension if not exists btree_gist with schema extensions;
