-- Root cause of "sponsor upgrade has no duration, upgrades instantly":
-- the CI deploy workflow runs `psql -f supabase/schema.sql`
-- UNCONDITIONALLY on every single deploy (not gated by the
-- _migrations_applied dedup that protects supabase/migrations/*.sql).
-- schema.sql was never updated after upgrade_sponsor/upgrade_club were
-- rewritten in later migrations, so every deploy since has silently
-- reverted them back to their old instant/wrong-signature versions -
-- this migration restores the correct live versions right now; the
-- companion fix to supabase/schema.sql itself (in the same commit)
-- stops this from recurring on the next deploy.

CREATE OR REPLACE FUNCTION public.upgrade_sponsor(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
  new_budget BIGINT;
  duration_days INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade sponsor';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF current_club.sponsor_level >= 5 THEN
    RAISE EXCEPTION 'Sponsor level cannot exceed 5';
  END IF;

  IF current_club.sponsor_upgrade_completes_at IS NOT NULL AND current_club.sponsor_upgrade_completes_at > now() THEN
    RAISE EXCEPTION 'Sponsor upgrade already in progress';
  END IF;

  new_budget := current_club.budget - (5000 * current_club.sponsor_level);
  IF new_budget < 0 THEN
    RAISE EXCEPTION 'Not enough budget to upgrade sponsor';
  END IF;

  duration_days := 2 * current_club.sponsor_level - 1;

  UPDATE public.clubs
  SET budget = new_budget,
      sponsor_upgrade_completes_at = now() + make_interval(days => duration_days)
  WHERE id = club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    club_id,
    'upgrade_sponsor',
    -(5000 * current_club.sponsor_level),
    format('Sponsor yükseltme harcaması: -%s GP (%s gün sürecek)', 5000 * current_club.sponsor_level, duration_days),
    'upgrade_sponsor'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- The 4-arg instant upgrade_club got resurrected by schema.sql too,
-- coexisting confusingly alongside (or replacing) the 2-arg
-- ticket-price-only version. Drop the stale one, restore the real one.
DROP FUNCTION IF EXISTS public.upgrade_club(uuid, integer, integer, integer);

CREATE OR REPLACE FUNCTION public.upgrade_club(
  p_club_id UUID,
  p_ticket_price INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = p_club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF p_ticket_price IS NULL OR p_ticket_price <= current_club.ticket_price THEN
    RAISE EXCEPTION 'Ticket price must be higher than current price';
  END IF;

  IF current_club.budget < 500 THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - 500,
      ticket_price = p_ticket_price
  WHERE id = p_club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (p_club_id, 'upgrade_club', -500, 'Bilet fiyatı güncelleme harcaması: -500 GP', 'upgrade_club');

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- These three were intentionally dropped when the transfer system moved
-- from auction bidding to real offers, but schema.sql kept resurrecting
-- them as unreachable zombies (their bodies reference columns that no
-- longer exist, e.g. transfer_market.highest_bidder_id) - remove for real.
DROP FUNCTION IF EXISTS public.place_transfer_bid(uuid, bigint);
DROP FUNCTION IF EXISTS public.accept_transfer_offer(uuid);
DROP FUNCTION IF EXISTS public.release_expired_transfer_bids();

-- Superseded by start_player_development/process_player_development;
-- nothing calls this anymore, schema.sql was just resurrecting dead code.
DROP FUNCTION IF EXISTS public.advance_player_development(uuid, integer, integer, integer, double precision);
