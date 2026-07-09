-- Three "Lig Oluştur" experience fixes:
--   1. Make league creation a true one-tap action - no club-name prompt.
--      The founder's club, like every bot club, now gets an auto-generated
--      name (renaming can be added as its own feature later).
--   2. Every club's starting budget now scales with a randomly rolled
--      quality tier (shared with generate_squad_for_club, so a club's
--      budget and squad strength move together) instead of a flat
--      10,000,000 for every club regardless of strength - closer to how
--      real clubs vary.
--   3. Seed the transfer market with a listing or two from each bot club
--      so there's something to browse/bid on the moment a league starts,
--      instead of a completely empty market.

CREATE OR REPLACE FUNCTION public.budget_for_quality(p_quality INT)
RETURNS BIGINT AS $$
BEGIN
  RETURN CASE
    WHEN p_quality >= 70 THEN (40000000 + floor(random() * 60000000))::bigint
    WHEN p_quality >= 55 THEN (15000000 + floor(random() * 25000000))::bigint
    WHEN p_quality >= 40 THEN (5000000 + floor(random() * 10000000))::bigint
    ELSE (1000000 + floor(random() * 4000000))::bigint
  END;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS public.create_league_and_join(text);

CREATE OR REPLACE FUNCTION public.create_league_and_join()
RETURNS public.clubs AS $$
DECLARE
  new_league_id UUID;
  new_club_id UUID;
  league_counter INT;
  invite_code TEXT;
  i INT;
  bot_club_id UUID;
  club_quality INT;
  club_budget BIGINT;
  updated_row public.clubs;
  listing_rec RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot create a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;

  invite_code := public.generate_invitation_code();
  SELECT count(*) INTO league_counter FROM public.leagues;

  INSERT INTO public.leagues (name, tier, is_active, season_generated, invitation_code)
  VALUES ('Lig ' || (league_counter + 1), 1, true, false, invite_code)
  RETURNING id INTO new_league_id;

  club_quality := 30 + floor(random() * 45)::int;
  club_budget := public.budget_for_quality(club_quality);

  INSERT INTO public.clubs (name, user_id, league_id, budget)
  VALUES (public.generate_bot_club_name(), auth.uid(), new_league_id, club_budget)
  RETURNING id INTO new_club_id;

  PERFORM public.generate_squad_for_club(new_club_id, club_quality);

  -- Fill the rest of the league with bot clubs so it can start playing
  -- immediately, and seed a transfer listing or two from each one.
  FOR i IN 1..17 LOOP
    club_quality := 30 + floor(random() * 45)::int;
    club_budget := public.budget_for_quality(club_quality);

    INSERT INTO public.clubs (name, league_id, budget)
    VALUES (public.generate_bot_club_name(), new_league_id, club_budget)
    RETURNING id INTO bot_club_id;
    PERFORM public.generate_squad_for_club(bot_club_id, club_quality);

    FOR listing_rec IN
      SELECT p.id AS player_id, (p.current_ability * p.current_ability * 800)::bigint AS price
      FROM public.players p
      WHERE p.club_id = bot_club_id
      ORDER BY random()
      LIMIT (1 + floor(random() * 2)::int)
    LOOP
      INSERT INTO public.transfer_market (player_id, current_highest_bid, end_time)
      VALUES (listing_rec.player_id, listing_rec.price, now() + interval '3 days')
      ON CONFLICT (player_id) DO NOTHING;
    END LOOP;
  END LOOP;

  PERFORM public.generate_season_fixtures_for_league(new_league_id);

  SELECT * INTO updated_row FROM public.clubs WHERE id = new_club_id;
  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
