-- Transfer counter-offer chain. transfer_offers previously only supported
-- a single round (offer -> accept/reject/withdraw). Adds the ability for
-- either side to counter a pending offer with a different amount,
-- chaining rounds via parent_offer_id up to a hard cap (5) so negotiation
-- can't loop forever. round_number/initiated_by track which side made
-- the LATEST move, so the UI/RPCs know whose turn it is to respond.
--
-- from_club_id/to_club_id stay fixed to buyer/seller across the whole
-- chain (only who made the most recent offer changes, tracked via
-- initiated_by) - this keeps _resolve_transfer_offer's budget/ownership
-- transfer logic unchanged, since it only ever runs on the chain's final
-- accepted round and always moves the player from_club_id -> to_club_id...
-- wait: existing _resolve_transfer_offer moves the player TO from_club_id
-- (the buyer) and pays FROM from_club_id's budget - buyer/seller naming
-- there is buyer=from_club_id, seller=to_club_id. Preserved exactly.

ALTER TABLE public.transfer_offers
  ADD COLUMN IF NOT EXISTS parent_offer_id UUID REFERENCES public.transfer_offers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS round_number INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS initiated_by TEXT NOT NULL DEFAULT 'buyer'; -- 'buyer' | 'seller' - who proposed THIS row's offer_amount

CREATE INDEX IF NOT EXISTS idx_transfer_offers_parent ON public.transfer_offers(parent_offer_id) WHERE parent_offer_id IS NOT NULL;

-- respond_to_transfer_offer: only the side that DIDN'T make the current
-- pending offer may accept/reject it (same "not your own move" rule as
-- countering) - both buyer and seller can now call this (previously only
-- the seller/to_club_id could), since a seller's counter-offer is
-- answered by the buyer.
CREATE OR REPLACE FUNCTION public.respond_to_transfer_offer(p_offer_id UUID, p_accept BOOLEAN, p_club_id UUID DEFAULT NULL)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
  caller_club_id UUID;
  caller_role TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot respond to an offer';
  END IF;

  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer not found';
  END IF;
  IF offer_row.status <> 'pending' THEN
    RAISE EXCEPTION 'Offer already resolved';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO caller_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid()
      AND id IN (offer_row.from_club_id, offer_row.to_club_id) LIMIT 1;
  END IF;

  IF caller_club_id = offer_row.from_club_id THEN
    caller_role := 'buyer';
  ELSIF caller_club_id = offer_row.to_club_id THEN
    caller_role := 'seller';
  ELSE
    RAISE EXCEPTION 'You are not a party to this offer';
  END IF;

  IF caller_role = offer_row.initiated_by THEN
    RAISE EXCEPTION 'Sıra karşı tarafta - kendi teklifinizi kabul/red edemezsiniz.';
  END IF;

  PERFORM public._resolve_transfer_offer(p_offer_id, p_accept);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- withdraw_transfer_offer: withdrawing is still buyer-only (matches the
-- original semantics - "withdraw" means the buyer pulls their money
-- back), but now only valid on a row the buyer themselves most recently
-- proposed (initiated_by='buyer') - if the seller just countered, the
-- buyer's move is to accept/reject/counter, not withdraw a offer that's
-- no longer theirs to retract.
CREATE OR REPLACE FUNCTION public.withdraw_transfer_offer(p_offer_id UUID)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot withdraw an offer';
  END IF;

  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer not found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = offer_row.from_club_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You do not own this offer';
  END IF;
  IF offer_row.status <> 'pending' THEN
    RAISE EXCEPTION 'Offer already resolved';
  END IF;

  UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
  UPDATE public.transfer_offers SET status = 'withdrawn', responded_at = now() WHERE id = p_offer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- make_transfer_offer's bot-seller branch: previously a single-shot
-- accept-if->=85%-of-fair-value-else-reject. Now a three-tier response so
-- the counter-offer feature is actually usable against bots (the vast
-- majority of sellers): >=85% fair value accepts immediately, 60-85%
-- gets a bot counter-offer at ~95% of fair value (giving the human buyer
-- something to accept/counter further, up to the round cap), below 60%
-- is rejected outright as not worth negotiating over.
CREATE OR REPLACE FUNCTION public.make_transfer_offer(p_player_id UUID, p_offer_amount BIGINT, p_club_id UUID DEFAULT NULL)
RETURNS public.transfer_offers AS $$
DECLARE
  buyer_club public.clubs%ROWTYPE;
  player_row public.players%ROWTYPE;
  seller_user_id UUID;
  available_budget BIGINT;
  new_offer public.transfer_offers;
  fair_value BIGINT;
  bot_counter_amount BIGINT;
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

  INSERT INTO public.transfer_offers(player_id, from_club_id, to_club_id, offer_amount, status, initiated_by)
  VALUES (p_player_id, buyer_club.id, player_row.club_id, p_offer_amount, 'pending', 'buyer')
  RETURNING * INTO new_offer;

  SELECT user_id INTO seller_user_id FROM public.clubs WHERE id = player_row.club_id;

  IF seller_user_id IS NOT NULL THEN
    INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
    VALUES (
      seller_user_id,
      player_row.club_id,
      'Transfer Teklifi',
      format('%s için %s GP teklif aldın.', player_row.name, p_offer_amount),
      false,
      now()
    );
    RETURN new_offer;
  END IF;

  fair_value := ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT;

  IF p_offer_amount >= (fair_value * 0.85)::BIGINT THEN
    PERFORM public._resolve_transfer_offer(new_offer.id, true);
  ELSIF p_offer_amount >= (fair_value * 0.60)::BIGINT THEN
    bot_counter_amount := (fair_value * 0.95)::BIGINT;
    UPDATE public.transfer_offers SET status = 'countered', responded_at = now() WHERE id = new_offer.id;
    INSERT INTO public.transfer_offers (player_id, from_club_id, to_club_id, offer_amount, status, parent_offer_id, round_number, initiated_by)
    VALUES (p_player_id, buyer_club.id, player_row.club_id, bot_counter_amount, 'pending', new_offer.id, 2, 'seller')
    RETURNING * INTO new_offer;
  ELSE
    PERFORM public._resolve_transfer_offer(new_offer.id, false);
  END IF;

  SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- When a human buyer counters a bot seller's counter-offer, the bot needs
-- to react automatically too (there's no human on the other side to
-- respond) - same three-tier logic as make_transfer_offer's bot branch,
-- applied inside counter_transfer_offer whenever the resulting new
-- pending row's seller is a bot AND the caller was the buyer.
CREATE OR REPLACE FUNCTION public.counter_transfer_offer(p_offer_id UUID, p_counter_amount BIGINT, p_club_id UUID DEFAULT NULL)
RETURNS public.transfer_offers AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
  caller_club_id UUID;
  caller_role TEXT;
  new_offer public.transfer_offers;
  available_budget BIGINT;
  buyer_club public.clubs%ROWTYPE;
  player_row public.players%ROWTYPE;
  seller_user_id UUID;
  fair_value BIGINT;
  bot_counter_amount BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot counter an offer';
  END IF;
  IF p_counter_amount <= 0 THEN
    RAISE EXCEPTION 'Karşı teklif pozitif olmalı';
  END IF;

  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Teklif bulunamadı ya da artık aktif değil';
  END IF;

  IF offer_row.round_number >= 5 THEN
    RAISE EXCEPTION 'Bu teklif için pazarlık turu sınırına ulaşıldı (5). Teklifi kabul edin, reddedin ya da geri çekin.';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO caller_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF caller_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  IF caller_club_id = offer_row.from_club_id THEN
    caller_role := 'buyer';
  ELSIF caller_club_id = offer_row.to_club_id THEN
    caller_role := 'seller';
  ELSE
    RAISE EXCEPTION 'Bu teklifin tarafı değilsiniz';
  END IF;

  IF caller_role = offer_row.initiated_by THEN
    RAISE EXCEPTION 'Sıra karşı tarafta - kendi teklifinizi karşı teklifle değiştiremezsiniz.';
  END IF;

  IF caller_role = 'buyer' THEN
    SELECT * INTO buyer_club FROM public.clubs WHERE id = offer_row.from_club_id FOR UPDATE;
    available_budget := buyer_club.budget - buyer_club.blocked_budget + offer_row.offer_amount;
    IF available_budget < p_counter_amount THEN
      RAISE EXCEPTION 'Bu karşı teklif için yeterli bakiyeniz yok';
    END IF;
    UPDATE public.clubs
    SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) + p_counter_amount
    WHERE id = offer_row.from_club_id;
  END IF;

  UPDATE public.transfer_offers SET status = 'countered', responded_at = now() WHERE id = p_offer_id;

  INSERT INTO public.transfer_offers (player_id, from_club_id, to_club_id, offer_amount, status, parent_offer_id, round_number, initiated_by)
  VALUES (offer_row.player_id, offer_row.from_club_id, offer_row.to_club_id, p_counter_amount, 'pending', offer_row.id, offer_row.round_number + 1, caller_role)
  RETURNING * INTO new_offer;

  -- If a human buyer just countered a bot seller, the bot must react
  -- immediately - there's no human seller to leave this pending for.
  IF caller_role = 'buyer' THEN
    SELECT user_id INTO seller_user_id FROM public.clubs WHERE id = offer_row.to_club_id;
    IF seller_user_id IS NULL THEN
      SELECT * INTO player_row FROM public.players WHERE id = offer_row.player_id;
      fair_value := ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT;

      IF p_counter_amount >= (fair_value * 0.85)::BIGINT THEN
        PERFORM public._resolve_transfer_offer(new_offer.id, true);
        SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
      ELSIF p_counter_amount >= (fair_value * 0.60)::BIGINT AND new_offer.round_number < 5 THEN
        bot_counter_amount := (fair_value * 0.95)::BIGINT;
        UPDATE public.transfer_offers SET status = 'countered', responded_at = now() WHERE id = new_offer.id;
        INSERT INTO public.transfer_offers (player_id, from_club_id, to_club_id, offer_amount, status, parent_offer_id, round_number, initiated_by)
        VALUES (offer_row.player_id, offer_row.from_club_id, offer_row.to_club_id, bot_counter_amount, 'pending', new_offer.id, new_offer.round_number + 1, 'seller')
        RETURNING * INTO new_offer;
      ELSE
        PERFORM public._resolve_transfer_offer(new_offer.id, false);
        SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
      END IF;
    END IF;
  END IF;

  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- CREATE OR REPLACE with a new trailing parameter adds a new overload
-- rather than replacing the old signature (same overload-accumulation
-- issue seen before with open_player_pack/scout_opponent) - drop the
-- now-superseded two-arg version so there's exactly one
-- respond_to_transfer_offer going forward.
DROP FUNCTION IF EXISTS public.respond_to_transfer_offer(UUID, BOOLEAN);

GRANT EXECUTE ON FUNCTION public.counter_transfer_offer(UUID, BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_transfer_offer(UUID, BOOLEAN, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_transfer_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.make_transfer_offer(UUID, BIGINT, UUID) TO authenticated;
