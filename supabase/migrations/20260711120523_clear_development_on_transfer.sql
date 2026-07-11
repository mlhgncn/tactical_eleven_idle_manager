-- Oyuncu transfer edildiğinde/serbest oyuncu olarak imzalandığında devam
-- eden gelişimi (development_completes_at) hiç temizlenmiyordu - gelişim
-- yeni kulübe "taşınıyor" ve o mevki grubu, kulüp sahibi hiç başlatmamış
-- olmasına rağmen yeni kulüpte kilitli kalabiliyordu. Transfer/imzalama
-- anında sıfırlıyoruz.
CREATE OR REPLACE FUNCTION public.sign_free_agent(p_player_id uuid)
 RETURNS clubs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;
  IF player_row.club_id IS NOT NULL THEN
    RAISE EXCEPTION 'Player is not a free agent';
  END IF;

  cost := ROUND(((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40) * 0.4);

  IF buyer_club.budget < cost THEN
    RAISE EXCEPTION 'Insufficient budget to sign this player';
  END IF;

  UPDATE public.clubs SET budget = budget - cost WHERE id = buyer_club.id RETURNING * INTO updated_row;
  UPDATE public.players
  SET club_id = buyer_club.id, development_completes_at = NULL, development_ad_uses = 0
  WHERE id = p_player_id;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (buyer_club.id, 'transfer_cost', -cost, format('Serbest oyuncu transferi: -%s GP', cost), 'sign_free_agent');

  INSERT INTO public.transfer_history(player_id, seller_club_id, buyer_club_id, price)
  VALUES (p_player_id, NULL, buyer_club.id, cost);

  RETURN updated_row;
END;
$function$;

CREATE OR REPLACE FUNCTION public._resolve_transfer_offer(p_offer_id uuid, p_accept boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    UPDATE public.clubs
    SET budget = budget - offer_row.offer_amount,
        blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount)
    WHERE id = offer_row.from_club_id;

    UPDATE public.clubs SET budget = budget + offer_row.offer_amount WHERE id = offer_row.to_club_id;

    UPDATE public.players
    SET club_id = offer_row.from_club_id, development_completes_at = NULL, development_ad_uses = 0
    WHERE id = offer_row.player_id;

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
$function$;

-- CREATE OR REPLACE aynı OID'yi koruduğu için REVOKE zaten kalıcı olmalı,
-- ama garanti olsun diye tekrar uyguluyoruz (idempotent, zararsız).
REVOKE EXECUTE ON FUNCTION public._resolve_transfer_offer(uuid, boolean) FROM PUBLIC, authenticated, anon;
