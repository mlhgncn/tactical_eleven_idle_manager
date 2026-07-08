-- OSM pivot, part 3: bootstrap the competition structure.
--
-- The entire league/season/fixture system was never actually initialized in
-- production: 0 leagues, 0 seasons, 0 matches, and all 642 clubs had
-- league_id = NULL. play_next_fixture always returning "no upcoming match
-- found" wasn't a bug in that function - there was simply no fixture data
-- for it to find. This creates ~18-club leagues out of the existing clubs,
-- an active season for each, and 10 weeks of weekly fixtures (random
-- pairing per week rather than a strict round-robin - good enough for a
-- mobile idle/OSM game, and much simpler to get right than circle-method
-- scheduling across 30+ unevenly-sized leagues).

DO $$
DECLARE
  club_rec RECORD;
  league_id_var UUID;
  clubs_in_current_league INT := 0;
  league_size INT := 18;
  league_counter INT := 0;
BEGIN
  -- Only run once - if any club already has a league, skip entirely.
  IF EXISTS (SELECT 1 FROM public.clubs WHERE league_id IS NOT NULL) THEN
    RETURN;
  END IF;

  FOR club_rec IN SELECT id FROM public.clubs ORDER BY random() LOOP
    IF clubs_in_current_league = 0 THEN
      league_counter := league_counter + 1;
      INSERT INTO public.leagues (name, tier, is_active)
      VALUES ('Lig ' || league_counter, 1, true)
      RETURNING id INTO league_id_var;
    END IF;

    UPDATE public.clubs SET league_id = league_id_var WHERE id = club_rec.id;

    clubs_in_current_league := clubs_in_current_league + 1;
    IF clubs_in_current_league >= league_size THEN
      clubs_in_current_league := 0;
    END IF;
  END LOOP;
END $$;

DO $$
DECLARE
  league_rec RECORD;
  season_id_var UUID;
  week_no INT;
  shuffled UUID[];
  n INT;
  i INT;
  season_start TIMESTAMPTZ := date_trunc('hour', now()) + interval '1 hour';
BEGIN
  FOR league_rec IN SELECT id FROM public.leagues LOOP
    INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
    VALUES (league_rec.id, '1. Sezon', season_start, 1, true)
    RETURNING id INTO season_id_var;

    FOR week_no IN 1..10 LOOP
      SELECT array_agg(id ORDER BY random()) INTO shuffled
      FROM public.clubs WHERE league_id = league_rec.id;

      n := COALESCE(array_length(shuffled, 1), 0);
      CONTINUE WHEN n < 2;
      IF n % 2 = 1 THEN n := n - 1; END IF;

      FOR i IN 1..n BY 2 LOOP
        INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
        VALUES (
          league_rec.id, season_id_var, week_no, shuffled[i], shuffled[i + 1],
          season_start + (week_no - 1) * interval '7 days',
          false
        );
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
