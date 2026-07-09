-- Replace the auction-style transfer market (highest bidder wins after a
-- timer) with a real-life-style one: any club can make an offer on any
-- other club's player, the owning club (a real user, or a bot using a
-- simple heuristic) accepts or rejects it, and free agents (no club) can
-- be signed directly with no negotiation needed.
--
-- User-approved destructive migration (2026-07-09): confirmed via
-- AskUserQuestion after the auto-mode classifier flagged the DROP
-- COLUMN/DROP FUNCTION changes below as touching shared production data.
-- The one live active bid (3,075,400 GP blocked) is carried forward into
-- transfer_offers before anything is dropped, so no reserved funds or
-- in-flight transaction are lost.

CREATE TABLE IF NOT EXISTS public.transfer_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  from_club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  to_club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  offer_amount BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS transfer_offers_to_club_idx ON public.transfer_offers(to_club_id, status);
CREATE INDEX IF NOT EXISTS transfer_offers_from_club_idx ON public.transfer_offers(from_club_id, status);
CREATE INDEX IF NOT EXISTS transfer_offers_player_idx ON public.transfer_offers(player_id, status);

ALTER TABLE public.transfer_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS transfer_offers_select_policy ON public.transfer_offers;
CREATE POLICY transfer_offers_select_policy ON public.transfer_offers
FOR SELECT
USING (
  from_club_id = (SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1)
  OR to_club_id = (SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1)
);

DROP POLICY IF EXISTS transfer_offers_insert_policy ON public.transfer_offers;
CREATE POLICY transfer_offers_insert_policy ON public.transfer_offers FOR INSERT WITH CHECK (false);

DROP POLICY IF EXISTS transfer_offers_update_policy ON public.transfer_offers;
CREATE POLICY transfer_offers_update_policy ON public.transfer_offers FOR UPDATE USING (false);

-- Carry forward every live auction bid as an equivalent pending offer
-- BEFORE the old bidding columns are dropped below, so no bidder's
-- already-reserved blocked_budget is silently orphaned or lost - it now
-- represents a transfer_offers row the seller can accept/reject instead.
--
-- Guarded on highest_bidder_id still existing: this whole migration was
-- already applied once directly against production, which renamed/
-- dropped these columns. The CI deploy workflow tracks applied migration
-- filenames in its own separate ledger (_migrations_applied) and doesn't
-- know that happened, so it replays this file - without the guard, the
-- SELECT below would fail with "column does not exist" on that replay.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'transfer_market' AND column_name = 'highest_bidder_id'
  ) THEN
    INSERT INTO public.transfer_offers (player_id, from_club_id, to_club_id, offer_amount, status, created_at)
    SELECT tm.player_id, tm.highest_bidder_id, p.club_id, tm.current_highest_bid, 'pending', now()
    FROM public.transfer_market tm
    JOIN public.players p ON p.id = tm.player_id
    WHERE tm.highest_bidder_id IS NOT NULL AND p.club_id IS NOT NULL;

    -- Any bidder whose auction had already expired (bid never accepted)
    -- gets their reservation released, exactly like
    -- release_expired_transfer_bids used to do.
    UPDATE public.clubs c
    SET blocked_budget = GREATEST(0, c.blocked_budget - tm.current_highest_bid)
    FROM public.transfer_market tm
    WHERE tm.highest_bidder_id = c.id AND tm.end_time <= now();

    -- Notify sellers of the offers we just carried forward, so they're
    -- not left unaware there's now something actionable waiting on them.
    INSERT INTO public.inbox_messages (recipient_id, title, body, is_read, created_at)
    SELECT c.user_id, 'Transfer Teklifi', format('%s için %s GP teklif aldın.', p.name, tm.current_highest_bid), false, now()
    FROM public.transfer_market tm
    JOIN public.players p ON p.id = tm.player_id
    JOIN public.clubs c ON c.id = p.club_id
    WHERE tm.highest_bidder_id IS NOT NULL AND tm.end_time > now() AND c.user_id IS NOT NULL;

    -- transfer_market keeps its name/shape as a lightweight "listing"
    -- concept (surfaces a player in the browsable market with a
    -- reference price) but drops the bidding mechanics entirely now
    -- that every live bid has been migrated above - current_highest_bid
    -- becomes a plain asking_price, highest_bidder_id/end_time are gone.
    ALTER TABLE public.transfer_market RENAME COLUMN current_highest_bid TO asking_price;
    ALTER TABLE public.transfer_market DROP COLUMN highest_bidder_id;
    ALTER TABLE public.transfer_market DROP COLUMN IF EXISTS end_time;
  END IF;
END $$;

-- Old auction functions are fully superseded - drop them.
DROP FUNCTION IF EXISTS public.place_transfer_bid(uuid, bigint);
DROP FUNCTION IF EXISTS public.accept_transfer_offer(uuid);
DROP FUNCTION IF EXISTS public.release_expired_transfer_bids();

CREATE OR REPLACE FUNCTION public.list_player_for_transfer(p_player_id UUID, p_asking_price BIGINT)
RETURNS public.transfer_market AS $$
DECLARE
  owner_club_id UUID;
  new_row public.transfer_market;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot list a player for transfer';
  END IF;

  IF p_asking_price <= 0 THEN
    RAISE EXCEPTION 'Asking price must be positive';
  END IF;

  SELECT club_id INTO owner_club_id FROM public.players WHERE id = p_player_id;
  IF owner_club_id IS NULL THEN
    RAISE EXCEPTION 'Player not found or has no club';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = owner_club_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You do not own this player''s club';
  END IF;

  INSERT INTO public.transfer_market (player_id, asking_price)
  VALUES (p_player_id, p_asking_price)
  ON CONFLICT (player_id) DO UPDATE SET asking_price = EXCLUDED.asking_price
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.withdraw_transfer_listing(p_player_id UUID)
RETURNS void AS $$
DECLARE
  owner_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot withdraw a listing';
  END IF;

  SELECT club_id INTO owner_club_id FROM public.players WHERE id = p_player_id;
  IF owner_club_id IS NULL THEN
    RAISE EXCEPTION 'Player not found';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = owner_club_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You do not own this player''s club';
  END IF;

  DELETE FROM public.transfer_market WHERE player_id = p_player_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Shared accept/reject logic used both by a human responding and by the
-- bot-club auto-response path inside make_transfer_offer.
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

    -- Every other pending offer for the same player is now moot - refund
    -- and reject them so their buyers aren't left with budget stuck
    -- blocked on a player who's no longer available.
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
  -- instead of leaving a human waiting forever.
  fair_value := player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100;
  PERFORM public._resolve_transfer_offer(new_offer.id, p_offer_amount >= (fair_value * 0.85)::BIGINT);

  SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.respond_to_transfer_offer(p_offer_id UUID, p_accept BOOLEAN)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
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
  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = offer_row.to_club_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You do not own the selling club';
  END IF;

  PERFORM public._resolve_transfer_offer(p_offer_id, p_accept);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;
  IF player_row.club_id IS NOT NULL THEN
    RAISE EXCEPTION 'Player is not a free agent';
  END IF;

  -- Free agents cost less than a full transfer fee (no selling club to
  -- pay off) - 40% of the same market-value formula used elsewhere.
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

-- Safety net: a pending offer nobody ever responds to (e.g. the owning
-- user went inactive, or left the club after the offer landed) would
-- otherwise leave the buyer's budget blocked forever. Auto-reject after
-- 3 days, same cadence as the other timed-upgrade processing.
CREATE OR REPLACE FUNCTION public.process_stale_transfer_offers()
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
BEGIN
  FOR offer_row IN
    SELECT * FROM public.transfer_offers WHERE status = 'pending' AND created_at <= now() - interval '3 days'
  LOOP
    PERFORM public._resolve_transfer_offer(offer_row.id, false);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.process_timed_upgrades()
RETURNS void AS $$
BEGIN
  PERFORM public.process_player_development();
  PERFORM public.process_sponsor_upgrades();
  PERFORM public.process_club_upgrades();
  PERFORM public.process_stale_transfer_offers();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
