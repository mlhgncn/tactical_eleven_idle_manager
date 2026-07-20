-- preview_league_theme always minted a brand new league (+ 18 fresh bot
-- clubs) on every call, even when an existing same-theme league was still
-- sitting in its pre-kickoff window with open bot clubs. Two users picking
-- the same theme within that window ended up in two separate, mostly-empty
-- leagues instead of filling one together. Now: look for the oldest
-- same-theme league whose season hasn't kicked off yet (no match has been
-- played and the first fixture is still in the future, or fixtures haven't
-- even been generated yet) that still has unclaimed bot clubs, and hand
-- back ITS club list (with is_taken populated, same shape as
-- preview_league_by_code) instead of creating a new league. Falls back to
-- the old create-new-league behavior when no such league exists.
CREATE OR REPLACE FUNCTION public.preview_league_theme(p_theme TEXT DEFAULT 'turkey')
RETURNS TABLE(club_id UUID, club_name TEXT, quality INT, is_taken BOOLEAN, is_premium_locked BOOLEAN, premium_unlock_cost INT) AS $$
DECLARE
  new_league_id UUID;
  reuse_league_id UUID;
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
  IF public._user_club_count(auth.uid()) >= 4 THEN
    RAISE EXCEPTION 'En fazla 4 farklı ligde kulübünüz olabilir.';
  END IF;
  IF p_theme NOT IN ('turkey', 'england', 'spain', 'germany', 'italy') THEN
    RAISE EXCEPTION 'Geçersiz lig teması';
  END IF;

  -- A league is still "joinable" if none of its matches have kicked off
  -- yet and it still has bot clubs nobody owns. Excludes leagues the
  -- caller already has a club in (they'd hit the "already have a club in
  -- this league" check in select_club_for_league anyway).
  SELECT l.id INTO reuse_league_id
  FROM public.leagues l
  WHERE l.theme = p_theme
    AND EXISTS (SELECT 1 FROM public.clubs c WHERE c.league_id = l.id AND c.user_id IS NULL)
    AND NOT EXISTS (SELECT 1 FROM public.clubs c WHERE c.league_id = l.id AND c.user_id = auth.uid())
    AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.league_id = l.id AND m.is_played = true)
    AND (
      NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.league_id = l.id)
      OR (SELECT min(m.match_date) FROM public.matches m WHERE m.league_id = l.id) > now()
    )
  ORDER BY l.created_at ASC
  LIMIT 1;

  IF reuse_league_id IS NOT NULL THEN
    RETURN QUERY
    SELECT
      c.id,
      c.name,
      COALESCE((SELECT ROUND(AVG(p.current_ability))::int FROM public.players p WHERE p.club_id = c.id), 0),
      (c.user_id IS NOT NULL),
      c.is_premium_locked,
      c.premium_unlock_cost
    FROM public.clubs c
    WHERE c.league_id = reuse_league_id
    ORDER BY c.is_premium_locked DESC, c.name;
    RETURN;
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
    is_taken := false;
    is_premium_locked := true;
    premium_unlock_cost := 100;
    RETURN NEXT;
  END LOOP;

  FOR i IN 1..15 LOOP
    club_quality := 30 + floor(random() * 45)::int;
    club_budget := public.budget_for_quality(club_quality);

    INSERT INTO public.clubs (name, league_id, budget, is_premium_locked, premium_unlock_cost)
    VALUES (public.generate_bot_club_name(p_theme), new_league_id, club_budget, false, NULL)
    RETURNING id, name INTO new_club_id, club_name;

    PERFORM public.generate_squad_for_club(new_club_id, club_quality, p_theme);

    club_id := new_club_id;
    quality := club_quality;
    is_taken := false;
    is_premium_locked := false;
    premium_unlock_cost := NULL;
    RETURN NEXT;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.preview_league_theme(TEXT) TO authenticated;
