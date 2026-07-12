-- Multi-league support: a user can now own up to 4 clubs at once, one per
-- league (never two clubs in the same league). This migration is written
-- to be fully backward compatible with every existing single-club user:
-- every RPC that used to silently resolve "the caller's club" via
-- `WHERE user_id = auth.uid() LIMIT 1` now takes an OPTIONAL p_club_id -
-- when omitted (NULL), it falls back to that same single-club lookup, so
-- nothing breaks for a user who (still) owns exactly one club. Flutter
-- passes the explicit club_id once the club-switcher UI lands; until then
-- behavior is identical to today.

-- ============================================================
-- 1. Replace the single-club unique index with a per-league one: a user
-- can own at most one club PER LEAGUE, but now multiple clubs across
-- different leagues.
-- ============================================================

DROP INDEX IF EXISTS public.clubs_user_id_unique_partial;

CREATE UNIQUE INDEX IF NOT EXISTS clubs_user_id_league_id_unique_partial
ON public.clubs (user_id, league_id)
WHERE user_id IS NOT NULL;

-- ============================================================
-- 2. Shared helper: how many clubs does this user currently own, and do
-- they already own one in this specific league.
-- ============================================================

CREATE OR REPLACE FUNCTION public._user_club_count(p_user_id UUID)
RETURNS INT AS $$
  SELECT count(*)::int FROM public.clubs WHERE user_id = p_user_id;
$$ LANGUAGE sql STABLE SET search_path = public;

-- ============================================================
-- 3. preview_league_theme / select_club_for_league: "already have a club"
-- becomes "already have a club in some league" only blocking at 4 total,
-- plus a NEW check for "already have a club in THIS league" (only
-- relevant for select_club_for_league, since preview doesn't assign yet).
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
  IF public._user_club_count(auth.uid()) >= 4 THEN
    RAISE EXCEPTION 'En fazla 4 farklı ligde kulübünüz olabilir.';
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
  IF public._user_club_count(auth.uid()) >= 4 THEN
    RAISE EXCEPTION 'En fazla 4 farklı ligde kulübünüz olabilir.';
  END IF;

  SELECT league_id, is_premium_locked, premium_unlock_cost
  INTO target_league_id, target_is_premium, target_cost
  FROM public.clubs
  WHERE id = p_club_id AND user_id IS NULL
  FOR UPDATE;

  IF target_league_id IS NULL THEN
    RAISE EXCEPTION 'Bu kulüp artık uygun değil.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid() AND league_id = target_league_id) THEN
    RAISE EXCEPTION 'Bu ligde zaten bir kulübünüz var.';
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

-- ============================================================
-- 4. join_league_with_code becomes preview-then-pick, matching the
-- "kullanıcı takım seçebilmeli" requirement instead of a random slot.
-- preview_league_by_code(p_invitation_code) lists every unowned club in
-- that league (name + quality); the user then calls select_club_for_league
-- with the chosen club_id (same function used for freshly-created
-- leagues). join_league_with_code is kept as-is (not dropped) for anyone/
-- anything still calling it directly - it still works, just skips the
-- picker.
-- ============================================================

CREATE OR REPLACE FUNCTION public.preview_league_by_code(p_invitation_code TEXT)
 RETURNS TABLE (
   club_id UUID,
   club_name TEXT,
   quality INT,
   is_taken BOOLEAN,
   is_premium_locked BOOLEAN,
   premium_unlock_cost INT
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  target_league_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot preview a league';
  END IF;
  IF p_invitation_code IS NULL OR length(trim(p_invitation_code)) = 0 THEN
    RAISE EXCEPTION 'Davet kodu boş olamaz.';
  END IF;

  SELECT id INTO target_league_id
  FROM public.leagues
  WHERE invitation_code = upper(trim(p_invitation_code));

  IF target_league_id IS NULL THEN
    RAISE EXCEPTION 'Geçersiz davet kodu.';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    -- Quality isn't stored directly on clubs; approximate it from squad
    -- average current_ability, same signal preview_league_theme reports
    -- at creation time.
    COALESCE((SELECT ROUND(AVG(p.current_ability))::int FROM public.players p WHERE p.club_id = c.id), 0),
    (c.user_id IS NOT NULL),
    c.is_premium_locked,
    c.premium_unlock_cost
  FROM public.clubs c
  WHERE c.league_id = target_league_id
  ORDER BY c.is_premium_locked DESC, c.name;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.preview_league_by_code(TEXT) TO authenticated;

-- ============================================================
-- 5. leave_current_club(p_club_id) - takes an explicit club id now instead
-- of guessing via LIMIT 1. p_club_id defaults to NULL for backward
-- compatibility (falls back to the old single-club lookup).
-- ============================================================

DROP FUNCTION IF EXISTS public.leave_current_club();

CREATE OR REPLACE FUNCTION public.leave_current_club(p_club_id UUID DEFAULT NULL)
RETURNS void AS $$
DECLARE
  owned_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot leave a club';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO owned_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO owned_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;

  IF owned_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  UPDATE public.clubs SET user_id = NULL WHERE id = owned_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 6. Player-market RPCs that used to resolve "the caller's club" via a
-- bare (unordered, no LIMIT) `WHERE user_id = auth.uid()` lookup - which
-- would now raise "query returned more than one row" for any multi-club
-- user. All gain an optional p_club_id (NULL = old single-club behavior).
-- ============================================================

DROP FUNCTION IF EXISTS public.sign_free_agent(UUID);

CREATE OR REPLACE FUNCTION public.sign_free_agent(p_player_id UUID, p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  buyer_club public.clubs%ROWTYPE;
  player_row public.players%ROWTYPE;
  cost BIGINT;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot sign a player';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO buyer_club FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO buyer_club FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  PERFORM public._check_roster_limit(buyer_club.id);

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;
  IF player_row.club_id IS NOT NULL THEN
    RAISE EXCEPTION 'Player is not a free agent';
  END IF;

  cost := ROUND((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100) * 0.4);

  IF buyer_club.budget < cost THEN
    RAISE EXCEPTION 'Insufficient budget to sign this player';
  END IF;

  UPDATE public.clubs SET budget = budget - cost WHERE id = buyer_club.id RETURNING * INTO updated_row;
  UPDATE public.players SET club_id = buyer_club.id WHERE id = p_player_id;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (buyer_club.id, 'transfer_cost', -cost, format('Serbest oyuncu transferi: -%s GP', cost), 'sign_free_agent');

  INSERT INTO public.transfer_history(player_id, seller_club_id, buyer_club_id, price)
  VALUES (p_player_id, NULL, buyer_club.id, cost);

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS public.make_transfer_offer(UUID, BIGINT);

CREATE OR REPLACE FUNCTION public.make_transfer_offer(p_player_id UUID, p_offer_amount BIGINT, p_club_id UUID DEFAULT NULL)
RETURNS public.transfer_offers AS $$
DECLARE
  buyer_club public.clubs%ROWTYPE;
  player_row public.players%ROWTYPE;
  seller_user_id UUID;
  available_budget BIGINT;
  new_offer public.transfer_offers;
  fair_value BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot make an offer';
  END IF;
  IF p_offer_amount <= 0 THEN
    RAISE EXCEPTION 'Offer must be positive';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO buyer_club FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO buyer_club FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;
  IF player_row.club_id IS NULL THEN
    RAISE EXCEPTION 'Player is a free agent, use sign_free_agent instead';
  END IF;
  IF player_row.club_id = buyer_club.id THEN
    RAISE EXCEPTION 'Cannot make an offer for your own player';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transfer_offers
    WHERE player_id = p_player_id AND from_club_id = buyer_club.id AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'You already have a pending offer for this player';
  END IF;

  available_budget := buyer_club.budget - buyer_club.blocked_budget;
  IF available_budget < p_offer_amount THEN
    RAISE EXCEPTION 'Insufficient available budget to make this offer';
  END IF;

  UPDATE public.clubs SET blocked_budget = blocked_budget + p_offer_amount WHERE id = buyer_club.id;

  INSERT INTO public.transfer_offers(player_id, from_club_id, to_club_id, offer_amount, status)
  VALUES (p_player_id, buyer_club.id, player_row.club_id, p_offer_amount, 'pending')
  RETURNING * INTO new_offer;

  SELECT user_id INTO seller_user_id FROM public.clubs WHERE id = player_row.club_id;

  IF seller_user_id IS NOT NULL THEN
    INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
    VALUES (
      seller_user_id,
      'Transfer Teklifi',
      format('%s için %s GP teklif aldın.', player_row.name, p_offer_amount),
      false,
      now()
    );
    RETURN new_offer;
  END IF;

  fair_value := ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT;
  PERFORM public._resolve_transfer_offer(new_offer.id, p_offer_amount >= (fair_value * 0.85)::BIGINT);

  SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 7. players_select_policy: a user can see players from ANY of their
-- clubs now, not just a single LIMIT-1 one.
-- ============================================================

DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players
FOR SELECT
USING (
  club_id IS NULL
  OR club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
);
