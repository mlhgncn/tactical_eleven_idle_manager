-- First wave of the "bug fix + game integrity" batch:
-- 1. Max 24 players per club roster (transfer accept + free agent sign are
--    blocked past the cap; diamond pack opening is intentionally exempt -
--    that's the paid "bypass the roster limit" perk).
-- 2. Inactive-user auto-accept: a club whose owner hasn't been active in 5+
--    days has any incoming transfer offer auto-accepted instead of sitting
--    forever waiting for a response that will never come.
-- 3. Lineup-neglect free agency: a club that goes 10 played matches in a
--    row without ever saving a starting XI has its whole squad released to
--    free agency (club_id set to NULL) - the "abandoned club" case.

-- ============================================================
-- 1. Max 24 players per club
-- ============================================================

CREATE OR REPLACE FUNCTION public._check_roster_limit(p_club_id UUID)
RETURNS void AS $$
BEGIN
  IF (SELECT count(*) FROM public.players WHERE club_id = p_club_id) >= 24 THEN
    RAISE EXCEPTION 'Kadro dolu (maksimum 24 oyuncu). Transfer yapmadan önce kadrodan oyuncu çıkarmalısınız.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public._resolve_transfer_offer(p_offer_id UUID, p_accept BOOLEAN)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
  buyer_user_id UUID;
BEGIN
  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT user_id INTO buyer_user_id FROM public.clubs WHERE id = offer_row.from_club_id;

  IF p_accept THEN
    IF (SELECT count(*) FROM public.players WHERE club_id = offer_row.from_club_id) >= 24 THEN
      -- Buyer's roster is full - refund and reject instead of letting the
      -- squad silently grow past the cap.
      UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
      UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;
      IF buyer_user_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (buyer_user_id, 'Teklif Reddedildi', 'Kadronuz dolu (maksimum 24 oyuncu) olduğu için transfer gerçekleşmedi, teklif iade edildi.', false, now());
      END IF;
      RETURN;
    END IF;

    UPDATE public.clubs
    SET budget = budget - offer_row.offer_amount,
        blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount)
    WHERE id = offer_row.from_club_id;

    UPDATE public.clubs SET budget = budget + offer_row.offer_amount WHERE id = offer_row.to_club_id;

    UPDATE public.players SET club_id = offer_row.from_club_id WHERE id = offer_row.player_id;

    INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
    VALUES
      (offer_row.to_club_id, 'transfer_revenue', offer_row.offer_amount, format('Transfer geliri: %s GP', offer_row.offer_amount), 'transfer_offer'),
      (offer_row.from_club_id, 'transfer_cost', -offer_row.offer_amount, format('Transfer satın alım maliyeti: -%s GP', offer_row.offer_amount), 'transfer_offer');

    INSERT INTO public.transfer_history(player_id, seller_club_id, buyer_club_id, price)
    VALUES (offer_row.player_id, offer_row.to_club_id, offer_row.from_club_id, offer_row.offer_amount);

    UPDATE public.transfer_offers SET status = 'accepted', responded_at = now() WHERE id = p_offer_id;

    UPDATE public.clubs c
    SET blocked_budget = GREATEST(0, c.blocked_budget - o.offer_amount)
    FROM public.transfer_offers o
    WHERE o.id <> p_offer_id AND o.player_id = offer_row.player_id AND o.status = 'pending' AND c.id = o.from_club_id;

    UPDATE public.transfer_offers
    SET status = 'rejected', responded_at = now()
    WHERE player_id = offer_row.player_id AND id <> p_offer_id AND status = 'pending';

    DELETE FROM public.transfer_market WHERE player_id = offer_row.player_id;

    IF buyer_user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
      VALUES (buyer_user_id, 'Teklif Kabul Edildi', 'Transfer teklifin kabul edildi, oyuncu artık kadronda!', false, now());
    END IF;
  ELSE
    UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
    UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;

    IF buyer_user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
      VALUES (buyer_user_id, 'Teklif Reddedildi', 'Transfer teklifin reddedildi.', false, now());
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.sign_free_agent(p_player_id UUID)
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

  SELECT * INTO buyer_club FROM public.clubs WHERE user_id = auth.uid();
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

-- ============================================================
-- 2. Inactive-user auto-accept on incoming transfer offers
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_inactive_club_offers()
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
BEGIN
  FOR offer_row IN
    SELECT o.* FROM public.transfer_offers o
    JOIN public.clubs c ON c.id = o.to_club_id
    WHERE o.status = 'pending'
      AND c.user_id IS NOT NULL
      AND c.last_activity_at IS NOT NULL
      AND c.last_activity_at < now() - interval '5 days'
  LOOP
    PERFORM public._resolve_transfer_offer(offer_row.id, true);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 3. Lineup-neglect free agency: 10 played matches in a row without ever
-- saving a starting XI releases the whole squad.
-- ============================================================

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS matches_without_lineup INT NOT NULL DEFAULT 0;

-- Called once per finished match for each side (from the match-resolving
-- edge function, same place fitness/morale postmatch updates already
-- happen) - increments the neglect counter unless the club has a valid
-- saved lineup, and releases the squad to free agency once it hits 10.
CREATE OR REPLACE FUNCTION public.track_lineup_neglect(p_club_id UUID, p_had_valid_lineup BOOLEAN)
RETURNS void AS $$
DECLARE
  new_count INT;
BEGIN
  IF p_had_valid_lineup THEN
    UPDATE public.clubs SET matches_without_lineup = 0 WHERE id = p_club_id;
    RETURN;
  END IF;

  UPDATE public.clubs SET matches_without_lineup = matches_without_lineup + 1
  WHERE id = p_club_id
  RETURNING matches_without_lineup INTO new_count;

  IF new_count >= 10 THEN
    UPDATE public.players SET club_id = NULL WHERE club_id = p_club_id;
    UPDATE public.clubs SET matches_without_lineup = 0 WHERE id = p_club_id;

    INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
    SELECT user_id, 'Kadro Dağıtıldı', 'Üst üste 10 maç boyunca kadro düzenlemediğiniz için tüm oyuncularınız serbest kaldı.', false, now()
    FROM public.clubs WHERE id = p_club_id AND user_id IS NOT NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.track_lineup_neglect(UUID, BOOLEAN) TO service_role;

-- ============================================================
-- Schedule the new inactive-offer sweep. 05:00 Istanbul is clear of the
-- existing 03:00-04:00 batch of daily jobs (daily-player-tick,
-- weekly-injury-recovery, advance-completed-seasons, process-stale-
-- transfer-offers all sit in that earlier window).
-- ============================================================

SELECT cron.unschedule('process-inactive-club-offers') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'process-inactive-club-offers'
);

SELECT cron.schedule(
  'process-inactive-club-offers',
  '0 2 * * *', -- 05:00 Istanbul (UTC+3)
  $$SELECT public.process_inactive_club_offers();$$
);
