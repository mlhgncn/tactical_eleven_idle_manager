-- Raises the roster cap from 24 to 30 players - generate_squad_for_club
-- still generates 24 players for a fresh squad (unchanged), this only
-- raises the ceiling for how many players a club can accumulate via
-- transfers/free agents/packs afterward.
CREATE OR REPLACE FUNCTION public._check_roster_limit(p_club_id UUID)
RETURNS void AS $$
BEGIN
  IF (SELECT count(*) FROM public.players WHERE club_id = p_club_id) >= 30 THEN
    RAISE EXCEPTION 'Kadro dolu (maksimum 30 oyuncu). Transfer yapmadan önce kadrodan oyuncu çıkarmalısınız.';
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
    IF (SELECT count(*) FROM public.players WHERE club_id = offer_row.from_club_id) >= 30 THEN
      UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
      UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;
      IF buyer_user_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (buyer_user_id, 'Teklif Reddedildi', 'Kadronuz dolu (maksimum 30 oyuncu) olduğu için transfer gerçekleşmedi, teklif iade edildi.', false, now());
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
