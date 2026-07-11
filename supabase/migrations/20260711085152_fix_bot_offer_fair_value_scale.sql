-- make_transfer_offer's bot-club auto-accept heuristic
-- (fair_value = current_ability*15000 + potential_ability*5000 + age*100,
-- accept if offer >= 85% of that) was never rescaled when the whole
-- economy (budgets, market values, sign_free_agent) was divided by 40 -
-- see 20260710145357_rebalance_club_economy_lower_budgets.sql. Bots were
-- comparing real, rescaled offers against a fair_value ~40x too high, so
-- they rejected almost every offer regardless of how reasonable it was.
CREATE OR REPLACE FUNCTION public.make_transfer_offer(p_player_id UUID, p_offer_amount BIGINT)
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

  SELECT * INTO buyer_club FROM public.clubs WHERE user_id = auth.uid();
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

  -- Bot club: respond immediately using a simple fair-value heuristic
  -- instead of leaving a human waiting forever. Same /40-rescaled
  -- market-value formula as lib/models/player_fm.dart's marketValue and
  -- sign_free_agent's cost.
  fair_value := ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT;
  PERFORM public._resolve_transfer_offer(new_offer.id, p_offer_amount >= (fair_value * 0.85)::BIGINT);

  SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
