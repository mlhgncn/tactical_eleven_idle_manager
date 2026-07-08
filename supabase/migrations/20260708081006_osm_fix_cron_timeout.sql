-- auto_resolve_matches was timing out: net.http_post defaults to a 5s
-- timeout, but resolving a batch of matches (each several sequential DB
-- round-trips) easily takes longer once there's a real backlog - confirmed
-- via net._http_response showing "Timeout of 5000 ms reached" on both cron
-- ticks after the league/season/fixture bootstrap created 321 due matches.
-- Raise the HTTP timeout to 30s; BATCH_LIMIT is also being lowered
-- separately (in the edge function itself) so each invocation reliably
-- finishes well inside that window, draining a large backlog over several
-- 5-minute ticks instead of trying to do it all in one slow call.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'auto-resolve-matches';
SELECT cron.schedule(
  'auto-resolve-matches',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://dfdidifutotlxvvslzrl.supabase.co/functions/v1/auto_resolve_matches',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT value FROM public.environment_secrets WHERE key = 'CRON_SHARED_SECRET')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);
