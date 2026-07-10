-- Matches were spaced 1 week apart, kicking off at "next hour from season
-- creation time" - switching to daily fixtures kicking off at a fixed
-- 21:00 Europe/Istanbul (Turkey has used a fixed UTC+3 offset, no DST,
-- since 2016), and anchoring the first fixture to the next upcoming 21:00
-- slot rather than whatever hour the season happened to be created in.
CREATE OR REPLACE FUNCTION public.generate_season_fixtures_for_league(p_league_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  season_id_var UUID;
  season_number INT;
  day_no INT;
  shuffled UUID[];
  n INT;
  i INT;
  season_start TIMESTAMPTZ := (date_trunc('day', now() AT TIME ZONE 'Europe/Istanbul') + interval '21 hours') AT TIME ZONE 'Europe/Istanbul';
BEGIN
  IF season_start <= now() THEN
    season_start := season_start + interval '1 day';
  END IF;

  SELECT count(*) + 1 INTO season_number FROM public.seasons WHERE league_id = p_league_id;

  INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
  VALUES (p_league_id, season_number || '. Sezon', season_start, 1, true)
  RETURNING id INTO season_id_var;

  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  SELECT season_id_var, id, 0, 0, 0, 0, 0, 0, 0, 0, NULL
  FROM public.clubs WHERE league_id = p_league_id
  ON CONFLICT (season_id, club_id) DO NOTHING;

  FOR day_no IN 1..10 LOOP
    SELECT array_agg(id ORDER BY random()) INTO shuffled
    FROM public.clubs WHERE league_id = p_league_id;

    n := COALESCE(array_length(shuffled, 1), 0);
    CONTINUE WHEN n < 2;
    IF n % 2 = 1 THEN n := n - 1; END IF;

    FOR i IN 1..n BY 2 LOOP
      INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
      VALUES (
        p_league_id, season_id_var, day_no, shuffled[i], shuffled[i + 1],
        season_start + (day_no - 1) * interval '1 day',
        false
      );
    END LOOP;
  END LOOP;

  UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
END;
$function$;
