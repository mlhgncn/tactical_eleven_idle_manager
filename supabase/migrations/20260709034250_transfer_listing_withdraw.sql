-- Players could be listed for transfer but never taken back off the
-- market - there was no function or UI path to cancel a listing. Allowed
-- only while no bid has been placed yet (once someone's bid money is on
-- the table, withdrawing would be unfair to the bidder).
CREATE OR REPLACE FUNCTION public.withdraw_transfer_listing(p_player_id UUID)
RETURNS void AS $$
DECLARE
  owner_club_id UUID;
  listing_row public.transfer_market%ROWTYPE;
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

  SELECT * INTO listing_row FROM public.transfer_market WHERE player_id = p_player_id AND end_time > now();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This player is not currently listed for transfer';
  END IF;

  IF listing_row.highest_bidder_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot withdraw a listing that already has a bid';
  END IF;

  DELETE FROM public.transfer_market WHERE player_id = p_player_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.withdraw_transfer_listing(UUID) TO authenticated;
