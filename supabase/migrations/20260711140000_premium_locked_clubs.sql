-- League creation becomes a two-step, user-driven picker instead of an
-- instant random assignment: pick a theme -> see the full 18-club list
-- (name + quality) for that league -> pick a free club, or spend 100
-- diamonds to claim one of the 3 curated "premium" (much stronger) clubs.
-- create_league_and_join(p_theme) is superseded by preview_league_theme +
-- select_club_for_league; left in place (not dropped) since it costs
-- nothing to keep and avoids breaking anything still referencing it.

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS is_premium_locked BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS premium_unlock_cost INT;
ALTER TABLE public.leagues ADD COLUMN IF NOT EXISTS is_pending_selection BOOLEAN NOT NULL DEFAULT false;

-- ============================================================
-- 1. generate_premium_club_name(p_theme, p_slot) - 3 curated (not random)
--    elevated-quality club names per theme, fictional/inspired only.
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_premium_club_name(p_theme TEXT, p_slot INT)
RETURNS TEXT AS $$
DECLARE
  names TEXT[];
BEGIN
  CASE p_theme
    WHEN 'england' THEN
      names := ARRAY['Manchester Northern Elite', 'London Capital United', 'Liverpool Mersey Athletic'];
    WHEN 'spain' THEN
      names := ARRAY['Madrid Deportivo Elite', 'Barcelona Litoral United', 'Vizcaya Norte Athletic'];
    WHEN 'germany' THEN
      names := ARRAY['Munich Bavaria Elite', 'Berlin Capital United', 'Dortmund Ruhr Athletic'];
    WHEN 'italy' THEN
      names := ARRAY['Milano Lombardia Elite', 'Torino Piemonte United', 'Roma Capitale Athletic'];
    ELSE -- 'turkey' and any unrecognized theme
      names := ARRAY['Istanbul Sahil Elite', 'Ankara Baskent United', 'Izmir Korfez Athletic'];
  END CASE;

  RETURN names[GREATEST(1, LEAST(3, p_slot))];
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 2. preview_league_theme(p_theme) - creates an unowned 18-club league
--    (3 premium + 15 free) and returns the full roster for the UI to show
--    before the user commits to a club. No user_id is assigned to any
--    club here, including the caller's - selection happens in step 2.
-- ============================================================
CREATE OR REPLACE FUNCTION public.preview_league_theme(p_theme TEXT DEFAULT 'turkey')
 RETURNS TABLE (
   club_id UUID,
   club_name TEXT,
   quality INT,
   is_premium_locked BOOLEAN,
   premium_unlock_cost INT
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  new_league_id UUID;
  league_counter INT;
  invite_code TEXT;
  i INT;
  new_club_id UUID;
  club_quality INT;
  club_budget BIGINT;
  league_display_name TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot preview a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;
  IF p_theme NOT IN ('turkey', 'england', 'spain', 'germany', 'italy') THEN
    RAISE EXCEPTION 'Geçersiz lig teması';
  END IF;

  invite_code := public.generate_invitation_code();
  SELECT count(*) INTO league_counter FROM public.leagues WHERE theme = p_theme;

  league_display_name := CASE p_theme
    WHEN 'england' THEN 'İngiltere Ligi'
    WHEN 'spain' THEN 'İspanya Ligi'
    WHEN 'germany' THEN 'Almanya Ligi'
    WHEN 'italy' THEN 'İtalya Ligi'
    ELSE 'Türkiye Ligi'
  END;

  INSERT INTO public.leagues (name, tier, is_active, season_generated, invitation_code, theme, is_pending_selection)
  VALUES (league_display_name || ' ' || (league_counter + 1), 1, true, false, invite_code, p_theme, true)
  RETURNING id INTO new_league_id;

  -- 3 curated premium clubs, clearly stronger than the free pool (85-95
  -- vs. the free pool's 30-74 max).
  FOR i IN 1..3 LOOP
    club_quality := 85 + floor(random() * 11)::int;
    club_budget := public.budget_for_quality(club_quality);

    INSERT INTO public.clubs (name, league_id, budget, is_premium_locked, premium_unlock_cost)
    VALUES (public.generate_premium_club_name(p_theme, i), new_league_id, club_budget, true, 100)
    RETURNING id INTO new_club_id;

    PERFORM public.generate_squad_for_club(new_club_id, club_quality, p_theme);

    club_id := new_club_id;
    club_name := public.generate_premium_club_name(p_theme, i);
    quality := club_quality;
    is_premium_locked := true;
    premium_unlock_cost := 100;
    RETURN NEXT;
  END LOOP;

  -- 15 free clubs, same random-quality pool the game has always used.
  FOR i IN 1..15 LOOP
    club_quality := 30 + floor(random() * 45)::int;
    club_budget := public.budget_for_quality(club_quality);

    INSERT INTO public.clubs (name, league_id, budget, is_premium_locked, premium_unlock_cost)
    VALUES (public.generate_bot_club_name(p_theme), new_league_id, club_budget, false, NULL)
    RETURNING id, name INTO new_club_id, club_name;

    PERFORM public.generate_squad_for_club(new_club_id, club_quality, p_theme);

    club_id := new_club_id;
    quality := club_quality;
    is_premium_locked := false;
    premium_unlock_cost := NULL;
    RETURN NEXT;
  END LOOP;
END;
$function$;

-- ============================================================
-- 3. select_club_for_league(p_club_id) - claims a club from a preview.
--    Premium clubs cost diamonds; free clubs are assigned directly.
--    Fixtures/transfer-market seeding only happen here, once someone
--    actually commits to the league.
-- ============================================================
CREATE OR REPLACE FUNCTION public.select_club_for_league(p_club_id UUID)
 RETURNS clubs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  target_league_id UUID;
  target_is_premium BOOLEAN;
  target_cost INT;
  current_diamonds BIGINT;
  updated_row public.clubs;
  bot_club_id UUID;
  listing_rec RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot select a club';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;

  SELECT league_id, is_premium_locked, premium_unlock_cost
  INTO target_league_id, target_is_premium, target_cost
  FROM public.clubs
  WHERE id = p_club_id AND user_id IS NULL
  FOR UPDATE;

  IF target_league_id IS NULL THEN
    RAISE EXCEPTION 'Bu kulüp artık uygun değil.';
  END IF;

  IF target_is_premium THEN
    SELECT diamonds INTO current_diamonds FROM public.profiles WHERE id = auth.uid() FOR UPDATE;
    IF current_diamonds IS NULL OR current_diamonds < target_cost THEN
      RAISE EXCEPTION 'Yetersiz elmas bakiyesi';
    END IF;
    UPDATE public.profiles SET diamonds = diamonds - target_cost WHERE id = auth.uid();
  END IF;

  UPDATE public.clubs SET user_id = auth.uid() WHERE id = p_club_id
  RETURNING * INTO updated_row;

  UPDATE public.leagues SET is_pending_selection = false WHERE id = target_league_id;

  -- Seed transfer listings for every bot club in the league now that the
  -- league has a real owner (deferred from preview_league_theme).
  FOR bot_club_id IN SELECT id FROM public.clubs WHERE league_id = target_league_id AND id <> p_club_id LOOP
    FOR listing_rec IN
      SELECT p.id AS player_id,
        GREATEST(1, ROUND(((p.current_ability * 15000 + p.potential_ability * 5000 + p.age * 100)::numeric / 40) * (0.8 + random() * 0.5))) AS price
      FROM public.players p
      WHERE p.club_id = bot_club_id
      ORDER BY random()
      LIMIT (1 + floor(random() * 2)::int)
    LOOP
      INSERT INTO public.transfer_market (player_id, asking_price)
      VALUES (listing_rec.player_id, listing_rec.price)
      ON CONFLICT (player_id) DO NOTHING;
    END LOOP;
  END LOOP;

  PERFORM public.generate_season_fixtures_for_league(target_league_id);

  RETURN updated_row;
END;
$function$;
