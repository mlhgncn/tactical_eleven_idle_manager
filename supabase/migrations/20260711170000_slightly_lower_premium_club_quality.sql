-- Slightly reduce the premium club quality range (85-95 -> 80-90). Still
-- clearly stronger than the free pool (30-74 max), just a touch less
-- dominant. Only the quality roll in preview_league_theme changes; nothing
-- else about the function (naming, cost, free-club generation) is touched.
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

  -- 3 curated premium clubs, still clearly stronger than the free pool
  -- (80-90 vs. the free pool's 30-74 max), slightly toned down from the
  -- original 85-95.
  FOR i IN 1..3 LOOP
    club_quality := 80 + floor(random() * 11)::int;
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
