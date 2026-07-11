-- budget_for_quality, ekonomi /40 rescale edilirken (20260710145357)
-- CREATE OR REPLACE ile "dokunulmuş" ama içeriği değişmemiş - hâlâ eski
-- ölçekte (1M-2.5M GP). Yeni kurulan her lig (kurucu + 17 bot kulüp) bu
-- yüzden diğer herkesin (~1.600-60.000 GP) 20-40 katı bütçeyle
-- başlıyordu. Aynı /40 rescale'i burada da uyguluyoruz.
CREATE OR REPLACE FUNCTION public.budget_for_quality(p_quality integer)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE
    WHEN p_quality >= 70 THEN (25000 + floor(random() * 37500))::bigint
    WHEN p_quality >= 55 THEN (9375 + floor(random() * 15625))::bigint
    WHEN p_quality >= 40 THEN (3125 + floor(random() * 6250))::bigint
    ELSE (625 + floor(random() * 2500))::bigint
  END;
END;
$function$;

-- create_league_and_join, yeni ligdeki bot kulüplerin ilk transfer
-- ilanlarını kendi (eski, rescale edilmemiş) formülüyle üretiyordu:
-- current_ability^2 * 800 - bu hem eski ölçekte hem seed_bot_transfer_
-- listings()'teki doğru formülden tamamen farklıydı. Örn. ability 70 bir
-- oyuncu 3.920.000 GP'ye listeleniyordu (kimse alamaz). Aynı doğru
-- formülü (marketValue /40, ±%20-50 rastgele çarpan) burada da kullan.
CREATE OR REPLACE FUNCTION public.create_league_and_join()
 RETURNS clubs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  PERFORM public.generate_season_fixtures_for_league(new_league_id);

  SELECT * INTO updated_row FROM public.clubs WHERE id = new_club_id;
  RETURN updated_row;
END;
$function$;
