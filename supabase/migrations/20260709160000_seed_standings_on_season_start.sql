-- league_standings rows were only ever created lazily, the first time a
-- club's match got resolved (inside update_standings_after_match's
-- INSERT ... ON CONFLICT DO NOTHING). That meant a freshly created league -
-- 18 clubs, season + fixtures already generated - showed a completely empty
-- table until someone's first kickoff time passed and the cron resolved it,
-- instead of every team appearing at 0 played like a real league table.
-- Seed a zero row for every club the moment a season starts, and backfill
-- any currently active season that's missing rows for clubs that simply
-- haven't played yet.

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

  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  SELECT season_id_var, id, 0, 0, 0, 0, 0, 0, 0, 0, NULL
  FROM public.clubs WHERE league_id = p_league_id
  ON CONFLICT (season_id, club_id) DO NOTHING;

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

INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
SELECT s.id, c.id, 0, 0, 0, 0, 0, 0, 0, 0, NULL
FROM public.seasons s
JOIN public.clubs c ON c.league_id = s.league_id
WHERE s.is_active = true
ON CONFLICT (season_id, club_id) DO NOTHING;
