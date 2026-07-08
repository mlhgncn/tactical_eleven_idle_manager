-- OSM pivot, part 4: auto-assign new signups to a league + starting roster.
--
-- createClub() (the "make a brand new club" path, as opposed to claiming an
-- existing bot club) inserted a bare clubs row with no league_id and no
-- players at all - a new user would land in a club with an empty squad and
-- no fixtures. This makes every new club, the moment it's created for a
-- real user, automatically:
--   1. Join a "recruiting" league (one whose season/fixtures haven't been
--      generated yet and has room) so new players start together in a
--      freshly-starting league rather than joining an already-advanced
--      one; once that league fills up (18 clubs), its season and 10 weeks
--      of fixtures are generated immediately and a new recruiting league
--      opens up behind it.
--   2. Get a full 30-34 player roster generated with the same
--      quality-tiered, position-appropriate approach as the one-time
--      player data overhaul.

ALTER TABLE public.leagues ADD COLUMN IF NOT EXISTS season_generated BOOLEAN NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.generate_squad_for_club(p_club_id UUID, p_quality INT DEFAULT NULL)
RETURNS void AS $$
DECLARE
  club_quality INT := COALESCE(p_quality, 30 + floor(random() * 45)::int);
  target_count INT := 30 + floor(random() * 5)::int;
  i INT;
  chosen_pos TEXT;
  gen_ca INT;
  gen_age INT;
  gen_pa INT;
  pos_pool TEXT[] := ARRAY['GK','CB','CB','LB','RB','CDM','CM','CM','CAM','LM','RM','ST','ST','LW','RW'];
  first_names TEXT[] := ARRAY[
    'Ariel','Bruno','Cesar','Diego','Erik','Felix','Gustavo','Hugo','Ivan','Jonas',
    'Kwame','Lars','Marco','Nils','Omar','Pedro','Quinten','Rafael','Sami','Tomas',
    'Umut','Viktor','Wesley','Xander','Yusuf','Zoltan','Adam','Bilal','Carlos','Denis',
    'Emre','Fabio','Giorgio','Hakan','Igor','Jamal','Kevin','Luca','Milan','Nico',
    'Oscar','Pablo','Quincy','Ruben','Stefan','Tarik','Urs','Vasco','Walid','Yannick'
  ];
  last_names TEXT[] := ARRAY[
    'Aydin','Berg','Costa','Duarte','Eriksen','Fischer','Garcia','Hansen','Ibrahim','Jansen',
    'Kovac','Lindberg','Martins','Novak','Oliveira','Petrov','Quiroga','Rossi','Santos','Tanaka',
    'Ulrich','Vidal','Weber','Xhaka','Yildiz','Zeman','Andersson','Batista','Costello','Dimitrov',
    'Ekstrom','Ferreira','Gomez','Hoffmann','Ivanovic','Johansson','Kruger','Larsen','Mendes','Nilsson',
    'Ostrowski','Perez','Radic','Sorensen','Torres','Uzun','Varga','Wagner','Yamamoto','Zorc'
  ];
BEGIN
  FOR i IN 1..target_count LOOP
    chosen_pos := pos_pool[1 + floor(random() * array_length(pos_pool, 1))::int];
    gen_ca := GREATEST(20, LEAST(95, club_quality + floor(random() * 30 - 12)))::int;
    gen_age := (17 + floor(random() * 17))::int;
    gen_pa := LEAST(99, gen_ca + (
      CASE
        WHEN gen_age <= 21 THEN (5 + floor(random() * 22))::int
        WHEN gen_age <= 27 THEN floor(random() * 10)::int
        ELSE floor(random() * 3)::int
      END
    ));

    INSERT INTO public.players (
      club_id, name, position, current_ability, potential_ability, age,
      morale, fitness, finishing, passing, tackling, composure,
      determination, consistency, injury_proneness
    ) VALUES (
      p_club_id,
      first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' ||
        last_names[1 + floor(random() * array_length(last_names, 1))::int],
      chosen_pos,
      gen_ca, gen_pa, gen_age,
      (65 + floor(random() * 25))::int,
      (85 + floor(random() * 16))::int,
      GREATEST(5, LEAST(20, CASE
        WHEN chosen_pos IN ('ST','LW','RW') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
        WHEN chosen_pos IN ('CM','CDM','CAM','LM','RM') THEN (gen_ca / 5 + floor(random() * 3))::int
        ELSE (gen_ca / 6)::int
      END)),
      GREATEST(5, LEAST(20, CASE
        WHEN chosen_pos IN ('CM','CDM','CAM','LM','RM') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
        ELSE (gen_ca / 6 + floor(random() * 2))::int
      END)),
      GREATEST(5, LEAST(20, CASE
        WHEN chosen_pos IN ('CB','LB','RB') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
        ELSE (gen_ca / 8)::int
      END)),
      (8 + floor(random() * 10))::int,
      (8 + floor(random() * 10))::int,
      (8 + floor(random() * 10))::int,
      (3 + floor(random() * 10))::int
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.generate_season_fixtures_for_league(p_league_id UUID)
RETURNS void AS $$
DECLARE
  season_id_var UUID;
  week_no INT;
  shuffled UUID[];
  n INT;
  i INT;
  season_start TIMESTAMPTZ := date_trunc('hour', now()) + interval '1 hour';
BEGIN
  INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
  VALUES (p_league_id, '1. Sezon', season_start, 1, true)
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

CREATE OR REPLACE FUNCTION public.onboard_new_club()
RETURNS TRIGGER AS $$
DECLARE
  target_league_id UUID;
  member_count INT;
  league_counter INT;
BEGIN
  -- Find a recruiting league (season not generated yet, room for more clubs).
  SELECT l.id INTO target_league_id
  FROM public.leagues l
  WHERE l.season_generated = false
    AND (SELECT count(*) FROM public.clubs c WHERE c.league_id = l.id) < 18
  ORDER BY l.created_at ASC
  LIMIT 1
  FOR UPDATE OF l;

  IF target_league_id IS NULL THEN
    SELECT count(*) INTO league_counter FROM public.leagues;
    INSERT INTO public.leagues (name, tier, is_active, season_generated)
    VALUES ('Lig ' || (league_counter + 1), 1, true, false)
    RETURNING id INTO target_league_id;
  END IF;

  UPDATE public.clubs SET league_id = target_league_id WHERE id = NEW.id;

  SELECT count(*) INTO member_count FROM public.clubs WHERE league_id = target_league_id;
  IF member_count >= 18 THEN
    PERFORM public.generate_season_fixtures_for_league(target_league_id);
  END IF;

  PERFORM public.generate_squad_for_club(NEW.id, NULL);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS onboard_new_club_trigger ON public.clubs;
CREATE TRIGGER onboard_new_club_trigger
AFTER INSERT ON public.clubs
FOR EACH ROW
WHEN (NEW.user_id IS NOT NULL)
EXECUTE FUNCTION public.onboard_new_club();
