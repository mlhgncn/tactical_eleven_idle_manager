-- Single wrapper + cron tick that applies any completed player
-- development, sponsor upgrade, or club development regardless of
-- whether the owning user's app is open (mirrors the existing
-- auto-resolve-matches pattern, but these are plain SQL - no edge
-- function/HTTP hop needed).
CREATE OR REPLACE FUNCTION public.process_timed_upgrades()
RETURNS void AS $$
BEGIN
  PERFORM public.process_player_development();
  PERFORM public.process_sponsor_upgrades();
  PERFORM public.process_club_upgrades();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'process-timed-upgrades';
SELECT cron.schedule(
  'process-timed-upgrades',
  '*/15 * * * *',
  $$SELECT public.process_timed_upgrades();$$
);
