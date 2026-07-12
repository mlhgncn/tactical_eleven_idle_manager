-- Module 3 (Transfer Market) improvements:
-- 1. inbox_messages gains related_player_id, so a message about a player
--    can deep-link to that player's card in the UI.
-- 2. Rejected-offer messages now include the player's market value (same
--    /40-rescaled formula as PlayerFM.marketValue) instead of a bare
--    "your offer was rejected" - gives the buyer a number to work from
--    when they reoffer.
-- 3. Accepted-offer messages now name the player instead of a generic
--    "a player joined your squad".

ALTER TABLE public.inbox_messages ADD COLUMN IF NOT EXISTS related_player_id UUID REFERENCES public.players(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public._resolve_transfer_offer(p_offer_id UUID, p_accept BOOLEAN)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
  buyer_user_id UUID;
  player_row public.players%ROWTYPE;
  fair_value BIGINT;
BEGIN
  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT user_id INTO buyer_user_id FROM public.clubs WHERE id = offer_row.from_club_id;
  SELECT * INTO player_row FROM public.players WHERE id = offer_row.player_id;

  IF p_accept THEN
    IF (SELECT count(*) FROM public.players WHERE club_id = offer_row.from_club_id) >= 24 THEN
      UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
      UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;
      IF buyer_user_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at, related_player_id)
        VALUES (buyer_user_id, 'Teklif Reddedildi', 'Kadronuz dolu (maksimum 24 oyuncu) olduğu için transfer gerçekleşmedi, teklif iade edildi.', false, now(), offer_row.player_id);
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
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at, related_player_id)
      VALUES (
        buyer_user_id,
        'Teklif Kabul Edildi',
        format('%s için verdiğin transfer teklifi kabul edildi, oyuncu artık kadronda!', COALESCE(player_row.name, 'Oyuncu')),
        false,
        now(),
        offer_row.player_id
      );
    END IF;
  ELSE
    UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
    UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;

    IF buyer_user_id IS NOT NULL THEN
      fair_value := CASE WHEN player_row.id IS NOT NULL THEN
        ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT
      ELSE NULL END;

      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at, related_player_id)
      VALUES (
        buyer_user_id,
        'Teklif Reddedildi',
        CASE WHEN fair_value IS NOT NULL THEN
          format('%s için verdiğin %s GP teklif reddedildi. Oyuncunun piyasaya göre tahmini değeri: %s GP.', player_row.name, offer_row.offer_amount, fair_value)
        ELSE
          'Transfer teklifin reddedildi.'
        END,
        false,
        now(),
        offer_row.player_id
      );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
