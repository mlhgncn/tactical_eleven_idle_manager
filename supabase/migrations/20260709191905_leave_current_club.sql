-- Lets a user leave their club. The club itself is NOT deleted (that
-- would orphan its matches/standings/history and break the league for
-- everyone else) - it just becomes unowned again (user_id = NULL),
-- exactly like the bot clubs auto_resolve_matches already knows how to
-- play, and exactly the slot shape join_league_with_code already knows
-- how to hand back out to the next joiner.
CREATE OR REPLACE FUNCTION public.leave_current_club()
RETURNS void AS $$
DECLARE
  owned_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot leave a club';
  END IF;

  SELECT id INTO owned_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  IF owned_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  UPDATE public.clubs SET user_id = NULL WHERE id = owned_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.leave_current_club() TO authenticated;
