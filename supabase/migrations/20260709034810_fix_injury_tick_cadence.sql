-- daily_player_tick decremented injury_duration_weeks by 1 on its daily
-- (0 3 * * *) schedule - a column that's supposed to mean "weeks remaining"
-- was clearing a 3-week injury in 3 days. Split fitness regen (genuinely
-- daily) from injury recovery (weekly) into two functions on two schedules.
CREATE OR REPLACE FUNCTION public.daily_player_tick()
RETURNS void AS $$
BEGIN
  UPDATE public.players
  SET fitness = LEAST(100, fitness + 5)
  WHERE fitness < 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.weekly_injury_recovery()
RETURNS void AS $$
BEGIN
  UPDATE public.players
  SET injury_duration_weeks = GREATEST(0, injury_duration_weeks - 1),
      is_suspended = GREATEST(0, injury_duration_weeks - 1) > 0
  WHERE injury_duration_weeks > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'weekly-injury-recovery';
SELECT cron.schedule(
  'weekly-injury-recovery',
  '0 3 * * 1',
  $$SELECT public.weekly_injury_recovery();$$
);
