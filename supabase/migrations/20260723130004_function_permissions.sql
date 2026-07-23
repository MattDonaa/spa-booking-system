-- ============================================================================
-- Migration: Function / RPC Permissions
-- ----------------------------------------------------------------------------
-- Least-privilege for callable functions. Every function in `public` is
-- currently a trigger function (set_updated_at, record_audit, ...); none is a
-- deliberate RPC yet. Trigger functions do not require EXECUTE to fire, so we
-- revoke EXECUTE from API roles to keep them off the PostgREST RPC surface.
-- Genuine RPCs (the booking engine) are added in Milestone 4 and will grant
-- EXECUTE explicitly, one function at a time.
-- ============================================================================

-- Revoke the default PUBLIC execute grant on existing and future public
-- functions from the API roles.
revoke execute on all functions in schema public from anon, authenticated;

alter default privileges in schema public
  revoke execute on functions from anon, authenticated;

-- Also revoke the implicit PUBLIC grant so new functions are locked by default;
-- each RPC must opt in with an explicit GRANT.
alter default privileges in schema public
  revoke execute on functions from public;
