-- ============================================================================
-- Migration: Scheduled Jobs (pg_cron + pg_net)
-- ----------------------------------------------------------------------------
-- Wires the periodic jobs that drive the engine:
--   * expire-booking-holds   — every minute (Milestone 4 sweep).
--   * enqueue-due-reminders   — every 5 minutes (reminder/review/rebooking).
--   * dispatch-notifications  — HTTP-invokes the notifications-dispatch Edge
--     Function; scheduled via private.setup_notification_dispatch() once the
--     project URL and service-role key are known (they are not available at
--     migration time), so it is provided as a setup function rather than run
--     here.
--
-- The pure-SQL jobs are scheduled inline, guarded by extension availability so
-- the migration is safe in environments without pg_cron.
-- ============================================================================

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Recreate idempotently.
    perform cron.unschedule('expire-booking-holds')
      where exists (select 1 from cron.job where jobname = 'expire-booking-holds');
    perform cron.unschedule('enqueue-due-reminders')
      where exists (select 1 from cron.job where jobname = 'enqueue-due-reminders');

    perform cron.schedule(
      'expire-booking-holds', '* * * * *',
      'select public.expire_booking_holds();');

    perform cron.schedule(
      'enqueue-due-reminders', '*/5 * * * *',
      'select public.enqueue_due_reminders();');
  else
    raise notice 'pg_cron not installed; skipping scheduled SQL jobs.';
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- setup_notification_dispatch: schedule the HTTP dispatch job. Admins call this
-- once with the project's functions base URL and service-role key. Requires
-- pg_cron and pg_net. Kept out of the default migration path because it needs
-- runtime secrets.
-- ----------------------------------------------------------------------------
create or replace function private.setup_notification_dispatch(
  p_functions_base_url text,
  p_service_role_key text,
  p_schedule text default '* * * * *'
)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise exception 'pg_cron and pg_net are required for HTTP dispatch scheduling.';
  end if;

  perform cron.unschedule('dispatch-notifications')
    where exists (select 1 from cron.job where jobname = 'dispatch-notifications');

  perform cron.schedule(
    'dispatch-notifications',
    p_schedule,
    format(
      $job$
        select net.http_post(
          url := %L,
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', %L),
          body := '{}'::jsonb
        );
      $job$,
      rtrim(p_functions_base_url, '/') || '/notifications-dispatch',
      'Bearer ' || p_service_role_key
    )
  );
end;
$$;

comment on function private.setup_notification_dispatch is
  'Schedules the notifications-dispatch Edge Function via pg_cron + pg_net.';

revoke execute on function
  private.setup_notification_dispatch(text, text, text)
from anon, authenticated, public;
