-- A club a user claims via select_club_for_league/join_league_with_code
-- isn't always freshly generated - if the league it belongs to was reused
-- (see 20260722000000_reuse_pending_league_on_theme_preview.sql) rather
-- than newly minted, the club can be days/weeks old and have grown well
-- past its original 24-player squad via the 15-minute academy-production
-- cron (which runs for bot clubs too, not just user-owned ones). That gave
-- users an inconsistent, sometimes much larger than intended starting
-- roster purely by luck of which club they picked. Trim back down to a
-- flat 24 on claim - lowest current_ability first, so the club keeps its
-- best players - by releasing the excess to free agency (not deleting
-- them outright; consistent with every other roster-shrinking path in
-- this codebase, e.g. release_player_to_free_agency, roster-limit
-- inactivity release).
CREATE OR REPLACE FUNCTION public._trim_club_squad_to_target(p_club_id UUID, p_target_count INT)
RETURNS void AS $$
BEGIN
  UPDATE public.players
  SET club_id = NULL
  WHERE id IN (
    SELECT id FROM public.players
    WHERE club_id = p_club_id
    ORDER BY current_ability ASC, id ASC
    OFFSET GREATEST(0, p_target_count)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.select_club_for_league(p_club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  target_league_id UUID;
  target_is_premium BOOLEAN;
  target_cost INT;
  current_diamonds BIGINT;
  updated_row public.clubs;
  bot_club_id UUID;
  listing_rec RECORD;
  is_first_club BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot select a club';
  END IF;
  IF public._user_club_count(auth.uid()) >= 4 THEN
    RAISE EXCEPTION 'En fazla 4 farklı ligde kulübünüz olabilir.';
  END IF;

  is_first_club := NOT EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid());

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

  PERFORM public._trim_club_squad_to_target(p_club_id, 24);

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

  IF is_first_club THEN
    PERFORM public._award_referral_bonus_if_applicable(auth.uid());
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.join_league_with_code(p_invitation_code TEXT)
RETURNS public.clubs AS $$
DECLARE
  target_league_id UUID;
  target_club_id UUID;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot join a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
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

  SELECT id INTO target_club_id
  FROM public.clubs
  WHERE league_id = target_league_id AND user_id IS NULL
  ORDER BY random()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF target_club_id IS NULL THEN
    RAISE EXCEPTION 'Bu ligde boş takım kalmadı.';
  END IF;

  UPDATE public.clubs SET user_id = auth.uid() WHERE id = target_club_id
  RETURNING * INTO updated_row;

  PERFORM public._trim_club_squad_to_target(target_club_id, 24);

  PERFORM public._award_referral_bonus_if_applicable(auth.uid());

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public._trim_club_squad_to_target(UUID, INT) FROM PUBLIC, authenticated, anon;
