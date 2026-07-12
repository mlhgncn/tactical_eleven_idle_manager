-- Module 6: Tactic Hide (prevents scout_opponent from revealing this
-- club's tactics for their next match) and Team Camp (+5% performance for
-- the next match). Both are per-match, one-shot effects tied to a
-- specific upcoming match_id so they can't accidentally apply to more
-- than one fixture. Each gets 1 (tactic hide) / 2 (camp) free uses per
-- season, refilled when a new season's fixtures are generated; extra
-- uses are purchased with diamonds via consumable_products.

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS tactic_hidden_for_match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS free_tactic_hides_this_season INT NOT NULL DEFAULT 1;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS tactic_hide_charges INT NOT NULL DEFAULT 0;

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS camp_active_for_match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS free_camp_uses_this_season INT NOT NULL DEFAULT 2;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS camp_charges INT NOT NULL DEFAULT 0;

-- Generic diamond-purchasable consumable catalog - same read-only,
-- SECURITY DEFINER-mutated pattern as player_packs/diamond_products.
CREATE TABLE IF NOT EXISTS public.consumable_products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  diamond_cost INT NOT NULL,
  effect_type TEXT NOT NULL CHECK (effect_type IN ('tactic_hide', 'camp')),
  grant_quantity INT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO public.consumable_products (id, name, diamond_cost, effect_type, grant_quantity, sort_order) VALUES
  ('tactic_hide_5', '5 Adet Taktik Gizleme', 50, 'tactic_hide', 5, 1),
  ('camp_5', '5 Kamp Hakkı', 50, 'camp', 5, 2)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  diamond_cost = EXCLUDED.diamond_cost,
  effect_type = EXCLUDED.effect_type,
  grant_quantity = EXCLUDED.grant_quantity,
  sort_order = EXCLUDED.sort_order;

ALTER TABLE public.consumable_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS consumable_products_select_policy ON public.consumable_products;
CREATE POLICY consumable_products_select_policy ON public.consumable_products FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.purchase_consumable(p_product_id TEXT, p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  product_row public.consumable_products%ROWTYPE;
  current_diamonds BIGINT;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot purchase';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO product_row FROM public.consumable_products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown product';
  END IF;

  SELECT diamonds INTO current_diamonds FROM public.profiles WHERE id = auth.uid() FOR UPDATE;
  IF current_diamonds IS NULL OR current_diamonds < product_row.diamond_cost THEN
    RAISE EXCEPTION 'Yetersiz elmas bakiyesi';
  END IF;
  UPDATE public.profiles SET diamonds = diamonds - product_row.diamond_cost WHERE id = auth.uid();

  IF product_row.effect_type = 'tactic_hide' THEN
    UPDATE public.clubs SET tactic_hide_charges = tactic_hide_charges + product_row.grant_quantity
    WHERE id = club_row.id RETURNING * INTO updated_row;
  ELSE
    UPDATE public.clubs SET camp_charges = camp_charges + product_row.grant_quantity
    WHERE id = club_row.id RETURNING * INTO updated_row;
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Hides this club's tactics from scout_opponent for their next unplayed
-- match. Uses a free seasonal charge first, falls back to a purchased one.
CREATE OR REPLACE FUNCTION public.hide_tactics_for_next_match(p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  next_match_id UUID;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  IF club_row.free_tactic_hides_this_season <= 0 AND club_row.tactic_hide_charges <= 0 THEN
    RAISE EXCEPTION 'Taktik gizleme hakkınız kalmadı. Marketten satın alabilirsiniz.';
  END IF;

  SELECT id INTO next_match_id
  FROM public.matches
  WHERE (home_club_id = club_row.id OR away_club_id = club_row.id) AND is_played = false
  ORDER BY match_date ASC
  LIMIT 1;

  IF next_match_id IS NULL THEN
    RAISE EXCEPTION 'Oynanacak yaklaşan maç bulunamadı.';
  END IF;

  IF club_row.free_tactic_hides_this_season > 0 THEN
    UPDATE public.clubs
    SET tactic_hidden_for_match_id = next_match_id, free_tactic_hides_this_season = free_tactic_hides_this_season - 1
    WHERE id = club_row.id RETURNING * INTO updated_row;
  ELSE
    UPDATE public.clubs
    SET tactic_hidden_for_match_id = next_match_id, tactic_hide_charges = tactic_hide_charges - 1
    WHERE id = club_row.id RETURNING * INTO updated_row;
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Sends the team to camp for their next unplayed match (+5% performance,
-- applied in match_engine.ts). Uses a free seasonal charge first.
CREATE OR REPLACE FUNCTION public.send_team_to_camp(p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  next_match_id UUID;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  IF club_row.free_camp_uses_this_season <= 0 AND club_row.camp_charges <= 0 THEN
    RAISE EXCEPTION 'Kamp hakkınız kalmadı. Marketten satın alabilirsiniz.';
  END IF;

  SELECT id INTO next_match_id
  FROM public.matches
  WHERE (home_club_id = club_row.id OR away_club_id = club_row.id) AND is_played = false
  ORDER BY match_date ASC
  LIMIT 1;

  IF next_match_id IS NULL THEN
    RAISE EXCEPTION 'Oynanacak yaklaşan maç bulunamadı.';
  END IF;

  IF club_row.free_camp_uses_this_season > 0 THEN
    UPDATE public.clubs
    SET camp_active_for_match_id = next_match_id, free_camp_uses_this_season = free_camp_uses_this_season - 1
    WHERE id = club_row.id RETURNING * INTO updated_row;
  ELSE
    UPDATE public.clubs
    SET camp_active_for_match_id = next_match_id, camp_charges = camp_charges - 1
    WHERE id = club_row.id RETURNING * INTO updated_row;
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- scout_opponent: no longer reveals tactics if the opponent has hidden
-- them for this specific match.
CREATE OR REPLACE FUNCTION public.scout_opponent(p_match_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  caller_club_id UUID;
  opponent_club_id_var UUID;
  opponent_hidden BOOLEAN;
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot scout an opponent';
  END IF;

  SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  IF caller_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Maç bulunamadı';
  END IF;

  IF match_row.home_club_id != caller_club_id AND match_row.away_club_id != caller_club_id THEN
    RAISE EXCEPTION 'Bu maçın tarafı değilsiniz';
  END IF;

  IF match_row.is_played THEN
    RAISE EXCEPTION 'Bu maç zaten oynandı';
  END IF;

  IF match_row.match_date > now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'Rakip kadrosu maça 15 dakika kalana kadar görüntülenemez';
  END IF;

  opponent_club_id_var := CASE
    WHEN match_row.home_club_id = caller_club_id THEN match_row.away_club_id
    ELSE match_row.home_club_id
  END;

  SELECT (tactic_hidden_for_match_id = p_match_id) INTO opponent_hidden
  FROM public.clubs WHERE id = opponent_club_id_var;

  SELECT json_build_object(
    'club_id', opponent_club_id_var,
    'players', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', p.id,
        'name', p.name,
        'position', p.position,
        'age', p.age,
        'current_ability', p.current_ability,
        'is_suspended', p.is_suspended,
        'injury_duration_weeks', p.injury_duration_weeks
      )), '[]'::json)
      FROM public.players p WHERE p.club_id = opponent_club_id_var
    ),
    'tactics_hidden', COALESCE(opponent_hidden, false),
    'tactics', (
      CASE WHEN COALESCE(opponent_hidden, false) THEN NULL ELSE (
        SELECT COALESCE(
          (SELECT row_to_json(t) FROM (
            SELECT formation, mentality, starting_eleven_ids, press_intensity, tempo,
                   defensive_line, offside_trap, time_wasting
            FROM public.tactics WHERE club_id = opponent_club_id_var
          ) t),
          CASE WHEN (SELECT user_id FROM public.clubs WHERE id = opponent_club_id_var) IS NULL THEN
            json_build_object(
              'formation', 'f442',
              'mentality', 'balanced',
              'starting_eleven_ids', NULL,
              'press_intensity', 50,
              'tempo', 50,
              'defensive_line', 50,
              'offside_trap', false,
              'time_wasting', false
            )
          ELSE NULL END
        )
      ) END
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- Refill the free seasonal charges whenever a league's fixtures are
-- (re)generated for a new season - same call site used both for a
-- brand-new league and for advance_completed_seasons' rollover.
CREATE OR REPLACE FUNCTION public.generate_season_fixtures_for_league(p_league_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  season_id_var UUID;
  season_number INT;
  club_ids UUID[];
  n INT;
  half INT;
  single_rounds INT;
  round_no INT;
  day_no INT;
  i INT;
  home_id UUID;
  away_id UUID;
  last_elem UUID;
  season_start TIMESTAMPTZ := (date_trunc('day', (now() + interval '48 hours') AT TIME ZONE 'Europe/Istanbul') + interval '21 hours') AT TIME ZONE 'Europe/Istanbul';
BEGIN
  IF season_start < now() + interval '48 hours' THEN
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

  -- Reset seasonal free perk counters for every club in this league.
  UPDATE public.clubs
  SET free_tactic_hides_this_season = 1, free_camp_uses_this_season = 2
  WHERE league_id = p_league_id;

  SELECT array_agg(id ORDER BY random()) INTO club_ids FROM public.clubs WHERE league_id = p_league_id;
  n := COALESCE(array_length(club_ids, 1), 0);

  IF n < 2 THEN
    UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
    RETURN;
  END IF;

  IF n % 2 = 1 THEN
    club_ids := array_append(club_ids, NULL);
    n := n + 1;
  END IF;

  half := n / 2;
  single_rounds := n - 1;

  FOR round_no IN 1..single_rounds LOOP
    day_no := round_no;

    FOR i IN 1..half LOOP
      home_id := club_ids[i];
      away_id := club_ids[n + 1 - i];

      IF home_id IS NOT NULL AND away_id IS NOT NULL THEN
        IF round_no % 2 = 0 THEN
          INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
          VALUES (p_league_id, season_id_var, day_no, away_id, home_id, season_start + (day_no - 1) * interval '1 day', false);
        ELSE
          INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
          VALUES (p_league_id, season_id_var, day_no, home_id, away_id, season_start + (day_no - 1) * interval '1 day', false);
        END IF;
      END IF;
    END LOOP;

    last_elem := club_ids[n];
    FOR i IN REVERSE n..3 LOOP
      club_ids[i] := club_ids[i - 1];
    END LOOP;
    club_ids[2] := last_elem;
  END LOOP;

  FOR round_no IN 1..single_rounds LOOP
    day_no := single_rounds + round_no;
    INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
    SELECT p_league_id, season_id_var, day_no, m.away_club_id, m.home_club_id,
           season_start + (day_no - 1) * interval '1 day', false
    FROM public.matches m
    WHERE m.season_id = season_id_var AND m.week = round_no;
  END LOOP;

  UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.purchase_consumable(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hide_tactics_for_next_match(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_team_to_camp(UUID) TO authenticated;
