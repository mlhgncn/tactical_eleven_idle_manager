-- Lets a user drop a player from their roster without going through the
-- transfer market (no listing, no offer to wait for, no revenue) - for
-- when a player just isn't wanted anymore and the user doesn't want to
-- bother selling them. The player becomes a free agent (club_id = NULL,
-- same as how transfer-market/pack/inactivity flows already release
-- players) and can be re-signed by anyone via sign_free_agent, including
-- the releasing club itself later if they change their mind. Also clears
-- any pending transfer listing/offers for the player so a released player
-- doesn't linger half-listed.
CREATE OR REPLACE FUNCTION public.release_player_to_free_agency(p_player_id UUID)
RETURNS void AS $$
DECLARE
  owner_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot release a player';
  END IF;

  SELECT club_id INTO owner_club_id FROM public.players WHERE id = p_player_id;
  IF owner_club_id IS NULL THEN
    RAISE EXCEPTION 'Oyuncu bulunamadı veya zaten serbest.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = owner_club_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Bu oyuncunun kulübü size ait değil.';
  END IF;

  DELETE FROM public.transfer_market WHERE player_id = p_player_id;
  UPDATE public.transfer_offers SET status = 'rejected', responded_at = now()
  WHERE player_id = p_player_id AND status = 'pending';

  UPDATE public.players SET club_id = NULL WHERE id = p_player_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.release_player_to_free_agency(UUID) TO authenticated;
