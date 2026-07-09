-- Every league's season was a fixed 10-week fixture list generated once -
-- once those matches were all played, the league would just stop forever
-- (no more fixtures, standings frozen) with no way to keep playing. This
-- makes seasons roll over automatically: generalizes
-- generate_season_fixtures_for_league to number seasons correctly instead
-- of hardcoding "1. Sezon", and adds advance_completed_seasons(), which
-- closes out any season whose fixtures are all played (crowning whoever's
-- top of the standings as champion) and immediately generates a fresh
-- 10-week season behind it - checked daily by cron.

CREATE OR REPLACE FUNCTION public.generate_season_fixtures_for_league(p_league_id UUID)
RETURNS void AS $$
DECLARE
  season_id_var UUID;
  season_number INT;
  week_no INT;
  shuffled UUID[];
  n INT;
  i INT;
  season_start TIMESTAMPTZ := date_trunc('hour', now()) + interval '1 hour';
BEGIN
  SELECT count(*) + 1 INTO season_number FROM public.seasons WHERE league_id = p_league_id;

  INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
  VALUES (p_league_id, season_number || '. Sezon', season_start, 1, true)
  RETURNING id INTO season_id_var;

  FOR week_no IN 1..10 LOOP
    SELECT array_agg(id ORDER BY random()) INTO shuffled
    FROM public.clubs WHERE league_id = p_league_id;

    n := COALESCE(array_length(shuffled, 1), 0);
    CONTINUE WHEN n < 2;
    IF n % 2 = 1 THEN n := n - 1; END IF;

    FOR i IN 1..n BY 2 LOOP
      INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
      VALUES (
        p_league_id, season_id_var, week_no, shuffled[i], shuffled[i + 1],
        season_start + (week_no - 1) * interval '7 days',
        false
      );
    END LOOP;
  END LOOP;

  UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.advance_completed_seasons()
RETURNS void AS $$
DECLARE
  season_rec RECORD;
  champion_id UUID;
BEGIN
  FOR season_rec IN
    SELECT s.id, s.league_id
    FROM public.seasons s
    WHERE s.is_active = true
      AND s.is_completed = false
      AND EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id)
      AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id AND m.is_played = false)
  LOOP
    SELECT club_id INTO champion_id
    FROM public.league_standings
    WHERE season_id = season_rec.id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC
    LIMIT 1;

    UPDATE public.seasons
    SET is_completed = true, is_active = false, champion_club_id = champion_id, end_date = now()
    WHERE id = season_rec.id;

    PERFORM public.generate_season_fixtures_for_league(season_rec.league_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'advance-completed-seasons';
SELECT cron.schedule(
  'advance-completed-seasons',
  '30 3 * * *',
  $$SELECT public.advance_completed_seasons();$$
);
