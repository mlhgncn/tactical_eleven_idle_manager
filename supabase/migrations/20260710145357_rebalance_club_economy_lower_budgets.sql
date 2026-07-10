-- "Bütün takımların bütçecisini biraz daha mantıklı bir şekilde düşür":
-- starting budgets (1M-100M GP) were 30-75x the single most expensive
-- action in the game (~1.3M GP to fully expand a stadium; sponsor/facility/
-- ticket upgrades cost 5K-150K), so every club could afford everything
-- instantly with no economic tension. Rescaling the whole player-value
-- economy down by the same 40x factor keeps it internally consistent:
-- new-club budgets, existing club budgets/blocked budgets, free-agent
-- signing cost (sign_free_agent, mirrors lib/models/player_fm.dart's
-- marketValue getter - keep both in sync), and outstanding transfer
-- market listings/offers that were priced against the old scale.

CREATE OR REPLACE FUNCTION public.budget_for_quality(p_quality integer)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE
    WHEN p_quality >= 70 THEN (1000000 + floor(random() * 1500000))::bigint
    WHEN p_quality >= 55 THEN (375000 + floor(random() * 625000))::bigint
    WHEN p_quality >= 40 THEN (125000 + floor(random() * 250000))::bigint
    ELSE (25000 + floor(random() * 100000))::bigint
  END;
END;
$function$;

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

  -- Free agents cost less than a full transfer fee (no selling club to
  -- pay off) - 40% of the same market-value formula used elsewhere,
  -- rescaled /40 to match the lower club-budget economy (see
  -- lib/models/player_fm.dart marketValue getter, kept in sync).
  cost := ROUND(((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40) * 0.4);

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
$function$;

-- Backfill: rescale every existing club's budget/blocked_budget by the
-- same /40 factor so it matches the new formulas above.
UPDATE public.clubs SET budget = FLOOR(budget / 40.0), blocked_budget = FLOOR(blocked_budget / 40.0);

-- Backfill: currently listed asking prices were set against the old
-- marketValue scale - rescale them so they're still sensible next to
-- the new budgets.
UPDATE public.transfer_market SET asking_price = GREATEST(1, FLOOR(asking_price / 40.0));

-- Backfill: pending (not yet resolved) transfer offers likewise, so an
-- accept doesn't try to move an amount inconsistent with the buyer's
-- now-much-smaller blocked_budget.
UPDATE public.transfer_offers SET offer_amount = GREATEST(1, FLOOR(offer_amount / 40.0)) WHERE status = 'pending';
